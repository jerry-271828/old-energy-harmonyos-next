// 登录/登出/注册/找回（/exam/login/api/*）。

import { http } from '@kit.NetworkKit';
import { ApiClient } from '../ApiClient';
import { UserInfo, SigninReq } from '../../models/User';

export class AuthApi {
  // 登录：成功后从 Set-Cookie 提取 token 并装入 ApiClient。
  // 返回 UserInfo；失败抛 ApiError（message 为服务端文案，如"密码错误"）。
  static async signin(account: string, pwd: string): Promise<UserInfo> {
    const body: SigninReq = { phoneNumber: account, pwd: pwd };
    const full = await ApiClient.requestFull<UserInfo>(
      http.RequestMethod.POST, '/login/api/stu/signin', body, false);
    const token = ApiClient.extractToken(full.headers);
    if (token.length > 0) {
      ApiClient.setToken(token);
    }
    return full.resp.extra as UserInfo;
  }

  static async logout(): Promise<void> {
    try {
      await ApiClient.get<object>('/login/api/logout');
    } finally {
      ApiClient.setToken('');
    }
  }
}
