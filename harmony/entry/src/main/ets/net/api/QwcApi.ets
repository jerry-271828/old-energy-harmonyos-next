// 错题原因 API: qwc/*
import { ApiClient } from '../ApiClient';

export interface QwcRecord {
  id: number;
  courseId?: number;
  paperId?: number;
  questionId: number;
  studentId: number;
  wrongCause: string;
  createTime: string;
}

export class QwcApi {
  static async list(courseId: number): Promise<QwcRecord[]> {
    try {
      return await ApiClient.post<QwcRecord[]>(
        '/api/qwc/list',
        { studentId: ApiClient.getUserId(), courseId: courseId } as object);
    } catch (e) {
      return [];
    }
  }

  static async save(courseId: number, questionId: number, wrongCause: string): Promise<void> {
    await ApiClient.post<object>('/api/qwc/save',
      { courseId, questionId, wrongCause } as object);
  }
}
