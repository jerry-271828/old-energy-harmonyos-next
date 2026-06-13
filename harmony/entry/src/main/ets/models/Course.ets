// 课件（course entity）域模型。
// 来源接口（字段对照真实响应采样）：
//   GET /api/student/course/entity/catalog/{catalogId}   → CourseListItem[]
//   GET /api/student/course/entity/{courseId}            → CourseEntityInfo
//   GET /api/student/course/entity/{courseId}/content    → RawContentBlock[]
//   GET /api/student/course/entity/{courseId}/statistics → CourseStatistics
// paper（考试）侧结构同构，复用本文件类型。

import { QuestionContent } from './Question';

export interface CourseListItem {
  id: number;
  originCourseId: number;
  courseType: number;
  courseName: string;
  catalogId: number;
  courseTagId: number;
  coursePublishTime: string | null;
  creator: number;
  classId: number;
  courseIndex: number;
  coursePublishTag: number;
  courseFinishTag: number;
  jobStatus: number;
  createTime: string;
  updateTime: string;
}

// 进入课件/试卷详情页的导航参数。
// createTime 来自列表项，补交(resubmit)时作为 courseBeginTime 必带字段透传。
export interface CourseDetailParam {
  id: number;
  createTime: string;
}

// entity/{id}：学生与这份课件的关联信息（用时/得分率/提交窗口）
export interface CourseEntityInfo {
  id: number;
  courseId: number;
  studentId: number;
  creator: number;
  groupId: number;
  coursePublishTime: string | null;
  mappingStatus: number;
  statisticsStatus: number;
  jobStatus: number;
  courseBeginTime: string | null;
  courseEndTime: string | null;
  courseResubmitTime: string | null;
  courseTime: number;          // 累计用时(分钟)
  scoring: number | null;
  scoringRate: string | null;  // "20.9%"
  updateTime: string;
  currTime: string;            // 服务器当前时间（自动提交倒计时基准）
}

// contentType 0：富文本块
export interface TextBlockContent {
  id: number;
  courseId: number;
  textContent: string;        // quill 受限 HTML
  titleLevel: number;         // 1/2 → 标题跳转目录项；0 → 普通段落
  textIndex: number;
  wordCounts: number;
  pointSwitch: number;
}

// contentType 1：附件块（PDF/视频/图片等）
export interface AttachmentEntity {
  id: number;
  attachmentName: string;
  attachmentLinkAddress: string;     // content 接口里是 DES 加密串；statistics 里是明文路径
  attachmentType: number;            // 4=视频 …（按扩展名兜底判断）
  attachmentExtraName: string;       // ".mp4" / ".pdf" / ".png"...
  mustHandleSwitch: number;
  creator: number;
  attachmentSize: string | null;
  attachmentDuration: string | null;
  attachmentPageCounts: number | null;
  convertStatus: number;
  courseAttachmentIndex: number;
  openTime: string | null;
  closeTime: string | null;
  downloadSwitch: number;
  replayRedTag: boolean;
  read: boolean;
}

// content 接口的原始块
export interface RawContentBlock {
  contentType: number;   // 0 文本 / 1 附件 / 2 题目
  idx: number;
  content: object;
}

// 解析后的强类型视图块（CourseApi.parseBlocks 产出）
export class CourseBlock {
  contentType: number = 0;
  idx: number = 0;
  text: TextBlockContent | null = null;
  attachment: AttachmentEntity | null = null;
  question: QuestionContent | null = null;
}

export interface KnowledgeLib {
  id: number;
  libType: number;
  libName: string | null;
}

export interface CourseStatistics {
  scoringRate: string | null;
  scoringRateMax: string | null;
  scoringRateAvg: string | null;
  courseBeginTime: string | null;
  courseEndTime: string | null;
  studentLibs: KnowledgeLib[] | null;
  // 注意：这里的 attachmentLinkAddress 是明文路径（如 /jyhr/uploadFile/xx.mp4），
  // 可用 id 反查 content 块对应附件的真实地址，绕过 deDes 解密。
  studentCourseAttachments: AttachmentEntity[] | null;
}
