// 统一 HTTP 客户端：@ohos.net.http 封装。
//   - BASE = https://bdfz.xnykcxt.com:5002/exam
//   - 认证：X-Custom-Auth 头，AES-256/CBC/PKCS7 加密 {domain,userId,version,timestamp}
//     （网页端 4.0.1 已从 DES/ECB 升级为 AES/CBC，逆向确认见 utils/Aes.ets）
//   - 响应统一解包 ApiResp{code,message,extra}，code!==0 抛 ApiError
//   - 会话守护：HTTP 401/403 或业务码提示未登录时，回调 reloginProvider
//     用记住的凭据静默重登一次再重试（对应油猴脚本"会话守护/自动登录"的原生化）
//   - 已知坑（沿用 GmHttp 经验）：此 SDK http 枚举无 PATCH，需要时映射 POST

import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { aesCbcEncrypt } from '../utils/Aes';
import { ApiResp, ApiError } from '../models/ApiTypes';
import { ApiHeaders } from './ApiHeaders';

const DOMAIN = 0x0002;
const TAG = 'ApiClient';

export interface FullResp<T> {
  resp: ApiResp<T>;
  headers: Record<string, string>;
  httpStatus: number;
}

export class ApiClient {
  static readonly ORIGIN: string = 'https://bdfz.xnykcxt.com:5002';
  static readonly BASE: string = ApiClient.ORIGIN + '/exam';
  private static readonly AUTH_DOMAIN: string = 'bdfz.xnykcxt.com';
  private static readonly AUTH_VERSION: string = '4.0.1';
  // 32 字符密钥串：其 UTF-8 字节（32B）直接作为 AES-256 密钥（与网页端 CryptoJS 一致）。
  private static readonly AES_KEY_STR: string = '348ebfa6d1f9708310cb8a7f88367bc5';

  private static userId: number = 0;
  private static token: string = '';
  static reloginProvider: (() => Promise<boolean>) | null = null;

  static setUserId(id: number): void {
    ApiClient.userId = id;
  }

  static getUserId(): number {
    return ApiClient.userId;
  }

  static setToken(t: string): void {
    ApiClient.token = t || '';
  }

  static getToken(): string {
    return ApiClient.token;
  }

  static hasAuth(): boolean {
    return ApiClient.userId > 0 && ApiClient.token.length > 0;
  }

  static buildAuthHeader(): string {
    // timestamp 为「秒」（网页端 4.0.1：Math.floor(Date.now()/1000)），非毫秒——实测确认。
    const payload: string = JSON.stringify({
      domain: ApiClient.AUTH_DOMAIN,
      userId: ApiClient.userId > 0 ? ApiClient.userId : '',
      version: ApiClient.AUTH_VERSION,
      timestamp: Math.floor(Date.now() / 1000)
    });
    return aesCbcEncrypt(ApiClient.AES_KEY_STR, payload);
  }

