// 登录/登出/注册/找回（/exam/login/api/*）。

import { http } from '@kit.NetworkKit';
import { ApiClient } from '../ApiClient';
import { UserInfo, SigninReq } from '../../models/User';

export class AuthApi {
  static async signin(account: string, pwd: string): Promise<UserInfo> {
    const body: SigninReq = { phoneNumber: account, pwd: pwd };
    const full = await ApiClient.requestFull<UserInfo>(
      http.RequestMethod.POST, '/login/api/stu/signin', body, false);
    const user = full.resp.extra as UserInfo;
    if (user && user.userId > 0) {
      ApiClient.setUserId(user.userId);
    }
    const token = ApiClient.extractToken(full.headers);
    if (token.length > 0) {
      ApiClient.setToken(token);
    }
    return user;
  }

  static async logout(): Promise<void> {
    try {
      await ApiClient.get<object>('/login/api/logout');
    } finally {
      ApiClient.setUserId(0);
      ApiClient.setToken('');
    }
  }
}
