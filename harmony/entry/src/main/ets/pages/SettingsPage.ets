// 设置页：个人信息卡 + 油猴设置项原生化（键沿用 bdfz_enhancer_settings_v3）
// + 网页版回退入口 + 退出登录。

import { Theme } from '../theme/Theme';
import { SessionStore } from '../store/SessionStore';
import { SettingsStore } from '../store/SettingsStore';
import { UiStore } from '../store/UiStore';
import { GlassCard, SquishButton } from '../components/glass/GlassKit';
import { Nav } from '../utils/Nav';

@ComponentV2
export struct SettingRow {
  @Param title: string = '';
  @Param desc: string = '';
  @Param value: boolean = false;
  @Param onToggle: (v: boolean) => void = (_v: boolean) => {};

  build() {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(this.title)
          .fontSize(Theme.F_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT)
        if (this.desc.length > 0) {
          Text(this.desc)
            .fontSize(Theme.F_MINI)
            .fontColor(Theme.TEXT_3)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: this.value })
        .selectedColor(Theme.PRIMARY)
        .onChange((v: boolean) => {
          this.onToggle(v);
        })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }
}

@ComponentV2
export struct SettingsPage {
  session: SessionStore = SessionStore.instance;
  settings: SettingsStore = SettingsStore.instance;
  ui: UiStore = UiStore.instance;
  @Local confirmLogout: boolean = false;