  // 拼绝对地址：传入 /api/... 或 /login/api/... 自动加 BASE；完整 URL 原样返回
  static absolute(path: string): string {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('/exam/')) {
      return ApiClient.ORIGIN + path;
    }
    return ApiClient.BASE + path;
  }

  // 静态资源绝对化。服务端文件都挂在应用根 /exam/ 下：
  //   - content 图片 src 已是 /exam/jyhr/... → 原样接 ORIGIN
  //   - 附件 statistics 给的明文路径是 /jyhr/uploadFile/...（少了 /exam 段）→ 必须补 /exam，否则 404
  static assetUrl(src: string): string {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return src;
    }
    if (src.startsWith('/exam/')) {
      return ApiClient.ORIGIN + src;
    }
    if (src.startsWith('/')) {
      return ApiClient.ORIGIN + '/exam' + src;
    }
    return ApiClient.BASE + '/' + src;
  }

  static async get<T>(path: string): Promise<T> {
    return ApiClient.request<T>(http.RequestMethod.GET, path, null);
  }

  static async post<T>(path: string, body: object | object[] | null): Promise<T> {
    return ApiClient.request<T>(http.RequestMethod.POST, path, body);
  }

  static async put<T>(path: string, body: object | object[] | null): Promise<T> {
    return ApiClient.request<T>(http.RequestMethod.PUT, path, body);
  }

  static async del<T>(path: string, body: object | object[] | null): Promise<T> {
    return ApiClient.request<T>(http.RequestMethod.DELETE, path, body);
  }

  // 常规请求：返回 extra（业务数据）。
  static async request<T>(method: http.RequestMethod, path: string,
    body: object | object[] | null): Promise<T> {
    const full = await ApiClient.requestFull<T>(method, path, body, true);
    return full.resp.extra as T;
  }

  // 完整请求：返回 ApiResp + 响应头。
  static async requestFull<T>(method: http.RequestMethod, path: string,
    body: object | object[] | null, allowRelogin: boolean): Promise<FullResp<T>> {
    const first = await ApiClient.doOnce<T>(method, path, body);
    if (!ApiClient.needRelogin(first)) {
      ApiClient.ensureOk(first, path);
      return first;
    }
    // 会话失效：尝试静默重登一次
    if (allowRelogin && ApiClient.reloginProvider !== null) {
      hilog.warn(DOMAIN, TAG, 'session expired on %{public}s, trying silent relogin', path);
      let ok = false;
      try {
        ok = await ApiClient.reloginProvider();
      } catch (e) {
        const err = e as BusinessError;
        hilog.warn(DOMAIN, TAG, 'silent relogin failed: %{public}s', err.message);
      }
      if (ok) {
        const second = await ApiClient.doOnce<T>(method, path, body);
        ApiClient.ensureOk(second, path);
        return second;
      }
    }
    ApiClient.ensureOk(first, path);
    return first;
  }

  private static needRelogin<T>(r: FullResp<T>): boolean {
    if (r.httpStatus === 401 || r.httpStatus === 403) {
      return true;
    }
    if (r.resp.code === 10003) {
      return true;
    }
    if (r.resp.code !== 0) {
      const msg = r.resp.message || '';
      if (msg.indexOf('登录') >= 0 || msg.indexOf('token') >= 0 || msg.indexOf('Token') >= 0) {
        return true;
      }
    }
    return false;
  }

  private static ensureOk<T>(r: FullResp<T>, path: string): void {
    if (r.httpStatus >= 400) {
      throw new ApiError(`HTTP ${r.httpStatus} on ${path}`, -1, r.httpStatus);
    }
    if (r.resp.code !== 0) {
      throw new ApiError(r.resp.message || `code ${r.resp.code} on ${path}`,
        r.resp.code, r.httpStatus);
    }
  }

  private static async doOnce<T>(method: http.RequestMethod, path: string,
    body: object | object[] | null): Promise<FullResp<T>> {
    const url = ApiClient.absolute(path);
    const client = http.createHttp();
    const headers: Record<string, string> =
      ApiHeaders.json(ApiClient.buildAuthHeader(), ApiClient.token);
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      connectTimeout: 15000,
      readTimeout: 20000,
      expectDataType: http.HttpDataType.STRING,
      usingCache: false
    };
    if (body !== null) {
      headers['Content-Type'] = 'application/json';
      options.extraData = JSON.stringify(body);
    }
    const t0 = Date.now();
    try {
      const resp = await client.request(url, options);
      const text: string = typeof resp.result === 'string' ? resp.result : String(resp.result ?? '');
      const status: number = resp.responseCode;
      hilog.info(DOMAIN, TAG, '%{public}s %{public}s -> %{public}d (%{public}dms, %{public}d bytes)',
        method, path, status, Date.now() - t0, text.length);
      let parsed: ApiResp<T>;
      try {
        parsed = JSON.parse(text) as ApiResp<T>;
      } catch (e) {
        // 非 JSON（网关错误页等）
        parsed = { code: -1, message: 'bad json: ' + text.substring(0, 120) };
      }
      const headerMap: Record<string, string> = ApiClient.normalizeHeaders(resp.header);
      return { resp: parsed, headers: headerMap, httpStatus: status };
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, '%{public}s %{public}s failed: %{public}s', method, path, err.message);
      throw new ApiError(err.message || 'network error', -1, 0);
    } finally {
      client.destroy();
    }
  }

  private static normalizeHeaders(h: object | undefined): Record<string, string> {
    const out: Record<string, string> = {};
    if (!h) {
      return out;
    }
    const rec = h as Record<string, string | string[]>;
    const keys = Object.keys(rec);
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i];
      const v = rec[k];
      if (typeof v === 'string') {
        out[k.toLowerCase()] = v;
      } else if (Array.isArray(v)) {
        out[k.toLowerCase()] = v.join('\n');
      }
    }
    return out;
  }

  static extractToken(headers: Record<string, string>): string {
    const sc = headers['set-cookie'] || '';
    if (sc.length === 0) {
      return '';
    }
    const m = sc.match(/token=([0-9a-fA-F]+)/);
    if (m && m.length > 1) {
      return m[1];
    }
    return '';
  }

  // multipart 上传（拍照作答图等）。fieldName 对应后端表单名。
  static async uploadFile<T>(path: string, filePath: string, fileName: string,
    mime: string, fieldName: string): Promise<T> {
    const url = ApiClient.absolute(path);
    const client = http.createHttp();
    const headers: Record<string, string> =
      ApiHeaders.multipart(ApiClient.buildAuthHeader(), ApiClient.token);
    const form: http.MultiFormData = {
      name: fieldName,
      contentType: mime,
      remoteFileName: fileName,
      filePath: filePath
    };
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      connectTimeout: 30000,
      readTimeout: 60000,
      expectDataType: http.HttpDataType.STRING,
      usingCache: false,
      multiFormDataList: [form]
    };
    try {
      const resp = await client.request(url, options);
      const text: string = typeof resp.result === 'string' ? resp.result : String(resp.result ?? '');
      const parsed = JSON.parse(text) as ApiResp<T>;
      if (parsed.code !== 0) {
        throw new ApiError(parsed.message || 'upload failed', parsed.code, resp.responseCode);
      }
      return parsed.extra as T;
    } catch (e) {
      if (e instanceof ApiError) {
        throw e;
      }
      const err = e as BusinessError;
      throw new ApiError(err.message || 'upload error', -1, 0);
    } finally {
      client.destroy();
    }
  }
}
