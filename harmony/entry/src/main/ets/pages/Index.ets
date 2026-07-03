// 根页面：登录态门卫 + HdsTabs 底部悬浮页签（沉浸光感材质，API 23 起）。
// 结构：
//   Navigation(Nav.stack)
//     ├─ booting   → 开屏 loading（自动登录进行中）
//     ├─ 未登录    → LoginPage
//     └─ 已登录    → MainTabs（课程/考试/AI/收藏/设置）
//   二级页（课件详情、网页版回退等）一律 NavDestination 推栈。

import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../theme/Theme';
import { Nav } from '../utils/Nav';
import { SessionStore } from '../store/SessionStore';
import { SettingsStore } from '../store/SettingsStore';
import { UiStore } from '../store/UiStore';
import { LoginPage } from './LoginPage';
import { CoursePage } from './CoursePage';
import { ExamPage } from './ExamPage';
import { AiPage } from './AiPage';
import { CollectionPage } from './CollectionPage';
import { SettingsPage } from './SettingsPage';
import { WebShellPage } from './WebShellPage';
import { CourseDetailPage } from './CourseDetailPage';
import { SearchSpotlight } from './SearchSpotlight';
import { TodoPanel } from './TodoPanel';
import { AttachmentViewerPage } from './AttachmentViewerPage';

interface TabItem {
  label: string;
  symbol: Resource;
}

const TABS: TabItem[] = [
  { label: '课程', symbol: $r('sys.symbol.book') },
  { label: '考试', symbol: $r('sys.symbol.doc_plaintext') },
  { label: 'AI', symbol: $r('sys.symbol.ai_edit') },
  { label: '收藏', symbol: $r('sys.symbol.heart') },
  { label: '设置', symbol: $r('sys.symbol.gearshape') }
];

const DOMAIN = 0x0002;
const TAG = 'Index';

@Entry
@ComponentV2
struct Index {
  private tabsController: HdsTabsController = new HdsTabsController();
  private session: SessionStore = SessionStore.instance;
  private settings: SettingsStore = SettingsStore.instance;
  private ui: UiStore = UiStore.instance;
  @Local private booting: boolean = SessionStore.instance.booting;
  @Local private loggedIn: boolean = SessionStore.instance.loggedIn;
  @Local private displayLg: number = SettingsStore.instance.lgIntensity;
  private sessionListener: () => void = () => {
    this.syncAppState();
  };
  private settingsListener: () => void = () => {
    this.syncSettingsState();
  };

  aboutToAppear(): void {
    this.session.addListener(this.sessionListener);
    this.settings.addListener(this.settingsListener);
    this.syncAppState();
    this.syncSettingsState();
  }

  aboutToBeDeleted(): void {
    this.session.removeListener(this.sessionListener);
    this.settings.removeListener(this.settingsListener);
  }

  private syncAppState(): void {
    if (this.session.booting !== this.booting) {
      this.booting = this.session.booting;
      hilog.info(DOMAIN, TAG, 'state sync booting=%{public}s', String(this.booting));
    }
    if (this.session.loggedIn !== this.loggedIn) {
      this.loggedIn = this.session.loggedIn;
      hilog.info(DOMAIN, TAG, 'state sync loggedIn=%{public}s', String(this.loggedIn));
    }
  }

  private syncSettingsState(): void {
    const lv = this.settings.lgIntensity;
    if (lv !== this.displayLg) {
      this.displayLg = lv;
    }
  }

  @Builder
  tabContentBody(index: number) {
    if (index === 0) {
      CoursePage()
    } else if (index === 1) {
      ExamPage()
    } else if (index === 2) {
      AiPage()
    } else if (index === 3) {
      CollectionPage()
    } else {
      SettingsPage()
    }
  }

  @Builder
  mainTabs() {
    Stack({ alignContent: Alignment.TopEnd }) {
      HdsTabs({ controller: this.tabsController, barPosition: BarPosition.End }) {
        ForEach(TABS, (item: TabItem, index: number) => {
          TabContent() {
            this.tabContentBody(index)
          }
          .tabBar(new BottomTabBarStyle({
            normal: new SymbolGlyphModifier(item.symbol)
          }, item.label).labelStyle({
            selectedColor: $r('app.color.primary_blue')
          }))
        }, (item: TabItem) => item.label)
      }
      .barOverlap(true)
      .barFloatingStyle({
        barBottomMargin: Theme.TABBAR_LIFT,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: this.displayLg >= 3
            ? hdsMaterial.MaterialLevel.EXQUISITE
            : (this.displayLg >= 2
              ? hdsMaterial.MaterialLevel.GENTLE
              : hdsMaterial.MaterialLevel.SMOOTH)
        }
      })

      // Floating action buttons: search + tools
      // 顶部悬浮按钮处于 expandSafeArea 全屏 Stack 内，必须按状态栏高度避让，
      // 否则被状态栏/刘海遮挡（与各 Tab 页标题用同一 topSafeVp+12 基线对齐）。
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(20)
          .fontColor([Theme.TEXT_2])
          .onClick(() => {
            Nav.push('search', null);
          })
        SymbolGlyph($r('sys.symbol.hammer_fill'))
          .fontSize(20)
          .fontColor([Theme.TEXT_2])
          .onClick(() => {
            Nav.push('todo', null);
          })
      }
      .padding({ left: 12, right: 16, top: this.ui.topSafeVp + 12 })
    }
  }

  @Builder
  splash() {
    Column({ space: 14 }) {
      LoadingProgress().width(54).height(54).color(Theme.PRIMARY)
      Text('正在进入新能源课程系统...')
        .fontSize(Theme.F_SUB)
        .fontColor(Theme.TEXT_2)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  pageMap(name: string) {
    if (name === 'webshell') {
      WebShellPage()
    } else if (name === 'courseDetail') {
      CourseDetailPage()
    } else if (name === 'search') {
      SearchSpotlight()
    } else if (name === 'todo') {
      TodoPanel()
    } else if (name === 'attachmentViewer') {
      AttachmentViewerPage()
    }
  }

  build() {
    Navigation(Nav.stack) {
      Stack() {
        if (this.booting) {
          this.splash()
        } else if (!this.loggedIn) {
          LoginPage({
            onLogin: () => {
              this.booting = false;
              this.loggedIn = true;
              hilog.info(DOMAIN, TAG, 'login event loggedIn=true');
            }
          })
        } else {
          this.mainTabs()
        }
      }
      .width('100%')
      .height('100%')
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.pageMap)
    .backgroundColor(Theme.BG_CREAM)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
