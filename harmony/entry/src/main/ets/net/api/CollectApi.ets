// 收藏域 API：目录、条件搜索、标签管理。
// 对照 Vue chunk: collect/* 全套

import { ApiClient } from '../ApiClient';

export interface CollectFolder {
  id: number;
  folderName: string;
  studentId: number;
  collectCount: number;
  createTime: string;
}

export interface CollectItem {
  id: number;
  folderId: number;
  courseId?: number;
  paperId?: number;
  questionId: number;
  questionStem: string;
  questionType: number;
  answer: string | null;
  questionAnalysis: string | null;
  courseName: string | null;
  createTime: string;
  tags: string[] | null;
}

export interface CollectTag {
  id: number;
  tagName: string;
  studentId: number;
}

interface CreateFolderBody {
  folderName: string;
}

interface AddItemBody {
  folderId: number;
  questionId: number;
  courseId?: number;
  paperId?: number;
}

interface AddTagBody {
  tagName: string;
}

export class CollectApi {
  static async folders(): Promise<CollectFolder[]> {
    return ApiClient.get<CollectFolder[]>('/api/collect/folder');
  }

  static async createFolder(name: string): Promise<CollectFolder> {
    const body: CreateFolderBody = { folderName: name };
    return ApiClient.post<CollectFolder>('/api/collect/folder', body);
  }

  static async deleteFolder(id: number): Promise<void> {
    await ApiClient.del<object>(`/api/collect/folder/${id}`, null);
  }

  static async items(folderId: number, page: number, size: number): Promise<CollectItem[]> {
    return ApiClient.get<CollectItem[]>(
      `/api/collect/items?folderId=${folderId}&page=${page}&size=${size}`);
  }

  static async addItem(folderId: number, questionId: number,
    courseId?: number, paperId?: number): Promise<void> {
    const body: AddItemBody = { folderId: folderId, questionId: questionId };
    if (courseId !== undefined) {
      body.courseId = courseId;
    }
    if (paperId !== undefined) {
      body.paperId = paperId;
    }
    await ApiClient.post<object>('/api/collect/item', body);
  }

  static async removeItem(id: number): Promise<void> {
    await ApiClient.del<object>(`/api/collect/item/${id}`, null);
  }

  static async tags(): Promise<CollectTag[]> {
    return ApiClient.get<CollectTag[]>('/api/collect/tag');
  }

  static async addTag(tagName: string): Promise<CollectTag> {
    const body: AddTagBody = { tagName: tagName };
    return ApiClient.post<CollectTag>('/api/collect/tag', body);
  }

  static async tagItem(itemId: number, tagId: number): Promise<void> {
    await ApiClient.post<object>(`/api/collect/item/${itemId}/tag/${tagId}`, null);
  }
}
