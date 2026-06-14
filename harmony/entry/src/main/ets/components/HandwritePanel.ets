// 手写面板：基于官方 Pen Kit 手写套件（HandwriteComponent + HandwriteController）。
// 组件自带画布与手写工具栏（笔刷/颜色/粗细/橡皮/撤销由套件内置工具栏处理），
// 壳层只负责标题栏与「提交」动作。
//
// - annotation 模式：纯手写草稿板（不上传，关闭即弃，沿用旧版语义）。
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

const DOMAIN = 0x0002;
const TAG = 'HandwritePanel';

@ComponentV2
export struct HandwritePanel {
  @Param mode: string = 'annotation';          // 'annotation' | 'answer'
  @Param questionStem: string = '';            // 题干文本(answer模式)
  @Param entityId: number = 0;
  @Param questionId: number = 0;
  @Param kind: StudyKind = 'course';
  @Param onClose: () => void = () => {};
  @Param onSubmitted: () => void = () => {};   // 上传成功后回调

  @Local private submitting: boolean = false;

  // 手写套件功能类实例：画布初始化、加载/保存、取笔迹范围与缩略图都经它。
  private controller: HandwriteController = new HandwriteController();
  // 各笔刷默认宽度（取值范围见官方文档：钢笔/圆珠笔 2-10，铅笔 4-20）。
  private penInfo: PenHspInfo[] = [
    { penType: PenType.PEN, penWidth: 4 },
    { penType: PenType.BALLPOINT_PEN, penWidth: 4 },
    { penType: PenType.PENCIL, penWidth: 8 }
  ] as PenHspInfo[];

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1800 });
    } catch (_) {
      // ignore
    }
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
          this.onClose();
        })

      Text(this.mode === 'answer' ? '手写作答' : '批注')
        .fontSize(Theme.F_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)

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
              hilog.info(DOMAIN, TAG, 'handwrite canvas init (mode=%{public}s)', this.mode);
            },
            onScale: (_scale: number) => {
              // 缩放回调，暂无自定义行为
            }
          })
        } else {
          this.unsupported()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor(Color.White)
      .border({ width: { top: 1 }, color: Theme.DIVIDER })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG_CREAM)
  }
}
