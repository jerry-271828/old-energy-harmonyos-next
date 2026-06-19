// 手写面板：基于官方 Pen Kit 手写套件（HandwriteComponent + HandwriteController）。
// 组件自带画布与手写工具栏（笔刷/颜色/粗细/橡皮/撤销由套件内置工具栏处理），
// 壳层只负责标题栏与「提交」动作。
//
// - annotation 模式：课程批注草稿板，本地保存为可重新编辑的 Pen Kit 笔迹文件。
// - answer 模式：HandwriteController.getThumbnail(getContentRange()) 导出笔迹为图片，
//   走原有上传管线（AttaApi.upload → 可选 imgEnhance → bindAnswerAttachment）。
//
// 前置：EntryAbility 必须已调用 BrushEngineContext.setContext(this.context)，
// 否则笔刷引擎拿不到 context，画布无法初始化。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { HandwriteController, HandwriteComponent, PenType, PenHspInfo } from '@kit.Penkit';
import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { Theme } from '../theme/Theme';
import { AttaApi, UploadResult } from '../net/api/AttaApi';
import { StudyApi, StudyKind } from '../net/api/StudyApi';
import { SettingsStore } from '../store/SettingsStore';
import { GmStorage } from '../bridge/GmStorage';
import { HtmlRichText } from './HtmlRichText';

const DOMAIN = 0x0002;
const TAG = 'HandwritePanel';

export interface HandwriteQuestionItem {
  id: number;
  label: string;
  stem: string;
}

interface AnnotationMeta {
  questionId: number;
  label: string;
  stem: string;
  previewHeight?: number;
}

const QUESTION_PREVIEW_MIN_HEIGHT = 92;
const QUESTION_PREVIEW_MAX_HEIGHT = 420;
const QUESTION_PREVIEW_DEFAULT_HEIGHT = 180;

@ComponentV2
export struct HandwritePanel {
  @Param mode: string = 'annotation';          // 'annotation' | 'answer'
  @Param questionStem: string = '';            // 题干文本(answer模式)
  @Param persistKey: string = '';              // annotation模式：本地持久化 key
  @Param questionItems: HandwriteQuestionItem[] = [];
  @Param entityId: number = 0;
  @Param questionId: number = 0;
  @Param kind: StudyKind = 'course';
  @Param onClose: () => void = () => {};
  @Param onSubmitted: () => void = () => {};   // 上传成功后回调

  @Local private submitting: boolean = false;
  @Local private showQuestionPicker: boolean = false;
  @Local private importedQuestionId: number = 0;
  @Local private importedQuestionLabel: string = '';
  @Local private importedQuestionStem: string = '';
  @Local private questionPreviewHeight: number = QUESTION_PREVIEW_DEFAULT_HEIGHT;
  private questionPreviewDragStart: number = QUESTION_PREVIEW_DEFAULT_HEIGHT;

  // 手写套件功能类实例：画布初始化、加载/保存、取笔迹范围与缩略图都经它。
  private controller: HandwriteController = new HandwriteController();
  // 各笔刷默认宽度（取值范围见官方文档：钢笔/圆珠笔 2-10，铅笔 4-20）。
  private penInfo: PenHspInfo[] = [
    { penType: PenType.PEN, penWidth: 4 },
    { penType: PenType.BALLPOINT_PEN, penWidth: 4 },
    { penType: PenType.PENCIL, penWidth: 8 }
  ] as PenHspInfo[];
  private annotPath: string = '';
  private annotLoaded: boolean = false;

  aboutToAppear(): void {
    if (this.mode === 'annotation') {
      this.setupAnnotationPersistence();
      this.loadAnnotationMeta();
    }
  }

