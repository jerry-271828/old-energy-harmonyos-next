import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window, display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { GmStorage } from '../bridge/GmStorage';
import { GmNotifier } from '../bridge/GmNotifier';
import { SessionStore } from '../store/SessionStore';
import { SettingsStore } from '../store/SettingsStore';
import { UiStore } from '../store/UiStore';
import { TodoStore } from '../store/TodoStore';

const DOMAIN = 0x0001;
const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onCreate');
    // 初始化顺序：GmStorage 先于一切（SessionStore/SettingsStore 同步读它；
    // WebView 回退模式下桥的 getValue 也是同步读）。
    GmStorage.init(this.context);
    GmNotifier.init(this.context);
    SettingsStore.instance.load();
    TodoStore.instance.load();
    SessionStore.instance.init(this.context);
    // 自动登录在后台跑，UI 由 SessionStore.booting 控制开屏态
    SessionStore.instance.tryAutoLogin(SettingsStore.instance.autoLogin);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'loadContent ok');

      try {
        const win = windowStage.getMainWindowSync();
        // 原生版沉浸式：内容延伸到系统栏下，但保留系统栏可见（与旧版整窗隐藏不同
        // ——那是为 H5 全屏服务的；原生页面自己用安全区高度避让）。
        win.setWindowLayoutFullScreen(true);
        win.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          statusBarContentColor: '#1F2329',
          navigationBarColor: '#00000000',
          navigationBarContentColor: '#1F2329'
        }).catch((e: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'setWindowSystemBarProperties failed: %{public}s', e.message);
        });

        this.syncWindowMetrics(win);
        win.on('windowSizeChange', () => {
          this.syncWindowMetrics(win);
        });
        win.on('avoidAreaChange', () => {
          this.syncWindowMetrics(win);
        });
      } catch (e) {
        const er = e as BusinessError;
        hilog.warn(DOMAIN, TAG, 'window config failed: %{public}s', er.message);
      }
    });
  }

  private syncWindowMetrics(win: window.Window): void {
    try {
      const props = win.getWindowProperties();
      const ui = UiStore.instance;
      const density = display.getDefaultDisplaySync().densityPixels;  // px per vp
      ui.windowWidthVp = Math.round(props.windowRect.width / density);
      ui.windowHeightVp = Math.round(props.windowRect.height / density);
      const sysAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const naviAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      ui.topSafeVp = Math.round(sysAvoid.topRect.height / density);
      ui.bottomSafeVp = Math.round(naviAvoid.bottomRect.height / density);
      hilog.info(DOMAIN, TAG, 'metrics: %{public}d x %{public}d, safe %{public}d/%{public}d',
        ui.windowWidthVp, ui.windowHeightVp, ui.topSafeVp, ui.bottomSafeVp);
    } catch (e) {
      const er = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'syncWindowMetrics failed: %{public}s', er.message);
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'onBackground');
  }
}
