// 文件下载工具：request.downloadFile 落盘到应用沙箱缓存。
// 既给 PDF 下载按钮用，也作为附件预览（PdfView / Video 本地回退）的取数通道。
// PdfView.loadDocument 只认本地沙箱路径，Video 本地播放也要 file:// 沙箱 URI，
// 所以网络附件统一先下到 cacheDir/attachments 再交给预览组件。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { request } from '@kit.BasicServicesKit';
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

    const headerMap: Record<string, string> = {};
    if (ApiClient.hasToken()) {
      headerMap['Cookie'] = 'token=' + ApiClient.getToken();
    }
    const config: request.DownloadConfig = {
      url: fullUrl,
      filePath: filePath,
      header: headerMap,
      enableMetered: true,
      enableRoaming: false,
      title: safeName,
      description: '正在加载附件 ' + safeName
    };
    hilog.info(DOMAIN, TAG, 'download start: %{public}s -> %{public}s', fullUrl, filePath);
    const task = await request.downloadFile(context, config);
    return new Promise<string>((resolve, reject) => {
      task.on('complete', () => {
        hilog.info(DOMAIN, TAG, 'download complete: %{public}s', safeName);
        resolve(filePath);
      });
      task.on('fail', (err: number) => {
        hilog.error(DOMAIN, TAG, 'download failed: %{public}d', err);
        reject(new Error('download failed (code ' + err + ')'));
      });
    });
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

  // 文件名净化：去掉路径分隔符等非法字符，避免越权写或非法路径。
  private static sanitize(name: string): string {
    const cleaned = name.replace(/[^A-Za-z0-9._一-龥-]/g, '_');
    return cleaned.length > 0 ? cleaned : 'attachment';
  }
}