  aboutToDisappear(): void {
    if (this.mode === 'annotation') {
      this.saveAnnotation();
    }
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1800 });
    } catch (_) {
      // ignore
    }
  }

  private safePersistKey(): string {
    const raw = this.persistKey.length > 0
      ? this.persistKey
      : `${this.kind}_${this.entityId}`;
    return raw.replace(/[^A-Za-z0-9]/g, '_') || 'course_annotation';
  }

  private metaKey(): string {
    return `handwrite_annot_meta_${this.safePersistKey()}`;
  }

  private setupAnnotationPersistence(): void {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const dir = ctx.filesDir + '/pen_annot';
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
      this.annotPath = dir + '/' + this.safePersistKey() + '.hwt';
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'setup annotation persistence failed: %{public}s',
        (e as Error).message);
    }
  }

  private loadAnnotationMeta(): void {
    const raw = GmStorage.getSync(this.metaKey());
    if (raw.length === 0) {
      return;
    }
    try {
      const meta = JSON.parse(raw) as AnnotationMeta;
      this.importedQuestionId = meta.questionId;
      this.importedQuestionLabel = meta.label ?? '';
      this.importedQuestionStem = meta.stem ?? '';
      if (typeof meta.previewHeight === 'number') {
        this.questionPreviewHeight = this.clampQuestionPreviewHeight(meta.previewHeight);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'load annotation meta failed: %{public}s',
        (e as Error).message);
    }
  }

  private saveAnnotationMeta(): void {
    if (this.mode !== 'annotation') {
      return;
    }
    const meta: AnnotationMeta = {
      questionId: this.importedQuestionId,
      label: this.importedQuestionLabel,
      stem: this.importedQuestionStem,
      previewHeight: this.questionPreviewHeight
    };
    GmStorage.putAsync(this.metaKey(), JSON.stringify(meta));
  }

  private clampQuestionPreviewHeight(value: number): number {
    return Math.max(QUESTION_PREVIEW_MIN_HEIGHT, Math.min(QUESTION_PREVIEW_MAX_HEIGHT, value));
  }

  private onCanvasInit(): void {
    hilog.info(DOMAIN, TAG, 'handwrite canvas init (mode=%{public}s)', this.mode);
    if (this.mode !== 'annotation' || this.annotLoaded || this.annotPath.length === 0) {
      return;
    }
    this.annotLoaded = true;
    try {
      if (fs.accessSync(this.annotPath)) {
        this.controller.load(this.annotPath);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'annotation load failed: %{public}s',
        (e as Error).message);
    }
  }

  private async saveAnnotation(): Promise<void> {
    if (this.mode !== 'annotation' || this.annotPath.length === 0) {
      return;
    }
    try {
      await this.controller.save(this.annotPath);
      this.saveAnnotationMeta();
      hilog.info(DOMAIN, TAG, 'annotation saved: %{public}s', this.annotPath);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'annotation save failed: %{public}s',
        (e as Error).message);
    }
  }

  private async closePanel(): Promise<void> {
    if (this.mode === 'annotation') {
      await this.saveAnnotation();
    }
    this.onClose();
  }

  private selectImportQuestion(item: HandwriteQuestionItem): void {
    this.importedQuestionId = item.id;
    this.importedQuestionLabel = item.label;
    this.importedQuestionStem = item.stem;
    this.showQuestionPicker = false;
    this.saveAnnotationMeta();
  }

  private clearImportQuestion(): void {
    this.importedQuestionId = 0;
    this.importedQuestionLabel = '';
    this.importedQuestionStem = '';
    this.showQuestionPicker = false;
    this.saveAnnotationMeta();
  }

  // answer 模式：导出笔迹缩略图并上传、绑定到作答。
  private async exportAndUpload(): Promise<void> {
    if (this.submitting) {
      return;
    }
    this.submitting = true;
    let filePath = '';
    try {
      // 取笔迹范围（Rect 单位为画布宽度的 1/1000）；右<=左 或 下<=上 视为空画布。
      const range = this.controller.getContentRange();
      if ((range.right - range.left) <= 0 || (range.bottom - range.top) <= 0) {
        this.toast('请先书写后再提交');
        return;
      }

      const pixelMap = await this.controller.getThumbnail(range);
      if (!pixelMap) {
        throw new Error('笔迹导出失败');
      }
      const packer = image.createImagePacker();
      // 用 PNG 保留透明背景：缩略图笔迹背景可能透明，转 JPEG 会被填黑。
      const packOpts: image.PackingOption = { format: 'image/png', quality: 100 };
      const buf = await packer.packing(pixelMap, packOpts);
      packer.release();
      pixelMap.release();

      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const fileName = `handwrite_${this.questionId}_${Date.now()}.png`;
      filePath = ctx.cacheDir + '/' + fileName;
      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, buf);
      fs.closeSync(file);

      let result: UploadResult = await AttaApi.upload(filePath, fileName, 'image/png');
      hilog.info(DOMAIN, TAG, 'uploaded handwrite %{public}s, id=%{public}d', fileName, result.id);

      if (!SettingsStore.instance.enableMockEnhance) {
        try {
          result = await AttaApi.imgEnhance(result.id);
        } catch (_) {
          // enhance optional
        }
      }

      const api = this.kind === 'paper' ? StudyApi.paper : StudyApi.course;
      await api.bindAnswerAttachment(this.entityId, this.questionId, result.id, '');
      hilog.info(DOMAIN, TAG, 'bound handwrite to q %{public}d', this.questionId);

      this.onSubmitted();
      this.onClose();
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'exportAndUpload failed: %{public}s', err.message);
      this.toast('提交失败：' + err.message);
    } finally {
      if (filePath.length > 0) {
        try {
          fs.unlinkSync(filePath);
        } catch (_) {
          // ignore
        }
      }
      this.submitting = false;
    }
  }

  @Builder
  headerBar() {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(24)
        .fontColor([Theme.TEXT])
        .onClick(() => {
          this.closePanel();
        })

      Text(this.mode === 'answer' ? '手写作答' : '批注')
        .fontSize(Theme.F_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)

      if (this.mode === 'annotation' && this.questionItems.length > 0) {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.list_bullet'))
            .fontSize(16)
            .fontColor([Theme.PRIMARY])
          Text(this.importedQuestionStem.length > 0 ? '更换题干' : '导入题干')
            .fontSize(Theme.F_SUB)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.PRIMARY)
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(Theme.PRIMARY_SOFT)
        .borderRadius(Theme.R_XL)
        .onClick(() => {
          this.showQuestionPicker = true;
        })
      }

      if (this.mode === 'answer') {
        Row({ space: 6 }) {
          if (this.submitting) {
            LoadingProgress().width(16).height(16).color(Color.White)
          }
          Text(this.submitting ? '提交中...' : '提交')
            .fontSize(Theme.F_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
        .padding({ left: 16, right: 16, top: 6, bottom: 6 })
        .backgroundColor(this.submitting ? Theme.TEXT_3 : Theme.PRIMARY)
        .borderRadius(Theme.R_XL)
        .onClick(() => {
          this.exportAndUpload();
        })
      }
    }
    .width('100%')
    .height(50)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  importedQuestionLayer() {
    if (this.mode === 'annotation' && this.importedQuestionStem.length > 0) {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text(this.importedQuestionLabel)
            .fontSize(Theme.F_SUB)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.PRIMARY)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.xmark_circle'))
              .fontSize(15)
              .fontColor([Theme.TEXT_2])
            Text('取消导入')
              .fontSize(Theme.F_MINI)
              .fontColor(Theme.TEXT_2)
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#0D000000')
          .borderRadius(Theme.R_XL)
          .onClick(() => {
            this.clearImportQuestion();
          })
        }
        .width('100%')

        Scroll() {
          HtmlRichText({
            html: this.importedQuestionStem,
            baseFontSize: Theme.F_SUB,
            maxImageWidth: 520
          })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        Row() {
          Column()
            .width(46)
            .height(4)
            .borderRadius(2)
            .backgroundColor('#33000000')
        }
        .width('100%')
        .height(18)
        .justifyContent(FlexAlign.Center)
        .gesture(
          PanGesture()
            .onActionStart(() => {
              this.questionPreviewDragStart = this.questionPreviewHeight;
            })
            .onActionUpdate((evt: GestureEvent) => {
              this.questionPreviewHeight = this.clampQuestionPreviewHeight(
                this.questionPreviewDragStart + evt.offsetY);
            })
            .onActionEnd(() => {
              this.saveAnnotationMeta();
            })
        )
      }
      .width('100%')
      .height(this.questionPreviewHeight)
      .padding(14)
      .backgroundColor('#F8FFFFFF')
      .borderRadius(Theme.R_MD)
      .border({ width: 1, color: Theme.DIVIDER })
      .margin({ left: 14, right: 14, top: 14 })
      .clip(true)
      .zIndex(2)
    }
  }

  @Builder
  questionPicker() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.showQuestionPicker = false;
        })

      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text('选择题干')
            .fontSize(Theme.F_BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .layoutWeight(1)
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([Theme.TEXT_2])
            .onClick(() => {
              this.showQuestionPicker = false;
            })
        }
        .width('100%')
        .padding({ bottom: 4 })

        if (this.importedQuestionStem.length > 0) {
          Row({ space: 10 }) {
            SymbolGlyph($r('sys.symbol.xmark_circle'))
              .fontSize(18)
              .fontColor([Theme.TEXT_2])
            Text('不导入题干，仅演算或记笔记')
              .fontSize(Theme.F_SUB)
              .fontColor(Theme.TEXT)
              .layoutWeight(1)
          }
          .width('100%')
          .padding(12)
          .backgroundColor('#F7F8FA')
          .borderRadius(Theme.R_MD)
          .onClick(() => {
            this.clearImportQuestion();
          })
        }

        List({ space: 6 }) {
          ForEach(this.questionItems, (item: HandwriteQuestionItem) => {
            ListItem() {
              Row({ space: 10 }) {
                Text(item.label)
                  .fontSize(Theme.F_SUB)
                  .fontColor(item.id === this.importedQuestionId ? Theme.PRIMARY : Theme.TEXT)
                  .fontWeight(item.id === this.importedQuestionId ? FontWeight.Medium : FontWeight.Normal)
                  .layoutWeight(1)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                if (item.id === this.importedQuestionId) {
                  SymbolGlyph($r('sys.symbol.checkmark_circle'))
                    .fontSize(18)
                    .fontColor([Theme.PRIMARY])
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(item.id === this.importedQuestionId ? Theme.PRIMARY_SOFT : '#F7F8FA')
              .borderRadius(Theme.R_MD)
              .onClick(() => {
                this.selectImportQuestion(item);
              })
            }
          }, (item: HandwriteQuestionItem) => `import_q_${item.id}`)
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('88%')
      .height('62%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(Theme.R_LG)
      .shadow({ radius: 18, color: '#26000000', offsetY: 6 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  unsupported() {
    Column({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
        .fontSize(40)
        .fontColor([Theme.TEXT_3])
      Text('当前设备不支持手写套件')
        .fontSize(Theme.F_SUB)
        .fontColor(Theme.TEXT_3)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      Column() {
        this.headerBar()

        // 题干预览（answer模式）
        if (this.mode === 'answer' && this.questionStem.length > 0) {
          Text(this.questionStem.replace(/<[^>]*>/g, '').trim())
            .fontSize(Theme.F_SUB)
            .fontColor(Theme.TEXT_2)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 8 })
        }

        // 手写画布：官方套件组件自带画布 + 工具栏。
        Stack({ alignContent: Alignment.TopStart }) {
          if (canIUse('SystemCapability.Stylus.Handwrite')) {
            HandwriteComponent({
              handwriteController: this.controller,
              defaultPenType: PenType.PEN,
              defaultPenInfo: this.penInfo,
              widthRatio: 1,
              heightRatio: 1,
              onInit: () => {
                this.onCanvasInit();
              },
              onScale: (_scale: number) => {
                // 缩放回调，暂无自定义行为
              }
            })
          } else {
            this.unsupported()
          }

          this.importedQuestionLayer()
        }
        .layoutWeight(1)
        .width('100%')
        .backgroundColor(Color.White)
        .border({ width: { top: 1 }, color: Theme.DIVIDER })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG_CREAM)

      if (this.showQuestionPicker) {
        this.questionPicker()
      }
    }
    .width('100%')
    .height('100%')
  }
}
