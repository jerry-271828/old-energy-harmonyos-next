// 后端响应公共包装与错误类型。
// 所有 /exam/api/* 接口的响应都是 { code, message, time, extra }，
// code === 0 表示成功，业务数据在 extra。

export interface ApiResp<T> {
  code: number;
  message: string;
  time?: number;
  extra?: T;
}

export class ApiError extends Error {
  readonly code: number;        // 业务 code（HTTP 层错误时为 -1）
  readonly httpStatus: number;  // HTTP 状态码（未知时 0）

  constructor(message: string, code: number, httpStatus: number) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
    this.httpStatus = httpStatus;
  }
}
