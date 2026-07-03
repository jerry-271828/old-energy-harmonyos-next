// AI 域 API：对齐官方网页端 /ai?pageid=2。
// 官方 AI 不是全局聊天页，而是教师/学科维度的回顾、错题、知识模块分析。

import { ApiClient } from '../ApiClient';

export interface AiTeacher {
  id: number;
  subjectId: number;
  subjectName: string;
  userName: string;
  lookBackTime?: number;
}

export interface AiOverviewItem {
  id: number;
  teacherid?: number;
  teacherId?: number;
  courseid?: number;
  courseId?: number;
  subjectId?: number;
  subjectName: string;
  userName: string;
  totalCount: number;
  reformedCount: number;
  highCount: number;
  middleCount: number;
  lowCount: number;
  noMasterCount?: number;
}

export interface AiWrongQuestion {
  id: number;
  questionId: number;
  firstQuestionId?: number;
  dataId: number;
  dataType: number;
  dataName: string;
  questionType: number;
  totalScoring: number;
  difficultyLevel: number;
  wrongCause: number | string | null;
  publishTime: string;
  zhdf: number;
  reformType: number;
  reformTime: string | null;
  mustDoSwitch?: number;
  selfReadOverSwitch?: number;
  questionStem?: string;
  stem?: string;
  content?: string;
  questionContent?: string;
  answer?: string | null;
  studentAnswer?: string | null;
  questionAnalysis?: string | null;
}

export interface AiWrongQuestionOverview {
  totalCount: number;
  reformedCount: number;
  highCount: number;
  middleCount: number;
  lowCount: number;
  wrongQuestionList: AiWrongQuestion[];
}

export interface AiKnowledgeLibItem {
  id?: number;
  libId: number;
  libType: number;
  libNumber: string;
  libName: string;
  scoring: number;
  scoringRate: string;
  questionAllCount: number;
  errorQuestionCount: number;
  errorProportion: number;
  errorProportionRate: string;
  correctRateType: number;
  reformType: number;
  reformTime: string | null;
  reformCount: number | null;
}

export interface AiKnowledgeLibOverview {
  totalCount: number;
  noMasterCount: number;
  reformedCount: number;
  highCount: number;
  middleCount: number;
  lowCount: number;
  knowledgeLibList: AiKnowledgeLibItem[];
}

export interface AiCoursePaperItem {
  dataId: number;
  dataName: string;
  dataType?: number;
  publishTime: string;
}

export interface AiCoursePaperGroup {
  courseList: AiCoursePaperItem[];
  paperList: AiCoursePaperItem[];
}

export interface AiStudentRespond {
  questionId: number;
  studentAnswer?: string | null;
  answer?: string | null;
  questionAnalysis?: string | null;
}

export interface AiAskBody {
  sourceFirstType: number;
  sourceFirstId: number;
  sourceSecondType: number;
  sourceSecondId: number;
}

export interface AiAskAnswer {
  id?: number;
  answer?: string;
  content?: string;
  createTime?: string;
}

export interface AiReformBody {
  studentId: number;
  sourceId: number;
  sourceType: number;
  subjectId: number;
  reformType: number;
  sourceFirstType?: number;
}

interface AiLookbackTimeBody {
  id: number;
  lookBackTime: number;
}

export class AiApi {
  static async teachers(): Promise<AiTeacher[]> {
    return ApiClient.get<AiTeacher[]>('/api/ai/stu/teachers');
  }

  static async wrongQuestion(teacherId: number, lookBackTime: number): Promise<AiWrongQuestionOverview> {
    const suffix = lookBackTime > 0 ? `?lookBackTime=${lookBackTime}` : '';
    return ApiClient.get<AiWrongQuestionOverview>(
      `/api/ai/stu/${teacherId}/wrongQuestion${suffix}`);
  }

  static async overview(): Promise<AiOverviewItem[]> {
    return ApiClient.get<AiOverviewItem[]>('/api/ai/stu/overView');
  }

  static async lookbackOverview(items: AiTeacher[]): Promise<AiOverviewItem[]> {
    return ApiClient.post<AiOverviewItem[]>('/api/ai/stu/lookback/overView', items);
  }

  static async libOverview(): Promise<AiOverviewItem[]> {
    return ApiClient.get<AiOverviewItem[]>('/api/ai/stu/lib/overView');
  }

  static async knowledgeLib(teacherId: number): Promise<AiKnowledgeLibOverview> {
    return ApiClient.get<AiKnowledgeLibOverview>(`/api/ai/stu/${teacherId}/knowledgeLib`);
  }

  static async libWrongQuestion(teacherId: number, libId: number): Promise<AiWrongQuestion[]> {
    return ApiClient.get<AiWrongQuestion[]>(
      `/api/ai/stu/${teacherId}/Lib/${libId}/wrongQuestion`);
  }

  static async courseAndPaper(teacherId: number, lookBackTime: number): Promise<AiCoursePaperGroup> {
    const suffix = lookBackTime > 0 ? `?lookBackTime=${lookBackTime}` : '';
    return ApiClient.get<AiCoursePaperGroup>(`/api/ai/stu/${teacherId}/courseAndPaper${suffix}`);
  }

  static async setLookbackTime(userId: number, lookBackTime: number): Promise<void> {
    const body: AiLookbackTimeBody = {
      id: userId,
      lookBackTime: lookBackTime
    };
    await ApiClient.post<object>('/api/user/student/lookbacktime', body);
  }

  static async studentRespond(dataType: number, dataId: number,
    questionId: number): Promise<AiStudentRespond> {
    return ApiClient.get<AiStudentRespond>(
      `/api/ai/stu/respond/${dataType}/${dataId}/${questionId}`);
  }

  static async studentAsk(body: AiAskBody): Promise<AiAskAnswer> {
    return ApiClient.post<AiAskAnswer>('/api/ai/stu/ask', body);
  }

  static async reform(body: AiReformBody): Promise<void> {
    await ApiClient.post<object>('/api/ai/stu/reform', body);
  }
}
