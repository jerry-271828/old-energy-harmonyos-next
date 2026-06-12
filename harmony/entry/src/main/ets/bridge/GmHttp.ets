import { http } from '@kit.NetworkKit';
import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'GmHttp';

interface XhrRequestData {
  id: string;
  url: string;
  method: string;
  headers: Record<string, string>;
  data: string | null;
  timeout: number;
  responseType: string;
}

interface XhrPayload {
  status?: number;
  statusText?: string;
  responseText?: string;
  responseHeaders?: string;
  finalUrl?: string;
  error?: string;
  timeout?: boolean;
}

export class GmHttp {
  private static controller: webview.WebviewController | null = null;

  static bindController(c: webview.WebviewController): void {
    GmHttp.controller = c;
  }

  static request(reqJson: string): void {
    let req: XhrRequestData;
    try {
      req = JSON.parse(reqJson) as XhrRequestData;
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'bad reqJson: %{public}s', err.message);
      return;
    }
    if (!req || !req.url) {
      hilog.warn(DOMAIN, TAG, 'missing url');
      return;
    }
    GmHttp.execute(req);
  }

  private static execute(req: XhrRequestData): void {
    const client = http.createHttp();
    const method: http.RequestMethod = GmHttp.toMethod(req.method);
    const headers: Record<string, string> = req.headers || {};
    const hasBody: boolean = req.data !== null && req.data !== undefined && req.data !== '';
    const isWriteMethod: boolean = method === http.RequestMethod.POST ||
                                   method === http.RequestMethod.PUT;
    if (!headers['Content-Type'] && hasBody && isWriteMethod) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
    }

    const timeoutMs: number = req.timeout && req.timeout > 0 ? req.timeout : 15000;
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs,
      expectDataType: http.HttpDataType.STRING,
      usingCache: false
    };
    if (req.data !== null && req.data !== undefined) {
      options.extraData = req.data;
    }

    client.request(req.url, options).then((resp: http.HttpResponse) => {
      const text: string = typeof resp.result === 'string' ? resp.result : String(resp.result ?? '');
      const headerJson: string = JSON.stringify(resp.header ?? {});
      const payload: XhrPayload = {
        status: resp.responseCode,
        statusText: '',
        responseText: text,
        responseHeaders: headerJson,
        finalUrl: req.url
      };
      GmHttp.resolveJs(req.id, payload);
    }).catch((err: BusinessError) => {
      const msg = err && err.message ? err.message : String(err);
      const isTimeout: boolean = msg.toLowerCase().indexOf('timeout') >= 0 ||
                                 msg.toLowerCase().indexOf('timed out') >= 0;
      const payload: XhrPayload = isTimeout ? { timeout: true } : { error: msg };
      GmHttp.resolveJs(req.id, payload);
    }).finally(() => {
      client.destroy();
    });
  }

  private static toMethod(name: string): http.RequestMethod {
    const m = (name || 'GET').toUpperCase();
    switch (m) {
      case 'POST': return http.RequestMethod.POST;
      case 'PUT': return http.RequestMethod.PUT;
      case 'DELETE': return http.RequestMethod.DELETE;
      case 'HEAD': return http.RequestMethod.HEAD;
      case 'OPTIONS': return http.RequestMethod.OPTIONS;
      case 'PATCH': return http.RequestMethod.POST; // ArkTS http enum has no PATCH at API 22 — map to POST
      default: return http.RequestMethod.GET;
    }
  }

  private static resolveJs(id: string, payload: XhrPayload): void {
    const c = GmHttp.controller;
    if (!c) {
      hilog.warn(DOMAIN, TAG, 'no webview controller bound');
      return;
    }
    const jsId = JSON.stringify(id);
    const jsPayload = JSON.stringify(payload);
    const script = `try{ if(window.__gm_xhr_resolve){window.__gm_xhr_resolve(${jsId},${jsPayload});} }catch(e){console.warn(e);}`;
    try {
      c.runJavaScript(script);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'runJavaScript failed: %{public}s', err.message);
    }
  }
}
