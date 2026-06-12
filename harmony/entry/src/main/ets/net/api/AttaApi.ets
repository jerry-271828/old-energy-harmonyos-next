// 附件上传与图片增强 API
import { ApiClient } from '../ApiClient';

export interface UploadResult {
  id: number;
  attachmentName: string;
  attachmentLinkAddress: string;
  attachmentExtraName: string;
}

export class AttaApi {
  static async upload(filePath: string, fileName: string, mime: string): Promise<UploadResult> {
    return ApiClient.uploadFile<UploadResult>(
      '/api/atta/upload', filePath, fileName, mime, 'file');
  }

  static async imgEnhance(attachmentId: number): Promise<UploadResult> {
    return ApiClient.get<UploadResult>(`/api/atta/img/enchance/${attachmentId}`);
  }
}
