// 学习域 API：course（课件）与 paper（考试）完全同构，
// 仅 URL 中 'course' / 'paper' 段不同——用 StudyKind 参数化，一份实现两用。
// 方法与请求体均对照 Vue 前端源码（/tmp/stu_app.js function a/i/u/c/l...）确认。

import { ApiClient } from '../ApiClient';
import { CourseListItem, CourseEntityInfo, RawContentBlock, CourseBlock,
  TextBlockContent, AttachmentEntity, CourseStatistics } from '../../models/Course';
import { QuestionContent, AnswerRecord } from '../../models/Question';
import { CatalogNode } from '../../models/Catalog';

export type StudyKind = 'course' | 'paper';

interface SubmitCourseReq {
  courseId?: number;
  paperId?: number;
}

// 单题保存请求体：POST /api/student/{kind}/entity/{courseId}/question/{questionId}
// body 即本对象（对照 Vue: aP("POST", e) + url 用 e.courseId/e.questionId）
export interface SaveAnswerBody {
  courseId?: number;
  paperId?: number;
  questionId: number;
  studentAnswer: string | null;
}

export class StudyApi {
  readonly kind: StudyKind;

  private constructor(kind: StudyKind) {
    this.kind = kind;
  }

  static readonly course: StudyApi = new StudyApi('course');
  static readonly paper: StudyApi = new StudyApi('paper');

  // ---- 目录 ----

  // 某教师的目录树（course: /api/student/catalog/entity/{tid}；paper: /api/student/paper/catalog/entity/{tid}）
  async catalogTree(teacherUserId: number): Promise<CatalogNode[]> {
    const path = this.kind === 'course'
      ? `/api/student/catalog/entity/${teacherUserId}`
      : `/api/student/paper/catalog/entity/${teacherUserId}`;
    return ApiClient.get<CatalogNode[]>(path);
  }

  // 目录节点下的课件/试卷列表
  async listByCatalog(catalogId: number): Promise<CourseListItem[]> {
    return ApiClient.get<CourseListItem[]>(
      `/api/student/${this.kind}/entity/catalog/${catalogId}`);
  }

  // ---- 课件实体 ----

  async entityInfo(id: number): Promise<CourseEntityInfo> {
    return ApiClient.get<CourseEntityInfo>(`/api/student/${this.kind}/entity/${id}`);
  }

  async rawContent(id: number): Promise<RawContentBlock[]> {
    return ApiClient.get<RawContentBlock[]>(`/api/student/${this.kind}/entity/${id}/content`);
  }

  // content 块解析：按 contentType 落到强类型字段
  async content(id: number): Promise<CourseBlock[]> {
    const raw = await this.rawContent(id);
    const out: CourseBlock[] = [];
    if (!raw) {
      return out;
    }
    for (let i = 0; i < raw.length; i++) {
      const r = raw[i];
      const b = new CourseBlock();
      b.contentType = r.contentType;
      b.idx = r.idx;
      if (r.contentType === 0) {
        b.text = r.content as TextBlockContent;
      } else if (r.contentType === 1) {
        b.attachment = r.content as AttachmentEntity;
      } else if (r.contentType === 2) {
        b.question = r.content as QuestionContent;
      }
      out.push(b);
    }
    return out;
  }

  async answers(id: number): Promise<AnswerRecord[]> {
    return ApiClient.get<AnswerRecord[]>(`/api/student/${this.kind}/entity/${id}/question`);
  }

  async statistics(id: number): Promise<CourseStatistics> {
    return ApiClient.get<CourseStatistics>(`/api/student/${this.kind}/entity/${id}/statistics`);
  }

  // ---- 作答 ----

  // 保存单题（选择题点选即存；isDraft 语义由 draft 接口承担）
  async saveAnswer(entityId: number, questionId: number,
    studentAnswer: string | null): Promise<AnswerRecord> {
    const body: SaveAnswerBody = { questionId: questionId, studentAnswer: studentAnswer };
    if (this.kind === 'course') {
      body.courseId = entityId;
    } else {
      body.paperId = entityId;
    }
    return ApiClient.post<AnswerRecord>(
      `/api/student/${this.kind}/entity/${entityId}/question/${questionId}`, body);
  }

  // 整卷提交（body 对照油猴快捷提交：{courseId} / {paperId}）
  async submit(entityId: number): Promise<void> {
    const body: SubmitCourseReq = {};
    if (this.kind === 'course') {
      body.courseId = entityId;
    } else {
      body.paperId = entityId;
    }
    await ApiClient.post<object>(`/api/student/${this.kind}/entity/${entityId}/submit`, body);
  }

  // 补交
  async resubmit(entityId: number): Promise<void> {
    const body: SubmitCourseReq = {};
    if (this.kind === 'course') {
      body.courseId = entityId;
    } else {
      body.paperId = entityId;
    }
    await ApiClient.post<object>(`/api/student/${this.kind}/entity/${entityId}/resubmit`, body);
  }

  // 作答附件（拍照/手写图）绑定与删除
  async bindAnswerAttachment(entityId: number, questionId: number,
    attachmentId: number, extraQuery: string): Promise<void> {
    await ApiClient.get<object>(
      `/api/student/${this.kind}/entity/${entityId}/question/${questionId}/attachment/${attachmentId}${extraQuery}`);
  }

  async deleteAnswerAttachment(entityId: number, questionId: number,
    attachmentId: number): Promise<void> {
    await ApiClient.get<object>(
      `/api/student/${this.kind}/entity/${entityId}/question/${questionId}/attachment/${attachmentId}/del`);
  }
}
