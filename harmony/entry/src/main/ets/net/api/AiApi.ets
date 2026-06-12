// AI 域 API：提问、错题库、知识库、reform。
// 对照 Vue chunk: ai/stu/ask, ai/stu/{x}/Lib/{x}/wrongQuestion, lib/overView, reform

import { ApiClient } from '../ApiClient';

export interface AiQuestion {
  question: string;
  courseId?: number;
  paperId?: number;
}

export interface AiAnswer {
  id: number;
  question: string;
  answer: string;
  createTime: string;
}

export interface WrongQuestion {
  id: number;
  questionId: number;
  courseId?: number;
  paperId?: number;
  questionStem: string;
  questionType: number;
  answer: string | null;
  studentAnswer: string | null;
  questionAnalysis: string | null;
  wrongCause: string | null;
  createTime: string;
}

export interface LibOverview {
  id: number;
  libName: string;
  libType: number;
  totalCount: number;
  wrongCount: number;
  correctRate: string | null;
}

export class AiApi {
  static async ask(question: string): Promise<AiAnswer> {
    return ApiClient.post<AiAnswer>('/api/ai/stu/ask', { question } as object);
  }

  static async history(page: number, size: number): Promise<AiAnswer[]> {
    return ApiClient.get<AiAnswer[]>(`/api/ai/stu/ask/history?page=${page}&size=${size}`);
  }

  static async wrongQuestions(libId: number, page: number, size: number): Promise<WrongQuestion[]> {
    return ApiClient.get<WrongQuestion[]>(
      `/api/ai/stu/wrongQuestion?libId=${libId}&page=${page}&size=${size}`);
  }

  static async libOverview(): Promise<LibOverview[]> {
    return ApiClient.get<LibOverview[]>('/api/lib/overView');
  }

  static async reform(questionId: number, wrongCause: string): Promise<void> {
    await ApiClient.post<object>('/api/ai/stu/reform',
      { questionId, wrongCause } as object);
  }
}
