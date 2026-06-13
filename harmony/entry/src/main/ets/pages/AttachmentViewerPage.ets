// 附件全屏预览页（NavDestination）：
//   PDF  → 下载到沙箱 → PdfView（@kit.PDFKit）
//   视频 → Video 组件直接流式播放网络地址
//   图片 → Image 全屏查看
//   其他 → 提示不支持预览

import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { pdfService, pdfViewManager, PdfView } from '@kit.PDFKit';
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
  if (e === '.pdf') {
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
    if (this.pdfReady) {
      try {
        this.pdfController.releaseDocument();
      } catch (e) {
        // ignore
      }
    }
  }

  private async loadPdf(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const localPath = await Downloader.downloadToCache(ctx, this.url, this.name);
      hilog.info(DOMAIN, TAG, 'pdf downloaded: %{public}s', localPath);
      const result = await this.pdfController.loadDocument(localPath);
      if (result === pdfService.ParseResult.PARSE_SUCCESS) {
        this.pdfReady = true;
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
    }
    .width('100%')
    .height(50)
    .padding({ left: 16, right: 16, top: this.ui.topSafeVp })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  pdfViewer() {
    if (this.pdfReady) {
      PdfView({
        controller: this.pdfController,
        pageFit: pdfService.PageFit.FIT_WIDTH,
        isContinuous: true,
        showScroll: true,
        pageLayout: pdfService.PageLayout.LAYOUT_SINGLE
      })
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
      Nav.pop();
      return true;
    })
  }
}
