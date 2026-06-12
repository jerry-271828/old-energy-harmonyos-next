// 用户信息（/api/user/*）与我的教师（/api/student/teacher/entity）。

import { ApiClient } from '../ApiClient';
import { UserInfo, SchoolItem, TeacherEntity } from '../../models/User';

interface UptPwdReq {
  oldPwd: string;
  newPwd: string;
}

export class UserApi {
  static async info(): Promise<UserInfo> {
    return ApiClient.get<UserInfo>('/api/user/info');
  }

  static async schoolList(): Promise<SchoolItem[]> {
    return ApiClient.get<SchoolItem[]>('/api/user/school/list');
  }

  static async teachers(): Promise<TeacherEntity[]> {
    return ApiClient.get<TeacherEntity[]>('/api/student/teacher/entity');
  }

  // 考试页的教师列表（paper 维度）
  static async paperTeachers(): Promise<TeacherEntity[]> {
    return ApiClient.get<TeacherEntity[]>('/api/student/teacher/entity/paper');
  }

  static async updatePwd(oldPwd: string, newPwd: string): Promise<void> {
    const body: UptPwdReq = { oldPwd: oldPwd, newPwd: newPwd };
    await ApiClient.post<object>('/api/user/upt/pwd', body);
  }

  static async lookbackTime(): Promise<number> {
    return ApiClient.get<number>('/api/user/student/lookbacktime');
  }
}
