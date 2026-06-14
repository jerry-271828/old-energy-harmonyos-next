// 文件下载工具：用 NetworkKit http 流式落盘到应用沙箱缓存。
// 既给 PDF 下载按钮用，也作为附件预览（PdfView / Video 本地回退）的取数通道。
// PdfView.loadDocument 只认本地沙箱路径，Video 本地播放也要 file:// 沙箱 URI，
// 所以网络附件统一先下到 cacheDir/attachments 再交给预览组件。
//
// 为什么不用 request.downloadFile：那是独立的系统下载代理进程，在本服务器
// （非标 :5002 HTTPS）上会以 ERROR_UNKNOWN(code 8) 失败（连接/TLS 握手超时）；
// 而 ApiClient 用的同一套 NetworkKit http 栈对该 host 是通的（登录/接口全部成功）。
// 故这里复用 http 栈，带上同样的 token cookie，绕开下载代理的差异。改回 downloadFile 会复发 code 8。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { ApiClient } from '../net/ApiClient';

const DOMAIN = 0x0002;
const TAG = 'Downloader';
const CACHE_SUBDIR = '/attachments';

export class Downloader {
  // 下载到沙箱缓存并返回本地绝对路径；命中缓存（同名非空文件）直接复用。
  // url 可为相对路径或绝对地址——assetUrl 内部已做绝对化。
  static async downloadToCache(context: common.UIAbilityContext, url: string,
    cacheFileName: string): Promise<string> {
    const fullUrl = ApiClient.assetUrl(url);
    const dir = context.cacheDir + CACHE_SUBDIR;
    const safeName = Downloader.sanitize(cacheFileName);
    const filePath = dir + '/' + safeName;

    // 确保目录存在（request.downloadFile 不会自建父目录——旧实现漏了这步）
    try {
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true);
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'mkdir %{public}s failed: %{public}s', dir, err.message);
    }

    // 缓存命中：非空文件直接复用；空/残留文件删掉重下（downloadFile 不允许目标已存在）
    try {
      if (fileIo.accessSync(filePath)) {
        const st = fileIo.statSync(filePath);
        if (st.size > 0) {
          hilog.info(DOMAIN, TAG, 'cache hit: %{public}s (%{public}d bytes)', safeName, st.size);
          return filePath;
        }
        fileIo.unlinkSync(filePath);
      }
    } catch (e) {
      // 探测失败按未命中处理
    }

    const headerMap: Record<string, string> = { 'Accept': '*/*' };
    if (ApiClient.hasToken()) {
      headerMap['Cookie'] = 'token=' + ApiClient.getToken();
    }

    // 先下到 .part 临时文件，成功再改名为目标名——避免半截文件被上面的"非空即命中"逻辑误当成缓存。
    const tmpPath = filePath + '.part';
    Downloader.safeUnlink(tmpPath);
    const file = fileIo.openSync(tmpPath,
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    const client = http.createHttp();
    let writeError = '';
    let totalBytes = 0;
    // dataReceive 在同一线程顺序回调，writeSync 同步写，分块顺序天然保证。
    client.on('dataReceive', (chunk: ArrayBuffer) => {
      if (writeError.length > 0) {
        return;
      }
      try {
        totalBytes += fileIo.writeSync(file.fd, chunk);
      } catch (e) {
        writeError = (e as BusinessError).message || 'write error';
      }
    });

    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: headerMap,
      connectTimeout: 15000,
      readTimeout: 60000,
      usingCache: false
    };
    hilog.info(DOMAIN, TAG, 'download start: %{public}s -> %{public}s', fullUrl, filePath);

    const cleanup = (): void => {
      client.off('dataReceive');
      try {
        fileIo.closeSync(file);
      } catch (e) {
        // 已关闭/无效 fd，忽略
      }
      client.destroy();
    };

    let status = -1;
    try {
      status = await client.requestInStream(fullUrl, options);
    } catch (e) {
      cleanup();
      Downloader.safeUnlink(tmpPath);
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'download failed: %{public}s', err.message);
      throw new Error('download failed (' + (err.message || 'network error') + ')');
    }
    cleanup();

    if (writeError.length > 0) {
      Downloader.safeUnlink(tmpPath);
      throw new Error('download failed (write: ' + writeError + ')');
    }
    if (status >= 400) {
      Downloader.safeUnlink(tmpPath);
      throw new Error('download failed (HTTP ' + status + ')');
    }
    if (totalBytes === 0) {
      Downloader.safeUnlink(tmpPath);
      throw new Error('download failed (empty response)');
    }
    Downloader.safeUnlink(filePath);
    fileIo.renameSync(tmpPath, filePath);
    hilog.info(DOMAIN, TAG, 'download complete: %{public}s (%{public}d bytes)', safeName, totalBytes);
    return filePath;
  }

  // 兼容旧调用：仅关心成功与否。
  static async download(context: common.UIAbilityContext, url: string,
    fileName: string): Promise<boolean> {
    try {
      await Downloader.downloadToCache(context, url, fileName);
      return true;
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'download error: %{public}s', err.message);
      return false;
    }
  }

  // 后台静默清缓存：整目录删除（含残留/未删的预览临时文件）。
  // 适合在冷启动时 fire-and-forget 调用——不影响当前会话的预览（那时还没有活动预览）。
  // 下次 downloadToCache 会自动重建目录，故无需保留空目录。
  static async clearCache(context: common.UIAbilityContext): Promise<void> {
    const dir = context.cacheDir + CACHE_SUBDIR;
    try {
      if (fileIo.accessSync(dir)) {
        await fileIo.rmdir(dir);   // 递归删除目录及其内容
        hilog.info(DOMAIN, TAG, 'attachment cache cleared: %{public}s', dir);
      }
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'clearCache failed: %{public}s', err.message);
    }
  }

  // 静默删除（不存在/失败都不抛）：清理失败或残留的 .part 临时文件。
  private static safeUnlink(p: string): void {
    try {
      if (fileIo.accessSync(p)) {
        fileIo.unlinkSync(p);
      }
    } catch (e) {
      // ignore
    }
  }

  // 文件名净化：去掉路径分隔符等非法字符，避免越权写或非法路径。
  private static sanitize(name: string): string {
    const cleaned = name.replace(/[^A-Za-z0-9._一-龥-]/g, '_');
    return cleaned.length > 0 ? cleaned : 'attachment';
  }
}
