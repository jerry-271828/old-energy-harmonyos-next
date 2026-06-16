// 附件全屏预览页（NavDestination）：
//   PDF / office 文档 → 下载到沙箱 → PdfView（@kit.PDFKit）
//   视频 → Video 组件直接流式播放网络地址
//   图片 → Image 全屏查看
//   其他 → 提示不支持预览
//
// office 文档（.doc/.docx/.ppt/.pptx）说明：服务端有转换流水线（attachment 实体的
// convertStatus/attachmentPageCounts 即其产物），在文件 URL 上直接返回转换后的 PDF 字节。
// 原 Vue 前端正是把这些类型和 .pdf 一起塞进 /exam/pdf/web/viewer.html（原版 PDF.js）。
// 故原生端把它们当 pdf 类型、下载同一 URL 即得 PDF，复用 PdfView 链路。
// （.xls/.xlsx 服务端不转、Vue 也不预览，保持不支持。）
//
// Pen Kit 批注（仅 pdf/office→pdf）：点头部「批注」→ 在 PdfView 上叠加一层透明的
// HandwriteComponent（自带笔/橡皮/颜色/撤销工具栏）。批注模式下手写长画布作为滚动主体、
// 画布高度按 PDF 总高设置，PDF 通过 setViewOffset 跟随画布滚动（onDidScroll，单向同步、
// 不回灌避免环路），使笔迹锚定到文档位置。批注用 Pen Kit 原生 save/load 持久化到
// filesDir/pen_annot/<docKey>.hwt（可重新编辑）。前置 BrushEngineContext 已由 EntryAbility 设好。
// 真机需核对：HandwriteComponent 透明叠加是否透出 PDF、手势(笔绘/指滑)归属、画布↔PDF 滚动标定。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { pdfService, pdfViewManager, PdfView } from '@kit.PDFKit';
import { HandwriteController, HandwriteComponent, PenType, PenHspInfo } from '@kit.Penkit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { Theme } from '../theme/Theme';
import { UiStore } from '../store/UiStore';
import { Nav } from '../utils/Nav';
import { ApiClient } from '../net/ApiClient';
import { Downloader } from '../utils/Downloader';
import { LoadingView } from '../components/glass/GlassKit';

const DOMAIN = 0x0002;
const TAG = 'AttachmentViewer';

// Nav.push('attachmentViewer', param) 传入
export interface AttachmentViewerParam {
  name: string;
  url: string;       // 明文相对路径（已从 statistics 解析）
  ext: string;       // ".pdf" / ".mp4" / ".png" ...
}

type ViewerKind = 'pdf' | 'video' | 'image' | 'unsupported';

function classifyExt(ext: string): ViewerKind {
  const e = ext.toLowerCase();
  // .pdf 与服务端会转成 PDF 的 office 文档共用 PdfView 链路（见文件头注释）。
  if (e === '.pdf' || e === '.doc' || e === '.docx' || e === '.ppt' || e === '.pptx') {
    return 'pdf';
  }
  if (e === '.mp4' || e === '.mov' || e === '.avi' || e === '.mkv' || e === '.ts') {
    return 'video';
  }
  if (e === '.png' || e === '.jpg' || e === '.jpeg' || e === '.gif' || e === '.webp' || e === '.bmp') {
    return 'image';
  }
  return 'unsupported';
}

@Component
export struct AttachmentViewerPage {
  ui: UiStore = UiStore.instance;

  @State private name: string = '';
  @State private url: string = '';
  @State private kind: ViewerKind = 'unsupported';
  @State private loading: boolean = true;
  @State private error: string = '';
  // PDF
  private pdfController: pdfViewManager.PdfController = new pdfViewManager.PdfController();
  @State private pdfReady: boolean = false;
  // Video
  private videoController: VideoController = new VideoController();
  @State private videoUrl: string = '';
  // Pen Kit 批注（仅 pdf）
  private handwriteCtrl: HandwriteController = new HandwriteController();
  private penInfo: PenHspInfo[] = [
    { penType: PenType.PEN, penWidth: 4 },
    { penType: PenType.BALLPOINT_PEN, penWidth: 4 },
    { penType: PenType.PENCIL, penWidth: 8 }
  ] as PenHspInfo[];
  @State private annotating: boolean = false;
  @State private canvasMaxH: number = 8000;   // 手写长画布高度(vp)；进入批注前按 PDF 总高重设
  private annotPath: string = '';             // Pen Kit 笔记文件路径（filesDir/pen_annot/<key>.hwt）
  private annotLoaded: boolean = false;       // 是否已尝试 load 过（避免重复加载）
  // PDF 滚动几何（registerScrollListener 被动更新，仅用于批注画布标定，不回灌 PDF）
  private pdfTotalH: number = 0;
  private pdfViewH: number = 0;
  private pdfOffsetY: number = 0;

