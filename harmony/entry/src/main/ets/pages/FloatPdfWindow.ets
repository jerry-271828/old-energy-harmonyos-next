import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ScriptBuilder, UserScript } from '../utils/ScriptBuilder';

const DOMAIN = 0x0001;
const TAG = 'FloatPdfWindow';

export type FloatState = 'closed' | 'normal' | 'minimized' | 'maximized';

export interface FloatGeom {
  x: number;
  y: number;
  w: number;
  h: number;
}

const TITLE_BAR_H: number = 40;
const CORNER_SIZE: number = 24;
const HALF_CORNER: number = 12;        // CORNER_SIZE / 2
const MIN_W: number = 320;
const MIN_H: number = 240;
const EXPAND_BTN: number = 56;
const EXPAND_BTN_MARGIN: number = 20;

type Corner = 'tl' | 'tr' | 'bl' | 'br';

export function defaultFloatGeom(pageW: number, pageH: number): FloatGeom {
  const w: number = Math.max(MIN_W, Math.min(720, Math.floor(pageW * 0.55)));
  const h: number = Math.max(MIN_H, Math.min(900, Math.floor(pageH * 0.7)));
  const x: number = Math.max(0, Math.floor((pageW - w) / 2));
  const y: number = Math.max(0, Math.floor((pageH - h) / 2));
  return { x, y, w, h };
}

// 浮动 PDF 预览窗：
//   - state === 'normal'    : 自由位置 + 自由大小，四角可拖动 resize，标题栏可拖移窗
//   - state === 'maximized' : 占满父容器，标题栏隐藏 resize 把手
//   - state === 'minimized' : 主面板挪到屏幕外保活内部 Web；右下显示展开按钮
//   - state === 'closed'    : Index.ets 不应挂载本组件
//
// Web 区只注入 pack2.js（由 ScriptBuilder.matchesUrl 按 @match 过滤）。
// 不挂 AndroidBridge——pack2.js 只用 GM_addStyle，无需桥；同时避开 GmHttp 单
// controller 绑定被主页夺走的副作用。
@Component
export struct FloatPdfWindow {
  @Link url: string;
  @Link state: FloatState;
  @Link geom: FloatGeom;
  @Link savedGeom: FloatGeom;
  @Link mounted: boolean;
  pageWidth: number = 1280;
  pageHeight: number = 800;
  earlyScript: string = '';
  userScripts: UserScript[] = [];
  onCloseRequest: () => void = () => {};

  private controller: webview.WebviewController = new webview.WebviewController();
  // 拖动开始时拍快照，避免在 onActionUpdate 累加导致数值漂移。
  private dragStartGeom: FloatGeom = { x: 0, y: 0, w: 0, h: 0 };

  private snapshot(): void {
    this.dragStartGeom = {
      x: this.geom.x,
      y: this.geom.y,
      w: this.geom.w,
      h: this.geom.h
    };
  }

  private clampGeom(g: FloatGeom): FloatGeom {
    const pw: number = this.pageWidth;
    const ph: number = this.pageHeight;
    const w: number = Math.max(MIN_W, Math.min(pw, g.w));
    const h: number = Math.max(MIN_H, Math.min(ph, g.h));
    // 给一点边距，避免被推出屏幕完全够不到
    const x: number = Math.max(-w + 80, Math.min(pw - 80, g.x));
    const y: number = Math.max(0, Math.min(ph - TITLE_BAR_H, g.y));
    return { x, y, w, h };
  }

  private toggleMaximize(): void {
    if (this.state === 'maximized') {
      this.geom = this.clampGeom(this.savedGeom);
      this.state = 'normal';
    } else {
      this.savedGeom = this.geom;
      this.state = 'maximized';
    }
  }

