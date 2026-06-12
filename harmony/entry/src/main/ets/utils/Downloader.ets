// 文件下载工具：request.agent 落盘到 Download 目录。
// 对应油猴脚本"强制显示 PDF 下载按钮"的原生化，补齐 README 已知限制。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { request } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { ApiClient } from '../net/ApiClient';

const DOMAIN = 0x0002;
const TAG = 'Downloader';

export class Downloader {
  static async download(context: common.UIAbilityContext, url: string,
    fileName: string): Promise<boolean> {
    const fullUrl = ApiClient.assetUrl(url);
    hilog.info(DOMAIN, TAG, 'starting download: %{public}s -> %{public}s', fullUrl, fileName);

    try {
      const downloadDir = context.cacheDir + '/downloads';
      const config: request.DownloadConfig = {
        url: fullUrl,
        filePath: downloadDir + '/' + fileName,
        header: ApiClient.hasToken()
          ? { 'Cookie': 'token=' + ApiClient.getToken() } : {},
        enableMetered: true,
        enableRoaming: false,
        title: fileName,
        description: '正在下载 ' + fileName
      };
      const task = await request.downloadFile(context, config);
      return new Promise<boolean>((resolve) => {
        task.on('complete', () => {
          hilog.info(DOMAIN, TAG, 'download complete: %{public}s', fileName);
          resolve(true);
        });
        task.on('fail', (err: number) => {
          hilog.error(DOMAIN, TAG, 'download failed: %{public}d', err);
          resolve(false);
        });
      });
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'download error: %{public}s', err.message);
      return false;
    }
  }
}
