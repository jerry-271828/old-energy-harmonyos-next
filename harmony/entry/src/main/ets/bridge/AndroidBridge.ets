import { webview } from '@kit.ArkWeb';
import { GmStorage } from './GmStorage';
import { GmNotifier } from './GmNotifier';
import { GmHttp } from './GmHttp';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'AndroidBridge';

// Exposed to WebView JS as `AndroidBridge`.
//   The name matches the original Android implementation so that the
//   userscripts (main_pack.js, pack2.js) need no modification.
export class AndroidBridge {
  // 由 UI 层（Index.ets）注册的回调：JS 调 openFloatPdf 时由这条
  // 通道把 URL 传到 ArkUI 侧，由 ArkUI 决定怎么开浮动窗口。
  // 一个全局 callback 足够：业务上同一时间只有一个主 WebView 在收浮窗请求。
  private static floatPdfOpener: ((url: string) => void) | null = null;

  static setFloatPdfOpener(fn: ((url: string) => void) | null): void {
    AndroidBridge.floatPdfOpener = fn;
  }

  attach(controller: webview.WebviewController): void {
    GmHttp.bindController(controller);
  }

  // ---- methods callable from JavaScript (synchronous from JS side) ----
  // NOTE: methodList in Web.javaScriptProxy() MUST list these names verbatim.

  getValue(key: string): string {
    return GmStorage.getSync(key);
  }

  setValue(key: string, value: string): void {
    GmStorage.putAsync(key, value);
  }

  showNotification(title: string, text: string): void {
    GmNotifier.publish(title, text);
  }

  xhrRequest(reqJson: string): void {
    GmHttp.request(reqJson);
  }

  // 主页 main_pack.js（appmode === 1 分支）会调这个把 PDF 预览转给原生浮窗。
  // ArkUI 用 setFloatPdfOpener 注入闭包；这里 trim 一下防御性兜底。
  openFloatPdf(url: string): void {
    const trimmed: string = (url || '').trim();
    if (trimmed.length === 0) {
      hilog.warn(DOMAIN, TAG, 'openFloatPdf: empty url, ignoring');
      return;
    }
    const opener = AndroidBridge.floatPdfOpener;
    if (!opener) {
      hilog.warn(DOMAIN, TAG, 'openFloatPdf: no opener registered, url=%{public}s', trimmed);
      return;
    }
    hilog.info(DOMAIN, TAG, 'openFloatPdf: %{public}s', trimmed);
    try {
      opener(trimmed);
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'openFloatPdf opener threw: %{public}s', err.message);
    }
  }
}