  // 根据 corner 类型把 (dx, dy) 转换成新 geom；处理最小尺寸时锚定对角不动。
  private resizeFromCorner(corner: Corner, dx: number, dy: number): FloatGeom {
    const sx: number = this.dragStartGeom.x;
    const sy: number = this.dragStartGeom.y;
    const sw: number = this.dragStartGeom.w;
    const sh: number = this.dragStartGeom.h;

    let nx: number = sx;
    let ny: number = sy;
    let nw: number = sw;
    let nh: number = sh;

    if (corner === 'tl' || corner === 'bl') {
      nx = sx + dx;
      nw = sw - dx;
    } else {
      nw = sw + dx;
    }
    if (corner === 'tl' || corner === 'tr') {
      ny = sy + dy;
      nh = sh - dy;
    } else {
      nh = sh + dy;
    }

    if (nw < MIN_W) {
      if (corner === 'tl' || corner === 'bl') {
        nx = sx + (sw - MIN_W);
      }
      nw = MIN_W;
    }
    if (nh < MIN_H) {
      if (corner === 'tl' || corner === 'tr') {
        ny = sy + (sh - MIN_H);
      }
      nh = MIN_H;
    }

    return this.clampGeom({ x: nx, y: ny, w: nw, h: nh });
  }

  // 标题栏拖动 → 整窗移动
  private dragWindow(dx: number, dy: number): void {
    const next: FloatGeom = {
      x: this.dragStartGeom.x + dx,
      y: this.dragStartGeom.y + dy,
      w: this.dragStartGeom.w,
      h: this.dragStartGeom.h
    };
    this.geom = this.clampGeom(next);
  }

  @Builder titleBar() {
    Row() {
      Text('PDF 预览')
        .layoutWeight(1)
        .padding({ left: 16 })
        .fontSize(14)
        .fontColor('#222')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // Minimize
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.minus')).fontSize(14).fontColor([Color.Black])
      }
      .width(28).height(28).backgroundColor('#EEEEEE').margin({ right: 6 })
      .onClick(() => { this.state = 'minimized'; })

      // Maximize / restore
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph(this.state === 'maximized'
          ? $r('sys.symbol.minus')
          : $r('sys.symbol.plus'))
          .fontSize(14).fontColor([Color.Black])
      }
      .width(28).height(28).backgroundColor('#EEEEEE').margin({ right: 6 })
      .onClick(() => { this.toggleMaximize(); })

