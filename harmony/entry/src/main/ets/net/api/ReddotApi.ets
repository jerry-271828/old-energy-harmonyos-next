// 红点 API（服务端维护的"有更新"集合）。
//   course 维度: /api/catalog/reddot（GET 全量）/add/course/{id} /eliminate/course/{id}
//   paper  维度: /api/paper/catalog/reddot 同构

import { ApiClient } from '../ApiClient';
import { ReddotSets, PaperReddotSets } from '../../models/Catalog';

export class ReddotApi {
  static async courseSets(): Promise<ReddotSets> {
    return ApiClient.get<ReddotSets>('/api/catalog/reddot');
  }

  static async paperSets(): Promise<PaperReddotSets> {
    return ApiClient.get<PaperReddotSets>('/api/paper/catalog/reddot');
  }

  // 消红点：进入课件时调用（对照 Vue：GET eliminate/course/{courseId}）
  static async eliminateCourse(courseId: number): Promise<void> {
    await ApiClient.get<object>(`/api/catalog/reddot/eliminate/course/${courseId}`);
  }

  static async eliminatePaper(paperId: number): Promise<void> {
    await ApiClient.get<object>(`/api/paper/catalog/reddot/eliminate/paper/${paperId}`);
  }
}
