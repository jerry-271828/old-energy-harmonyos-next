// 错题原因 API: qwc/*
// 来源：真机/Playwright 抓包（2026-07-03）
//   list  → POST /api/qwc/list   body {studentId, courseId}
//   save  → POST /api/qwc/entity body {id(0=新建/>0=更新), courseId, questionId, studentId, wrongCause:number}
// wrongCause 枚举（后端存 1-6 整数）：
//   1=粗心大意 2=没有思路 3=知识概念 4=过程错误 5=结果错误 6=没看懂题
import { ApiClient } from '../ApiClient';

export const QWC_LABELS: string[] =
  ['粗心大意', '没有思路', '知识概念', '过程错误', '结果错误', '没看懂题'];

export interface QwcRecord {
  id: number;
  courseId?: number;
  paperId?: number;
  questionId: number;
  studentId: number;
  wrongCause: number;    // 1-6；曾错误地声明为 string
  updateTime: string;
}

interface QwcListReq {
  studentId: number;
  courseId?: number;
  paperId?: number;
}

interface QwcSaveReq {
  id: number;
  courseId?: number;
  paperId?: number;
  questionId: number;
  studentId: number;
  wrongCause: number;
}

export class QwcApi {
  // 加载本课件 / 试卷所有错因记录（失败返回空数组，不抛）
  static async list(courseId: number, kind: string = 'course'): Promise<QwcRecord[]> {
    try {
      const body: QwcListReq = kind === 'paper'
        ? { studentId: ApiClient.getUserId(), paperId: courseId }
        : { studentId: ApiClient.getUserId(), courseId: courseId };
      return await ApiClient.post<QwcRecord[]>('/api/qwc/list', body);
    } catch (e) {
      return [];
    }
  }

  // 新建或更新一条错因记录。id=0 → 新建；id>0 → 更新（使用上次 save 返回的 id）。
  static async save(
    entityId: number,
    questionId: number,
    wrongCause: number,
    existingId: number,
    kind: string = 'course'
  ): Promise<QwcRecord> {
    const body: QwcSaveReq = {
      id: existingId,
      questionId: questionId,
      studentId: ApiClient.getUserId(),
      wrongCause: wrongCause
    };
    if (kind === 'paper') {
      body.paperId = entityId;
    } else {
      body.courseId = entityId;
    }
    return ApiClient.post<QwcRecord>('/api/qwc/entity', body);
  }
}
