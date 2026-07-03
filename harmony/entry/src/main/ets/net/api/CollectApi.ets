// 收藏域 API：对齐官方网页端 /collection?pageid=3。
// 官方收藏页不是“收藏夹”模型，而是教师目录 + 条件查询 + 资源标签。

import { ApiClient } from '../ApiClient';
import { AttachmentEntity } from '../../models/Course';

export interface CollectCatalogItem {
  teacherId: number;
  teacherName: string;
  subjectId: number;
  subjectName: string;
}

export interface CollectTeacherItem {
  id: number;
  teacherUserId: number;
  subjectId: number;
  subjectName: string;
  userName: string;
}

export interface CollectTag {
  id: number;
  tagName: string;
  studentId?: number;
  check?: boolean;
}

export interface CollectTagRef {
  id: number;
}

export interface CollectConditionBody {
  subjectId: number;
  teacherId: number;
  contentType: number[];
  tagIds: number[];
}

export interface CollectDeleteBody {
  sourceId: number;
  sourceType: number;
  courseId: number;
  type: number;
}

export interface CollectTagEntityBody {
  tagName: string;
}

export interface CollectEntityBody {
  sourceId: number;
  sourceType: number;
  courseId: number;
  tagList: CollectTagRef[];
  type: number;
}

export interface CollectResourceContent {
  id?: number;
  courseId?: number;
  paperId?: number;
  textContent?: string;
  titleLevel?: number;
  attachmentName?: string;
  attachmentLinkAddress?: string;
  attachmentType?: number | string;
  attachmentExtraName?: string;
  attachmentSize?: string | null;
  questionStem?: string;
  relevanceQuestionStem?: string | null;
  answer?: string | null;
  questionAnalysis?: string | null;
  addToQuestionAnalysis?: string | null;
  questionType?: number;
  questionNumber?: string;
  questionScore?: number;
  studentAnswer?: string | null;
  studentScore?: number | null;
  judgeTag?: number | null;
  readOverTag?: number | null;
  childList?: CollectResourceContent[] | null;
  attachmentEntityList?: AttachmentEntity[] | null;
  noteList?: object[] | null;
  draftList?: object[] | null;
  askShareDTOList?: object[] | null;
  associationList?: object[] | null;
  readAttachmentList?: AttachmentEntity[] | null;
  stuAttachmentList?: AttachmentEntity[] | null;
}

export interface CollectResource {
  sourceId: number;
  sourceType: number;
  courseId: number;
  type: number;
  courseName: string;
  createTime: string;
  tagList: CollectTag[];
  content: CollectResourceContent;
  contentType?: number;
  resourceType?: number;
  read?: boolean;
  replayRedTag?: boolean;
  asked?: boolean;
}

export interface CollectItem {
  contentType: number;
  resourceType?: number;
  content: CollectResource;
}

export class CollectApi {
  static async catalogRaw(): Promise<CollectCatalogItem[]> {
    return ApiClient.get<CollectCatalogItem[]>('/api/collect/catalog');
  }

  static async catalog(): Promise<CollectTeacherItem[]> {
    const rows = await CollectApi.catalogRaw();
    const out: CollectTeacherItem[] = [];
    rows.forEach((item: CollectCatalogItem) => {
      const teacher: CollectTeacherItem = {
        id: item.teacherId,
        teacherUserId: item.teacherId,
        subjectId: item.subjectId,
        subjectName: item.subjectName,
        userName: item.teacherName
      };
      out.push(teacher);
    });
    return out;
  }

  static async condition(body: CollectConditionBody): Promise<CollectItem[]> {
    return ApiClient.post<CollectItem[]>('/api/collect/condition', body);
  }

  static async remove(body: CollectDeleteBody): Promise<void> {
    await ApiClient.del<object>('/api/collect/entity', body);
  }

  static async tags(): Promise<CollectTag[]> {
    return ApiClient.get<CollectTag[]>('/api/collect/tag/list');
  }

  static async createTag(tagName: string): Promise<CollectTag> {
    const body: CollectTagEntityBody = { tagName: tagName };
    return ApiClient.post<CollectTag>('/api/collect/tag/entity', body);
  }

  static async saveEntity(body: CollectEntityBody): Promise<void> {
    await ApiClient.put<object>('/api/collect/entity', body);
  }

  static async deleteTags(body: CollectEntityBody): Promise<void> {
    await ApiClient.put<object>('/api/collect/entity/del/tags', body);
  }
}
