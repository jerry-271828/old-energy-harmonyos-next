// 登录页：玻璃卡片 + 学号/密码 + 记住密码。
// 对照 Web 端 /login：POST /exam/login/api/stu/signin {phoneNumber, pwd}。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../theme/Theme';
import { SessionStore } from '../store/SessionStore';
import { GlassCard } from '../components/glass/GlassKit';
import { ApiError } from '../models/ApiTypes';

const DOMAIN = 0x0002;
const TAG = 'LoginPage';

@ComponentV2
export struct LoginPage {
  @Param onLogin: () => void = () => {};
  @Local account: string = SessionStore.instance.account;
  @Local pwd: string = SessionStore.instance.pwd;
  @Local remember: boolean = SessionStore.instance.remember;
  @Local showPwd: boolean = false;
  @Local busy: boolean = false;
  @Local errorMsg: string = '';

  private async doLogin(): Promise<void> {
    if (this.busy) {
      return;
    }
    const acc = this.account.trim();
    const pw = this.pwd;
    if (acc.length === 0 || pw.length === 0) {
      this.errorMsg = '请输入学号和密码';
      return;
    }
    this.busy = true;
    this.errorMsg = '正在登录...';
    hilog.info(DOMAIN, TAG, 'login submit');
    try {
      await SessionStore.instance.signin(acc, pw, this.remember);
      this.errorMsg = '';
      hilog.info(DOMAIN, TAG, 'login ok');
      this.onLogin();
    } catch (e) {
      if (e instanceof ApiError) {
        this.errorMsg = e.message;
      } else {
        const err = e as Error;
        this.errorMsg = err.message || '登录失败，请检查网络';
      }
      hilog.warn(DOMAIN, TAG, 'login failed: %{public}s', this.errorMsg);
    } finally {
      this.busy = false;
    }
  }

  @Builder
  loginCardContent() {
    Column({ space: 18 }) {
      Text('用户登录（学生端）')
        .fontSize(Theme.F_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)

      TextInput({ placeholder: '请输入学号', text: this.account })
        .type(InputType.USER_NAME)
        .height(48)
        .borderRadius(Theme.R_LG)
        .backgroundColor('#F0F2F5')
        .fontSize(Theme.F_BODY)
        .onChange((v: string) => {
          this.account = v;
        })
        .onSubmit(() => {
          this.doLogin();
        })

      Row({ space: 8 }) {
        TextInput({ placeholder: '请输入密码', text: this.pwd })
          .type(this.showPwd ? InputType.Normal : InputType.Password)
          .showPasswordIcon(false)
          .height(48)
          .layoutWeight(1)
          .borderRadius(Theme.R_LG)
          .backgroundColor('#F0F2F5')
          .fontSize(Theme.F_BODY)
          .onChange((v: string) => {
            this.pwd = v;
          })
          .onSubmit(() => {
            this.doLogin();
          })
        SymbolGlyph(this.showPwd ? $r('sys.symbol.eye') : $r('sys.symbol.eye_slash'))
          .fontSize(22)
          .fontColor([Theme.TEXT_2])
          .onClick(() => {
            this.showPwd = !this.showPwd;
          })
      }
      .alignItems(VerticalAlign.Center)

      if (this.errorMsg.length > 0) {
        Text(this.errorMsg)
          .fontSize(Theme.F_SUB)
          .fontColor(Theme.DANGER)
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      Button(this.busy ? '登录中...' : '开始使用', { type: ButtonType.Normal, stateEffect: true })
      .width('100%')
      .height(48)
      .backgroundColor(Theme.PRIMARY)
      .borderRadius(Theme.R_XL)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(Color.White)
      .enabled(!this.busy)
      .onClick(() => {
        this.doLogin();
      })

      Row({ space: 6 }) {
        Checkbox()
          .select(this.remember)
          .selectedColor(Theme.PRIMARY)
          .width(18)
          .height(18)
          .onChange((v: boolean) => {
            this.remember = v;
          })
        Text('记住密码')
          .fontSize(Theme.F_SUB)
          .fontColor(Theme.TEXT_2)
          .onClick(() => {
            this.remember = !this.remember;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
  }

  build() {
    Stack() {
      // 米黄底 + 轻微径向渐变，呼应护眼配色
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 160,
          colors: [['#FDFAF2', 0], [Theme.BG_CREAM, 0.5], ['#F1E9D6', 1]]
        })

      Column({ space: 26 }) {
        Text('新能源课程系统')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)

        Column() {
          GlassCard({ innerPadding: 26 }) {
            this.loginCardContent()
          }
        }
        .width('86%')
        .constraintSize({ maxWidth: 420 })

        Text('爆改新能源 · HarmonyOS 原生版')
          .fontSize(Theme.F_MINI)
          .fontColor(Theme.TEXT_3)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
