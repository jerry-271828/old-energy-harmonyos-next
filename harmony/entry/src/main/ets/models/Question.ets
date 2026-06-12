// 题目与作答记录模型。
// 来源：content 接口 contentType=2 块、/question 接口实测响应。

import { AttachmentEntity } from './Course';

// 题目本体（contentType 2 的 content）
export interface QuestionContent {
  id: number;
  creator: number;
  originQuestionId: number;
  courseId?: number;
  paperId?: number;
  questionType: number;          // 0 单选 1 多选 …（解答/拍照按 answerWay* 区分）
  difficultyLevel: number;
  firstQuestionId: number | null;
  questionStem: string;          // 题干 HTML
  relevanceQuestionStem: string | null;
  answer: string | null;         // 标准答案（"D" / "AB" / 解答题为 HTML）
  questionAnalysis: string | null;
  addToQuestionAnalysis: string | null;
  mustDoSwitch: number;
  questionNumber: string;
  questionScore: number;
  questionIndex: number;
  answerWayHandle: number;       // 手写/上传作答
  answerWayPhoto: number;        // 拍照作答
  answerWayTalking: number;
  answerWayVideo: number;
  answerWayKeyboard: number;     // 键盘文字作答
  answerCard: string | null;     // "A,B,C,D"
  chooseZoneCounts: number | null;
  originChooseZoneCounts: number | null;
  selfReadOverSwitch: number;
  previewAnswer: number;
  compositionTag: number;
  part: number;
  childList: QuestionContent[] | null;   // 一题多问的子题
  questionParentId: number | null;
}

// 学生作答记录（/question 接口数组项）
export interface AnswerRecord {
  id: number;
  courseId?: number;
  paperId?: number;
  questionId: number;
  questionNumber: string;
  questionIndex: number;
  studentId: number;
  userName: string;
  firstQuestionId: number | null;
  studentAnswer: string | null;
  studentScore: number | null;
  judgeTag: number | null;       // 1 对 / 0 错 / 2 半对
  readOverTag: number | null;    // 已批阅
  teacherReadOverContent: string | null;
  resubmitTag: number;           // 1 = 可补交/已被打回
  autoSubmitTag: number;
  abandonTag: number;
  anonymity: number;
  teacherMark: number;
  passAiTag: number;
  studentSubmitTime: string | null;
  attachments: AttachmentEntity[] | null;  // 拍照/手写上传的作答图
  isDraft: boolean;
  postilList: object[] | null;   // 教师批注
}

// 保存/提交作答的请求体（对照 Vue chunk 的 chooseBtn / 提交逻辑）
export interface SaveAnswerReq {
  courseId?: number;
  paperId?: number;
  questionId: number;
  studentAnswer: string | null;
}

export interface ErrorCauseRecord {
  id: number;
  courseId?: number;
  paperId?: number;
  questionId: number;
  studentId: number;
  wrongCause: string | null;
}
