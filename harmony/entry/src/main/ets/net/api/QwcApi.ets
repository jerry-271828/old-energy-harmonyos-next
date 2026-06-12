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
  static async get(courseId: number, questionId: number): Promise<QwcRecord | null> {
    try {
      return await ApiClient.get<QwcRecord>(
        `/api/qwc/get?courseId=${courseId}&questionId=${questionId}`);
    } catch (e) {
      return null;
    }
  }

  static async save(courseId: number, questionId: number, wrongCause: string): Promise<void> {
    await ApiClient.post<object>('/api/qwc/save',
      { courseId, questionId, wrongCause } as object);
  }
}
