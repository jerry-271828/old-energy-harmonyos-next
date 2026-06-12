// 问答域 API: ask/* 师生互动问答
import { ApiClient } from '../ApiClient';

export interface AskQuestion {
  id: number;
  courseId?: number;
  paperId?: number;
  questionId?: number;
  studentId: number;
  content: string;
  replyContent: string | null;
  replyTime: string | null;
  createTime: string;
  readTag: number;
}

export class AskApi {
  static async list(page: number, size: number): Promise<AskQuestion[]> {
    return ApiClient.get<AskQuestion[]>(`/api/ask/list?page=${page}&size=${size}`);
  }

  static async submit(courseId: number, questionId: number, content: string): Promise<void> {
    await ApiClient.post<object>('/api/ask/submit',
      { courseId, questionId, content } as object);
  }

  static async detail(id: number): Promise<AskQuestion> {
    return ApiClient.get<AskQuestion>(`/api/ask/${id}`);
  }
}
