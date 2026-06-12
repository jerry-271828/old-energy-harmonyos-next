// 统一 HTTP 客户端：@ohos.net.http 封装。
//   - BASE = https://bdfz.xnykcxt.com:5002/exam
//   - 认证：登录后服务端 Set-Cookie: token=<hex>，之后所有请求带 Cookie 头
//   - 响应统一解包 ApiResp{code,message,extra}，code!==0 抛 ApiError
//   - 会话守护：HTTP 401/403 或业务码提示未登录时，回调 reloginProvider
//     用记住的凭据静默重登一次再重试（对应油猴脚本"会话守护/自动登录"的原生化）
//   - 已知坑（沿用 GmHttp 经验）：此 SDK http 枚举无 PATCH，需要时映射 POST

import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ApiResp, ApiError } from '../models/ApiTypes';

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

  private static token: string = '';
  // 由 SessionStore 注册：静默重登。返回 true 表示拿到了新 token，可重试原请求。
  static reloginProvider: (() => Promise<boolean>) | null = null;

  static setToken(t: string): void {
    ApiClient.token = t || '';
  }

  static getToken(): string {
    return ApiClient.token;
  }

  static hasToken(): boolean {
    return ApiClient.token.length > 0;
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

  // 静态资源（内容图片等）绝对化：textContent 里的 src 是 /exam/jyhr/... 形式
  static assetUrl(src: string): string {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return src;
    }
    if (src.startsWith('/')) {
      return ApiClient.ORIGIN + src;
    }
    return ApiClient.ORIGIN + '/' + src;
  }

  static async get<T>(path: string): Promise<T> {
    return ApiClient.request<T>(http.RequestMethod.GET, path, null);
  }

  static async post<T>(path: string, body: object | null): Promise<T> {
    return ApiClient.request<T>(http.RequestMethod.POST, path, body);
  }

  static async put<T>(path: string, body: object | null): Promise<T> {
    return ApiClient.request<T>(http.RequestMethod.PUT, path, body);
  }

  static async del<T>(path: string, body: object | null): Promise<T> {
    return ApiClient.request<T>(http.RequestMethod.DELETE, path, body);
  }

  // 常规请求：返回 extra（业务数据）。
  static async request<T>(method: http.RequestMethod, path: string,
    body: object | null): Promise<T> {
    const full = await ApiClient.requestFull<T>(method, path, body, true);
    return full.resp.extra as T;
  }

  // 完整请求：返回 ApiResp + 响应头（登录要从头里拿 Set-Cookie）。
  static async requestFull<T>(method: http.RequestMethod, path: string,
    body: object | null, allowRelogin: boolean): Promise<FullResp<T>> {
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
    body: object | null): Promise<FullResp<T>> {
    const url = ApiClient.absolute(path);
    const client = http.createHttp();
    const headers: Record<string, string> = {
      'Accept': 'application/json, text/plain, */*'
    };
    if (ApiClient.token.length > 0) {
      headers['Cookie'] = 'token=' + ApiClient.token;
    }
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

  // 从响应头提取 token（Set-Cookie: token=xxxx; Path=/ ...）
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
    const headers: Record<string, string> = {
      'Accept': 'application/json, text/plain, */*',
      'Content-Type': 'multipart/form-data'
    };
    if (ApiClient.token.length > 0) {
      headers['Cookie'] = 'token=' + ApiClient.token;
    }
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
