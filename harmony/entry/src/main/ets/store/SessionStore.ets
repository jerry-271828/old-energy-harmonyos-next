// 会话仓库：token + 用户信息 + 记住密码/自动登录 + 静默重登（会话守护）。
// 持久化走 GmStorage（preferences 'gm_storage'，与旧 WebView 壳同仓）。

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { GmStorage } from '../bridge/GmStorage';
import { ApiClient } from '../net/ApiClient';
import { AuthApi } from '../net/api/AuthApi';
import { UserInfo } from '../models/User';

const DOMAIN = 0x0002;
const TAG = 'SessionStore';

const K_TOKEN = 'bxny_token';
const K_ACCOUNT = 'bxny_account';
const K_PWD = 'bxny_pwd';
const K_REMEMBER = 'bxny_remember';
const K_USER = 'bxny_user_info';

const AUTO_LOGIN_TIMEOUT_MS = 8000;   // 无缓存会话时自动登录的硬超时，避免冷网络下开屏卡死

@ObservedV2
export class SessionStore {
  static readonly instance: SessionStore = new SessionStore();

  @Trace loggedIn: boolean = false;
  @Trace user: UserInfo | null = null;
  @Trace booting: boolean = true;     // 启动期自动登录进行中（显示开屏 loading）

  account: string = '';
  pwd: string = '';
  remember: boolean = true;

  private constructor() {
  }

  // EntryAbility.onCreate 调（GmStorage.init 之后）
  init(_ctx: common.UIAbilityContext): void {
    this.account = GmStorage.getSync(K_ACCOUNT);
    this.pwd = GmStorage.getSync(K_PWD);
    this.remember = GmStorage.getSync(K_REMEMBER) !== '0';
    const token = GmStorage.getSync(K_TOKEN);
    if (token.length > 0) {
      ApiClient.setToken(token);
    }
    const userJson = GmStorage.getSync(K_USER);
    if (userJson.length > 0) {
      try {
        this.user = JSON.parse(userJson) as UserInfo;
      } catch (e) {
        this.user = null;
      }
    }
    // 注册静默重登：ApiClient 发现会话失效时回调
    ApiClient.reloginProvider = (): Promise<boolean> => {
      return this.silentRelogin();
    };
  }

  // 启动自动登录：有记住的凭据就直接 signin（语义对应油猴"自动登录"开关，
  // 该开关在脚本里是强制开启的，这里同样默认开启，可在设置页关）。
  async tryAutoLogin(autoLoginEnabled: boolean): Promise<void> {
    // 自动登录关：始终回登录页，不拿缓存会话自动进入。
    if (!autoLoginEnabled) {
      this.booting = false;
      return;
    }
    const hasCreds = this.account.length > 0 && this.pwd.length > 0;
    // 有缓存会话（init 已把 token 装入 ApiClient、user 反序列化）：乐观进入，登录刷新丢到
    // 后台，绝不阻塞首屏——这是开屏卡死的直接根因。token 失效由静默重登在首个 API 401 兜底。
    if (ApiClient.hasToken() && this.user !== null) {
      this.loggedIn = true;
      this.booting = false;
      if (hasCreds) {
        this.refreshLoginInBackground();
      }
      return;
    }
    // 无缓存会话但有凭据：做一次带硬超时的登录，避免冷网络（DNS/TLS 握手慢）下开屏无限等待。
    if (hasCreds) {
      try {
        await SessionStore.withTimeout(
          this.signin(this.account, this.pwd, this.remember), AUTO_LOGIN_TIMEOUT_MS);
        hilog.info(DOMAIN, TAG, 'auto login ok');
      } catch (e) {
        const err = e as BusinessError;
        hilog.warn(DOMAIN, TAG, 'auto login failed/timeout: %{public}s', err.message);
      }
    }
    this.booting = false;
  }

  // 后台静默刷新登录态：成功换到新 token；失败保留缓存会话（由静默重登在后续请求兜底）。
  private refreshLoginInBackground(): void {
    this.signin(this.account, this.pwd, this.remember)
      .then(() => {
        hilog.info(DOMAIN, TAG, 'background login refresh ok');
      })
      .catch((e: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'background login refresh failed: %{public}s', e.message);
      });
  }

  // 给 Promise 套硬超时：超时即 reject。底层请求仍会在后台跑完——若它最终 signin 成功，
  // signin 内部照常置 loggedIn=true，Index 会自动从开屏/登录页切到主页，是一种自愈而非 bug。
  private static withTimeout<T>(p: Promise<T>, ms: number): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const timer = setTimeout(() => {
        reject(new Error('timeout'));
      }, ms);
      p.then((v: T) => {
        clearTimeout(timer);
        resolve(v);
      }).catch((e: Object) => {
        clearTimeout(timer);
        reject(e);
      });
    });
  }

  async signin(account: string, pwd: string, remember: boolean): Promise<UserInfo> {
    const user = await AuthApi.signin(account, pwd);
    this.user = user;
    this.loggedIn = true;
    this.account = account;
    this.pwd = pwd;
    this.remember = remember;
    GmStorage.putAsync(K_TOKEN, ApiClient.getToken());
    GmStorage.putAsync(K_USER, JSON.stringify(user));
    if (remember) {
      GmStorage.putAsync(K_ACCOUNT, account);
      GmStorage.putAsync(K_PWD, pwd);
      GmStorage.putAsync(K_REMEMBER, '1');
    } else {
      GmStorage.putAsync(K_ACCOUNT, '');
      GmStorage.putAsync(K_PWD, '');
      GmStorage.putAsync(K_REMEMBER, '0');
    }
    return user;
  }

  // 静默重登（ApiClient 会话守护回调）
  private async silentRelogin(): Promise<boolean> {
    if (this.account.length === 0 || this.pwd.length === 0) {
      return false;
    }
    try {
      await AuthApi.signin(this.account, this.pwd);
      GmStorage.putAsync(K_TOKEN, ApiClient.getToken());
      hilog.info(DOMAIN, TAG, 'silent relogin ok');
      return true;
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'silent relogin failed: %{public}s', err.message);
      this.loggedIn = false;
      return false;
    }
  }

  async logout(): Promise<void> {
    try {
      await AuthApi.logout();
    } catch (e) {
      // 网络失败也照样本地登出
    }
    this.loggedIn = false;
    this.user = null;
    GmStorage.putAsync(K_TOKEN, '');
  }
}