  aboutToAppear(): void {
    const param = Nav.stack.getParamByName('attachmentViewer') as Object[];
    if (param.length > 0) {
      const p = param[param.length - 1] as AttachmentViewerParam;
      this.name = p.name;
      this.url = p.url;
      this.kind = classifyExt(p.ext);
    }
    if (this.url.length === 0) {
      this.loading = false;
      this.error = '附件地址为空';
      return;
    }
    if (this.kind === 'pdf') {
      this.loadPdf();
    } else if (this.kind === 'video') {
      this.videoUrl = ApiClient.assetUrl(this.url);
      this.loading = false;
    } else if (this.kind === 'image') {
      this.loading = false;
    } else {
      this.loading = false;
      this.error = '暂不支持预览此类型文件';
    }
  }

  aboutToDisappear(): void {
    // 离开页面前落盘批注（曾进入过批注模式才需要）
    if (this.annotLoaded) {
      this.saveAnnotation();
    }
    if (this.pdfReady) {
      try {
        this.pdfController.releaseDocument();
      } catch (e) {
        // ignore
      }
    }
  }

  // 准备批注：解析笔记文件路径（按文档 url 取键）并注册 PDF 滚动监听（仅记录几何）。
  private setupAnnotation(ctx: common.UIAbilityContext): void {
    try {
      const dir = ctx.filesDir + '/pen_annot';
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
      const key = this.url.replace(/[^A-Za-z0-9]/g, '_') || 'doc';
      this.annotPath = dir + '/' + key + '.hwt';
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'setupAnnotation path failed: %{public}s', (e as Error).message);
    }
    try {
      this.pdfController.registerScrollListener((sp: pdfViewManager.ScrollParam) => {
        // 被动记录几何，供进入批注时标定画布；不在此处驱动画布滚动（避免与 onDidScroll 形成环路）
        this.pdfTotalH = sp.pdfHeight;
        this.pdfViewH = sp.viewHeight;
        this.pdfOffsetY = sp.offsetY;
      });
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'registerScrollListener failed: %{public}s', (e as Error).message);
    }
  }

  // 预览用缓存文件名强制 .pdf 后缀：office 文档下到的是服务端转换后的 PDF 字节，
  // 用原扩展名（.docx 等）命名可能让 PdfView 按扩展名拒识，且会与「下载原文件」缓存混淆。
  private pdfCacheName(): string {
    const n = this.name;
    const dot = n.lastIndexOf('.');
    const base = dot > 0 ? n.substring(0, dot) : n;
    return base + '.pdf';
  }

  private async loadPdf(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const localPath = await Downloader.downloadToCache(ctx, this.url, this.pdfCacheName());
      hilog.info(DOMAIN, TAG, 'pdf downloaded: %{public}s', localPath);
      const result = await this.pdfController.loadDocument(localPath);
      if (result === pdfService.ParseResult.PARSE_SUCCESS) {
        this.pdfReady = true;
        this.setupAnnotation(ctx);
      } else {
        this.error = 'PDF 加载失败 (code ' + result + ')';
      }
    } catch (e) {
      const err = e as Error;
      this.error = err.message || 'PDF 下载失败';
      hilog.error(DOMAIN, TAG, 'loadPdf failed: %{public}s', err.message);
    } finally {
      this.loading = false;
    }
  }

  // 切换批注模式。进入前按 PDF 总高设定长画布高度；退出时先存盘再卸载手写组件。
  private async toggleAnnotate(): Promise<void> {
    if (this.annotating) {
      await this.saveAnnotation();   // 组件仍挂载时存盘
      this.annotating = false;       // 之后卸载
      return;
    }
    if (this.pdfTotalH > 0) {
      const h = px2vp(this.pdfTotalH);
      const cap = px2vp(1000000);    // scrollTo/画布的最大可滚动范围
      this.canvasMaxH = h > cap ? cap : (h < 1000 ? 1000 : h);
    }
    this.annotLoaded = false;        // 本次挂载后在 onInit 里 load 一次
    this.annotating = true;
  }

  // 手写画布初始化完成：加载已存笔记，并对齐到 PDF 当前滚动位置（一次性 PDF→画布）。
  private onAnnotInit(): void {
    if (!this.annotLoaded && this.annotPath.length > 0) {
      this.annotLoaded = true;
      try {
        if (fs.accessSync(this.annotPath)) {
          this.handwriteCtrl.load(this.annotPath);
        }
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'annot load failed: %{public}s', (e as Error).message);
      }
    }
    const denom = this.canvasMaxH - px2vp(this.pdfViewH);
    if (denom > 0) {
      try {
        this.handwriteCtrl.scrollTo(this.pdfOffsetY * denom);
      } catch (e) {
        // ignore
      }
    }
  }

  // 批注模式下画布滚动 → 驱动 PDF 跟随（单向）。offsetY 取 0~1。
  private onCanvasScroll(yOffsetVp: number): void {
    const denom = this.canvasMaxH - px2vp(this.pdfViewH);
    if (denom <= 0) {
      return;
    }
    let ratio = yOffsetVp / denom;
    ratio = ratio < 0 ? 0 : (ratio > 1 ? 1 : ratio);
    try {
      this.pdfController.setViewOffset(0, ratio, true);
    } catch (e) {
      // ignore
    }
  }

  private async saveAnnotation(): Promise<void> {
    if (this.annotPath.length === 0) {
      return;
    }
    try {
      await this.handwriteCtrl.save(this.annotPath);
      hilog.info(DOMAIN, TAG, 'annotation saved: %{public}s', this.annotPath);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'annotation save failed: %{public}s', (e as Error).message);
    }
  }

  @Builder
  headerBar() {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(24)
        .fontColor([Theme.TEXT])
        .onClick(() => {
          Nav.pop();
        })
      Text(this.name)
        .fontSize(Theme.F_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.kind === 'pdf' && this.pdfReady && canIUse('SystemCapability.Stylus.Handwrite')) {
        Text(this.annotating ? '完成' : '批注')
          .fontSize(Theme.F_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.annotating ? Color.White : Theme.PRIMARY)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(this.annotating ? Theme.PRIMARY : Theme.PRIMARY_SOFT)
          .borderRadius(Theme.R_XL)
          .onClick(() => {
            this.toggleAnnotate();
          })
      }
    }
    .width('100%')
    .height(50)
    .padding({ left: 16, right: 16, top: this.ui.topSafeVp })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  pdfViewer() {
    if (this.pdfReady) {
      Stack() {
        PdfView({
          controller: this.pdfController,
          pageFit: pdfService.PageFit.FIT_WIDTH,
          isContinuous: true,
          showScroll: true,
          pageLayout: pdfService.PageLayout.LAYOUT_SINGLE
        })
          .width('100%')
          .height('100%')

        // 批注层：透明手写画布叠加在 PDF 之上（自带工具栏）。
        // 置于 Stack 末尾即在最上层；批注模式下作为滚动主体，PDF 经 onCanvasScroll 跟随。
        if (this.annotating && canIUse('SystemCapability.Stylus.Handwrite')) {
          HandwriteComponent({
            handwriteController: this.handwriteCtrl,
            defaultPenType: PenType.PEN,
            defaultPenInfo: this.penInfo,
            widthRatio: 1,
            heightRatio: 1,
            maxCanvasHeight: this.canvasMaxH,
            scaleDisabled: true,   // 批注时禁缩放，保持与 PDF 标定稳定
            onInit: () => {
              this.onAnnotInit();
            },
            onScale: (_scale: number) => {
            },
            onDidScroll: (yOffset: number) => {
              this.onCanvasScroll(yOffset);
            }
          })
            .width('100%')
            .height('100%')
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
  }

  // Video 组件无法设置自定义 HTTP header；若资源需 auth cookie，直接流式会 403。
  // 策略：先尝试网络流式播放，onError 回退为下载到沙箱后本地播放。
  private async fallbackVideoToLocal(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'video streaming failed, fallback to local download');
    this.loading = true;
    this.error = '';
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const localPath = await Downloader.downloadToCache(ctx, this.url, this.name);
      this.videoUrl = 'file://' + localPath;
    } catch (e) {
      const err = e as Error;
      this.error = err.message || '视频下载失败';
      hilog.error(DOMAIN, TAG, 'fallbackVideo failed: %{public}s', err.message);
    } finally {
      this.loading = false;
    }
  }

  @Builder
  videoViewer() {
    if (this.videoUrl.length > 0) {
      Video({
        src: this.videoUrl,
        controller: this.videoController
      })
        .width('100%')
        .layoutWeight(1)
        .controls(true)
        .autoPlay(true)
        .objectFit(ImageFit.Contain)
        .onError(() => {
          if (this.videoUrl.startsWith('http')) {
            this.fallbackVideoToLocal();
          } else {
            hilog.error(DOMAIN, TAG, 'video playback error (local)');
            this.error = '视频播放失败';
          }
        })
    }
  }

  @Builder
  imageViewer() {
    Column() {
      Image(ApiClient.assetUrl(this.url))
        .width('100%')
        .layoutWeight(1)
        .objectFit(ImageFit.Contain)
    }
    .width('100%')
    .layoutWeight(1)
  }

  build() {
    NavDestination() {
      Column() {
        this.headerBar()

        if (this.loading) {
          LoadingView()
            .layoutWeight(1)
        } else if (this.error.length > 0) {
          Column({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
              .fontSize(40)
              .fontColor([Theme.TEXT_3])
            Text(this.error)
              .fontSize(Theme.F_BODY)
              .fontColor(Theme.TEXT_2)
              .textAlign(TextAlign.Center)
              .padding({ left: 32, right: 32 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else if (this.kind === 'pdf') {
          this.pdfViewer()
        } else if (this.kind === 'video') {
          this.videoViewer()
        } else if (this.kind === 'image') {
          this.imageViewer()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.kind === 'video' ? '#000000' : Theme.BG_CREAM)
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      if (this.annotating) {
        this.toggleAnnotate();   // 先存盘并退出批注，不直接退出预览
        return true;
      }
      Nav.pop();
      return true;
    })
  }
}
