// 附件上传与图片增强 API
import { ApiClient } from '../ApiClient';

export interface UploadResult {
  id: number;
  attachmentName: string;
  attachmentLinkAddress: string;
  attachmentExtraName: string;
}

interface ImgEnhanceReq {
  attachmentId: number;
}

export class AttaApi {
  // multipart 字段名是 'uploadFile'（真机抓包确认 2026-06-14：用 'file'/'files'/'multipartFile'
  // 均返回 code 9999「服务器错误！」，仅 'uploadFile' 成功——这是「手写/拍照作答提交报错」的根因之一）。
  static async upload(filePath: string, fileName: string, mime: string): Promise<UploadResult> {
    return ApiClient.uploadFile<UploadResult>(
      '/api/atta/upload', filePath, fileName, mime, 'uploadFile');
  }

  // 图片增强：POST /api/atta/img/enchance（body {attachmentId}）。真机抓包确认是 POST、路径不带 id；
  // 原先的 GET /api/atta/img/enchance/{id} 实测 404。增强是可选项（调用方 try/catch 吞失败→退回原图），
  // 故即便失败也不影响作答提交。
  static async imgEnhance(attachmentId: number): Promise<UploadResult> {
    const body: ImgEnhanceReq = { attachmentId: attachmentId };
    return ApiClient.post<UploadResult>('/api/atta/img/enchance', body);
  }
}
