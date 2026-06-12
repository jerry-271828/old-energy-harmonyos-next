// 用户/登录相关模型（字段对照 /exam/login/api/stu/signin 与 /exam/api/user/* 实测响应）。

export interface UserInfo {
  userId: number;
  userName: string;
  number: string;             // 学号
  mobile: string | null;
  roleId: number;
  sex: number;
  schoolId: number;
  schoolName: string;
  mail: string | null;
  periodOfValidity: string | null;
  lookBackTime: number | null; // 视频回看时长(分钟)
  isWhite: number;
  libPrivilege: boolean;
}

export interface SigninReq {
  phoneNumber: string;
  pwd: string;
}

export interface SchoolItem {
  id: number;
  schoolName: string;
}

// 我的教师列表项（/api/student/teacher/entity）
export interface TeacherEntity {
  id: number;
  teacherUserId: number;
  studentUserId: number;
  userName: string;
  sex: number;
  phoneNumber: string | null;
  schoolId: number;
  schoolName: string;
  subjectCode: string | null;
  subjectName: string | null;
  mappingStatus: number;
  newCourseFlag: boolean;     // 该教师有新课（红点）
  publishFlag: boolean;
}