      // Close
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.xmark')).fontSize(14).fontColor([Color.White])
      }
      .width(28).height(28).backgroundColor('#E94B4B').margin({ right: 12 })
      .onClick(() => { this.onCloseRequest(); })
    }
    .width('100%')
    .height(TITLE_BAR_H)
    .backgroundColor('#F7F8FA')
    .alignItems(VerticalAlign.Center)
    .gesture(
      PanGesture()
        .onActionStart(() => {
          if (this.state !== 'maximized') {
            this.snapshot();
          }
        })
        .onActionUpdate((evt: GestureEvent) => {
          if (this.state === 'maximized') {
            return;
          }
          this.dragWindow(evt.offsetX, evt.offsetY);
        })
    )
  }

  @Builder webArea() {
    if (this.mounted && this.url.length > 0) {
      Web({ src: this.url, controller: this.controller })
        .domStorageAccess(true)
        .javaScriptAccess(true)
        .fileAccess(true)
        .imageAccess(true)
        .onlineImageAccess(true)
        .zoomAccess(true)
        .overScrollMode(OverScrollMode.NEVER)
        .horizontalScrollBarAccess(false)
        .verticalScrollBarAccess(true)
        .mixedMode(MixedMode.All)
        .cacheMode(CacheMode.Default)
        .databaseAccess(true)
        .layoutMode(WebLayoutMode.NONE)
        .javaScriptOnDocumentStart([
          { script: this.earlyScript, scriptRules: ['*'] }
        ])
        .onPageEnd((event) => {
          const u: string = event?.url ?? '';
          hilog.info(DOMAIN, TAG, 'pageEnd: %{public}s', u);
          // 用与主页一致的 URL 过滤；pack2.js 的 @match 命中 /pdf/web*。
          for (let i = 0; i < this.userScripts.length; i++) {
            const s: UserScript = this.userScripts[i];
            if (!ScriptBuilder.matchesUrl(u, s.patterns)) {
              continue;
            }
            const scriptName: string = s.name;
            const scriptLen: number = s.content.length;
            try {
              this.controller.runJavaScript(s.content, (err) => {
                if (err) {
                  hilog.warn(DOMAIN, TAG, 'inject %{public}s failed: %{public}s',
                    scriptName, err.message);
                  return;
                }
                hilog.info(DOMAIN, TAG, 'inject %{public}s OK (%{public}d bytes)',
                  scriptName, scriptLen);
              });
            } catch (e) {
              const err = e as BusinessError;
              hilog.warn(DOMAIN, TAG, 'inject %{public}s exception: %{public}s',
                scriptName, err.message);
            }
          }
        })
        .onErrorReceive((event) => {
          const u: string = event?.request?.getRequestUrl() ?? '';
          const info: string = event?.error?.getErrorInfo() ?? '';
          hilog.warn(DOMAIN, TAG, 'errorReceive %{public}s: %{public}s', u, info);
        })
        .onConsole((event) => {
          const msg = event?.message;
          if (msg) {
            hilog.info(DOMAIN, TAG, '[floatweb] %{public}s', msg.getMessage());
          }
          return false;
        })
        .width('100%')
        .layoutWeight(1)
    } else {
      Column() {
        LoadingProgress().width(40).height(40).color('#5280FF')
      }
      .width('100%').layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder cornerHandle(corner: Corner) {
    // 圆形把手，比把手占地略小的实心圆居中；半个尺寸越出窗体，方便单手抓取。
    Stack() {
      Column()
        .width(10).height(10).borderRadius(5)
        .backgroundColor('#88333333')
    }
    .width(CORNER_SIZE).height(CORNER_SIZE)
    .borderRadius(CORNER_SIZE / 2)
    .backgroundColor('#CCFFFFFF')
    .border({ width: 1, color: '#22000000' })
    .shadow({ radius: 4, color: '#33000000', offsetY: 1 })
    .position(this.cornerPos(corner))
    .gesture(
      PanGesture()
        .onActionStart(() => { this.snapshot(); })
        .onActionUpdate((evt: GestureEvent) => {
          this.geom = this.resizeFromCorner(corner, evt.offsetX, evt.offsetY);
        })
    )
  }

  // Stack 是相对父 Stack 定位的（FloatPdfWindow 的根 Stack）。
  // 把手中心要落在窗体四角上：左/上 = -HALF_CORNER，右/下 = panelSize - HALF_CORNER。
  private cornerPos(corner: Corner): Position {
    const pw: number = this.state === 'maximized' ? this.pageWidth : this.geom.w;
    const ph: number = this.state === 'maximized' ? this.pageHeight : this.geom.h;
    const x: number = (corner === 'tl' || corner === 'bl') ? -HALF_CORNER : (pw - HALF_CORNER);
    const y: number = (corner === 'tl' || corner === 'tr') ? -HALF_CORNER : (ph - HALF_CORNER);
    return { x, y };
  }

  // 主面板（标题栏 + Web 区）
  @Builder panel() {
    Column() {
      this.titleBar()
      this.webArea()
    }
    .width('100%')
    .height('100%')
    .borderRadius(12)
    .backgroundColor('#FFFFFF')
    .clip(true)
    .shadow({ radius: 24, color: '#44000000', offsetY: 4 })
    .border({ width: 0.5, color: '#22000000' })
  }

  build() {
    // 外层 Stack 包住所有"浮窗资产"。它的宽高在 normal/maximized 时跟随窗体；
    // minimized 时整窗挪到屏幕外（保活 Web），由 Index.ets 那侧另起一个独立
    // 展开按钮浮在右下。
    Stack({ alignContent: Alignment.TopStart }) {
      this.panel()

      if (this.state === 'normal') {
        this.cornerHandle('tl')
        this.cornerHandle('tr')
        this.cornerHandle('bl')
        this.cornerHandle('br')
      }
    }
    .width(this.state === 'maximized' ? this.pageWidth : this.geom.w)
    .height(this.state === 'maximized' ? this.pageHeight : this.geom.h)
    .position({
      x: this.state === 'minimized' ? -100000 : (this.state === 'maximized' ? 0 : this.geom.x),
      y: this.state === 'minimized' ? -100000 : (this.state === 'maximized' ? 0 : this.geom.y)
    })
  }
}
