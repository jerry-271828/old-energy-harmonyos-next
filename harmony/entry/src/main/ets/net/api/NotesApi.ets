// 笔记域 API: notes/*
import { ApiClient } from '../ApiClient';

export interface NoteItem {
  id: number;
  courseId?: number;
  paperId?: number;
  questionId?: number;
  studentId: number;
  content: string;
  createTime: string;
  updateTime: string;
}

export class NotesApi {
  static async list(page: number, size: number): Promise<NoteItem[]> {
    return ApiClient.get<NoteItem[]>(`/api/notes/list?page=${page}&size=${size}`);
  }

  static async save(courseId: number, questionId: number, content: string): Promise<NoteItem> {
    return ApiClient.post<NoteItem>('/api/notes/save',
      { courseId, questionId, content } as object);
  }

  static async update(id: number, content: string): Promise<void> {
    await ApiClient.put<object>(`/api/notes/${id}`, { content } as object);
  }

  static async remove(id: number): Promise<void> {
    await ApiClient.del<object>(`/api/notes/${id}`, null);
  }
}
