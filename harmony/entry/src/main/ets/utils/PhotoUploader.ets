// 拍照/相册选图 → 上传 → 绑定到题目作答。
// 流程：cameraPicker/photoPicker → 沙箱复制 → AttaApi.upload → (可选)imgEnhance → bind

import { hilog } from '@kit.PerformanceAnalysisKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AttaApi, UploadResult } from '../net/api/AttaApi';
import { StudyApi, StudyKind } from '../net/api/StudyApi';
import { SettingsStore } from '../store/SettingsStore';

const DOMAIN = 0x0002;
const TAG = 'PhotoUploader';

export class PhotoUploader {
  static async pickAndUpload(context: common.UIAbilityContext, entityId: number,
    questionId: number, kind: StudyKind): Promise<UploadResult | null> {
    const uri = await PhotoUploader.pickPhoto(context);
    if (uri === null) {
      return null;
    }
    return PhotoUploader.uploadAndBind(context, uri, entityId, questionId, kind);
  }

  static async pickPhoto(context: common.UIAbilityContext): Promise<string | null> {
    try {
      const option = new photoAccessHelper.PhotoSelectOptions();
      option.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      option.maxSelectNumber = 1;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select(option);
      if (result.photoUris.length > 0) {
        return result.photoUris[0];
      }
      return null;
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'pickPhoto failed: %{public}s', err.message);
      return null;
    }
  }

  static async uploadAndBind(context: common.UIAbilityContext, uri: string,
    entityId: number, questionId: number, kind: StudyKind): Promise<UploadResult | null> {
    try {
      // copy to sandbox for upload
      const fileName = `answer_${Date.now()}.jpg`;
      const sandboxPath = context.cacheDir + '/' + fileName;
      const srcFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const destFile = fs.openSync(sandboxPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      const buf = new ArrayBuffer(1024 * 1024);
      let total = 0;
      let n = fs.readSync(srcFile.fd, buf);
      while (n > 0) {
        fs.writeSync(destFile.fd, buf, { length: n, offset: total });
        total += n;
        n = fs.readSync(srcFile.fd, buf);
      }
      fs.closeSync(srcFile);
      fs.closeSync(destFile);

      // upload
      let result = await AttaApi.upload(sandboxPath, fileName, 'image/jpeg');
      hilog.info(DOMAIN, TAG, 'uploaded %{public}s, id=%{public}d', fileName, result.id);

      // enhance (unless user opted for fast upload)
      if (!SettingsStore.instance.enableMockEnhance) {
        try {
          result = await AttaApi.imgEnhance(result.id);
          hilog.info(DOMAIN, TAG, 'enhanced attachment %{public}d', result.id);
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'enhance skipped');
        }
      }

      // bind to question
      const api = kind === 'paper' ? StudyApi.paper : StudyApi.course;
      await api.bindAnswerAttachment(entityId, questionId, result.id, '');
      hilog.info(DOMAIN, TAG, 'bound attachment %{public}d to question %{public}d',
        result.id, questionId);

      // cleanup sandbox
      try {
        fs.unlinkSync(sandboxPath);
      } catch (_) {
        // ignore
      }

      return result;
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'uploadAndBind failed: %{public}s', err.message);
      return null;
    }
  }
}