  @Builder
  userCard() {
    Row({ space: 16 }) {
      Column() {
        Text(this.session.user ? this.session.user.userName.substring(0, 1) : '?')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(60)
      .height(60)
      .borderRadius(30)
      .backgroundColor(Theme.PRIMARY)
      .justifyContent(FlexAlign.Center)

      Column({ space: 4 }) {
        Text(this.session.user ? this.session.user.userName : '未登录')
          .fontSize(Theme.F_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
        Text(this.session.user
          ? `学号 ${this.session.user.number} · ${this.session.user.schoolName}`
          : '')
          .fontSize(Theme.F_SUB)
          .fontColor(Theme.TEXT_2)
        if (this.session.user && this.session.user.periodOfValidity) {
          Text(`账号有效期至 ${this.session.user.periodOfValidity}`)
            .fontSize(Theme.F_MINI)
            .fontColor(Theme.TEXT_3)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }

  @Builder
  lgIntensityRow() {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text('沉浸光感强度')
          .fontSize(Theme.F_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT)
        Text('Liquid Glass 动效与材质等级')
          .fontSize(Theme.F_MINI)
          .fontColor(Theme.TEXT_3)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row({ space: 0 }) {
        ForEach([1, 2, 3], (lv: number) => {
          Text(lv === 1 ? '轻' : (lv === 2 ? '中' : '满'))
            .fontSize(Theme.F_SUB)
            .fontColor(this.settings.lgIntensity === lv ? Color.White : Theme.TEXT_2)
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor(this.settings.lgIntensity === lv ? Theme.PRIMARY : Color.Transparent)
            .borderRadius(Theme.R_XL)
            .onClick(() => {
              this.settings.lgIntensity = lv;
              this.settings.save();
            })
        }, (lv: number) => lv.toString())
      }
      .backgroundColor('#F0F2F5')
      .borderRadius(Theme.R_XL)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text('设 置')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .width('100%')

        Column() {
        GlassCard({ innerPadding: 20 }) {
          this.userCard()
        }
        }
        .width('100%')

        Column() {
        GlassCard({ innerPadding: 16 }) {
          Column() {
            SettingRow({
              title: '自动登录', desc: '启动时用记住的账号直接进入',
              value: this.settings.autoLogin,
              onToggle: (v: boolean) => {
                this.settings.autoLogin = v;
                this.settings.save();
              }
            })
            Divider().color(Theme.DIVIDER)
            SettingRow({
              title: '允许作答前看答案', desc: '方便快速对答案，我劝你别抄答案！',
              value: this.settings.enableAnswerForce,
              onToggle: (v: boolean) => {
                this.settings.enableAnswerForce = v;
                this.settings.save();
              }
            })
            Divider().color(Theme.DIVIDER)
            SettingRow({
              title: '自动展开答题区', desc: '方便快速录入答案',
              value: this.settings.autoExpandAnswerArea,
              onToggle: (v: boolean) => {
                this.settings.autoExpandAnswerArea = v;
                this.settings.save();
              }
            })
            Divider().color(Theme.DIVIDER)
            SettingRow({
              title: '开启下载权限', desc: '课件 PDF 显示下载按钮，甭外传资料！',
              value: this.settings.forceShowPDFButtons,
              onToggle: (v: boolean) => {
                this.settings.forceShowPDFButtons = v;
                this.settings.save();
              }
            })
            Divider().color(Theme.DIVIDER)
            SettingRow({
              title: '图片加速上传', desc: '拍照作答跳过增强和剪裁',
              value: this.settings.enableMockEnhance,
              onToggle: (v: boolean) => {
                this.settings.enableMockEnhance = v;
                this.settings.save();
              }
            })
            Divider().color(Theme.DIVIDER)
            SettingRow({
              title: '图片反色', desc: '反转作业图颜色（深色环境护眼）',
              value: this.settings.enableImageInvert,
              onToggle: (v: boolean) => {
                this.settings.enableImageInvert = v;
                this.settings.save();
              }
            })
            Divider().color(Theme.DIVIDER)
            SettingRow({
              title: '手写优化', desc: '批注/手写时防止页面滚动',
              value: this.settings.enableHandwritingFix,
              onToggle: (v: boolean) => {
                this.settings.enableHandwritingFix = v;
                this.settings.save();
              }
            })
            Divider().color(Theme.DIVIDER)
            SettingRow({
              title: '简洁模式', desc: '收起次要工具按钮',
              value: this.settings.enableSimpleMode,
              onToggle: (v: boolean) => {
                this.settings.enableSimpleMode = v;
                this.settings.save();
              }
            })
            Divider().color(Theme.DIVIDER)
            this.lgIntensityRow()
          }
          .width('100%')
        }
        }
        .width('100%')

        Column() {
        GlassCard({ innerPadding: 16 }) {
          Column() {
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.more'))
                .fontSize(20)
                .fontColor([Theme.TEXT_2])
              Column({ space: 3 }) {
                Text('打开网页版（兼容模式）')
                  .fontSize(Theme.F_BODY)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Theme.TEXT)
                Text('原生版未覆盖的功能可临时回到网页版使用')
                  .fontSize(Theme.F_MINI)
                  .fontColor(Theme.TEXT_3)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(18)
                .fontColor([Theme.TEXT_3])
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
            .onClick(() => {
              Nav.push('webshell', null);
            })
          }
          .width('100%')
        }
        }
        .width('100%')

        Column() {
        SquishButton({
          onTap: () => {
            this.confirmLogout = true;
          }
        }) {
          Text('退出登录')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.DANGER)
            .width('100%')
            .height(48)
            .textAlign(TextAlign.Center)
            .backgroundColor('#14E94B4B')
            .borderRadius(Theme.R_XL)
        }
        }
        .width('100%')

        if (this.confirmLogout) {
          Column() {
          GlassCard({ innerPadding: 20 }) {
            Column({ space: 14 }) {
              Text('确定退出登录吗？')
                .fontSize(Theme.F_BODY)
                .fontColor(Theme.TEXT)
              Row({ space: 12 }) {
                Button('取消')
                  .layoutWeight(1)
                  .backgroundColor('#F0F2F5')
                  .fontColor(Theme.TEXT_2)
                  .onClick(() => {
                    this.confirmLogout = false;
                  })
                Button('退出')
                  .layoutWeight(1)
                  .backgroundColor(Theme.DANGER)
                  .fontColor(Color.White)
                  .onClick(() => {
                    this.confirmLogout = false;
                    SessionStore.instance.logout();
                  })
              }
              .width('100%')
            }
            .width('100%')
          }
          }
          .width('100%')
        }

        Text('爆改新能源 · HarmonyOS 原生版 2.0 · 原作者 程序猿')
          .fontSize(Theme.F_MINI)
          .fontColor(Theme.TEXT_3)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ bottom: 90 })
      }
      .width('100%')
      .padding({
        left: 20, right: 20,
        top: this.ui.topSafeVp + 12
      })
      .constraintSize({ maxWidth: 760 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring)
  }
}
