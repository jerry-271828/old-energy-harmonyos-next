// 手写面板：全屏绘图覆盖层，用于批注和手写作答。
// Canvas + 触控绘制，支持笔/橡皮/颜色/粗细/撤销/清除。
// 手写作答模式支持导出画布为图片（componentSnapshot + ImagePacker）。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { componentSnapshot } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { Theme } from '../theme/Theme';
import { AttaApi, UploadResult } from '../net/api/AttaApi';
import { StudyApi, StudyKind } from '../net/api/StudyApi';
import { SettingsStore } from '../store/SettingsStore';

interface HwStrokePoint {
  x: number;
  y: number;
}

interface HwStrokeLine {
  points: HwStrokePoint[];
  color: string;
  width: number;
  isEraser: boolean;
}

const PEN_COLORS: string[] = ['#1F2329', '#FF0000', '#3367FF', '#52C41A', '#FAAD14'];
const PEN_WIDTHS: number[] = [2, 4, 6, 8];

@ComponentV2
export struct HandwritePanel {
  @Param mode: string = 'annotation';          // 'annotation' | 'answer'
  @Param questionStem: string = '';             // 题干文本(answer模式)
  @Param entityId: number = 0;
  @Param questionId: number = 0;
  @Param kind: StudyKind = 'course';
  @Param onClose: () => void = () => {};
  @Param onSubmitted: () => void = () => {};    // 上传成功后回调

  @Local private lines: HwStrokeLine[] = [];
  @Local private currentLine: HwStrokeLine | null = null;
  @Local private tool: string = 'pen';
  @Local private penColor: string = '#1F2329';
  @Local private penWidth: number = 4;
  @Local private submitting: boolean = false;

  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);
  private canvasW: number = 0;
  private canvasH: number = 0;

  private redraw(): void {
    this.ctx.clearRect(0, 0, this.canvasW, this.canvasH);
    for (let i = 0; i < this.lines.length; i++) {
      this.drawLine(this.lines[i]);
    }
    if (this.currentLine !== null) {
      this.drawLine(this.currentLine);
    }
  }

  private drawLine(line: HwStrokeLine): void {
    if (line.points.length < 2) {
      return;
    }
    this.ctx.beginPath();
    this.ctx.strokeStyle = line.isEraser ? '#FFFFFF' : line.color;
    this.ctx.lineWidth = line.isEraser ? line.width * 4 : line.width;
    this.ctx.globalAlpha = 1.0;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
    this.ctx.moveTo(line.points[0].x, line.points[0].y);
    for (let i = 1; i < line.points.length; i++) {
      this.ctx.lineTo(line.points[i].x, line.points[i].y);
    }
    this.ctx.stroke();
  }

  private undo(): void {
    if (this.lines.length > 0) {
      this.lines.pop();
      this.lines = [...this.lines];
      this.redraw();
    }
  }

  private clear(): void {
    this.lines = [];
    this.ctx.clearRect(0, 0, this.canvasW, this.canvasH);
  }

  private async exportAndUpload(): Promise<void> {
    if (this.submitting || this.lines.length === 0) {
      return;
    }
    this.submitting = true;
    try {
      const pixelMap = await componentSnapshot.get('hwCanvasArea');
      const packer = image.createImagePacker();
      const packOpts: image.PackingOption = { format: 'image/jpeg', quality: 85 };
      const buf = await packer.packing(pixelMap, packOpts);
      packer.release();
      pixelMap.release();

      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const fileName = `handwrite_${this.questionId}_${Date.now()}.jpg`;
      const filePath = ctx.cacheDir + '/' + fileName;
      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, buf);
      fs.closeSync(file);

      let result = await AttaApi.upload(filePath, fileName, 'image/jpeg');
      hilog.info(0x0002, 'HandwritePanel', 'uploaded handwrite %{public}s, id=%{public}d',
        fileName, result.id);

      if (!SettingsStore.instance.enableMockEnhance) {
        try {
          result = await AttaApi.imgEnhance(result.id);
        } catch (_) {
          // enhance optional
        }
      }

      const api = this.kind === 'paper' ? StudyApi.paper : StudyApi.course;
      await api.bindAnswerAttachment(this.entityId, this.questionId, result.id, '');
      hilog.info(0x0002, 'HandwritePanel', 'bound handwrite to q %{public}d', this.questionId);

      try {
        fs.unlinkSync(filePath);
      } catch (_) {
        // ignore
      }

      this.onSubmitted();
      this.onClose();
    } catch (e) {
      const err = e as Error;
      hilog.error(0x0002, 'HandwritePanel', 'exportAndUpload failed: %{public}s', err.message);
    } finally {
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

      Text('清除')
        .fontSize(Theme.F_SUB)
        .fontColor(Theme.DANGER)
        .onClick(() => {
          this.clear();
        })

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
        .backgroundColor(this.lines.length > 0 ? Theme.PRIMARY : Theme.TEXT_3)
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
  toolBar() {
    Row({ space: 10 }) {
      // Pen / Eraser
      SymbolGlyph($r('sys.symbol.card_writer'))
        .fontSize(22)
        .fontColor([this.tool === 'pen' ? Theme.PRIMARY : Theme.TEXT_2])
        .onClick(() => {
          this.tool = 'pen';
        })
      SymbolGlyph($r('sys.symbol.xmark'))
        .fontSize(22)
        .fontColor([this.tool === 'eraser' ? Theme.PRIMARY : Theme.TEXT_2])
        .onClick(() => {
          this.tool = 'eraser';
        })

      Divider().vertical(true).height(22).color(Theme.DIVIDER)

      ForEach(PEN_COLORS, (c: string) => {
        Circle({ width: 20, height: 20 })
          .fill(c)
          .border({ width: this.penColor === c ? 2 : 0, color: Theme.PRIMARY })
          .onClick(() => {
            this.penColor = c;
          })
      }, (c: string) => c)

      Divider().vertical(true).height(22).color(Theme.DIVIDER)

      ForEach(PEN_WIDTHS, (w: number) => {
        Circle({ width: w + 8, height: w + 8 })
          .fill(this.penWidth === w ? Theme.PRIMARY : Theme.TEXT_3)
          .onClick(() => {
            this.penWidth = w;
          })
      }, (w: number) => `pw${w}`)

      Divider().vertical(true).height(22).color(Theme.DIVIDER)

      SymbolGlyph($r('sys.symbol.repeat_1'))
        .fontSize(22)
        .fontColor([this.lines.length > 0 ? Theme.TEXT_2 : Theme.TEXT_3])
        .onClick(() => {
          this.undo();
        })
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#F0F2F5')
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

      // Drawing area — componentSnapshot 用 id 捕获此区域
      Column() {
        Canvas(this.ctx)
          .width('100%')
          .layoutWeight(1)
          .backgroundColor(Color.White)
          .onAreaChange((_old: Area, now: Area) => {
            this.canvasW = now.width as number;
            this.canvasH = now.height as number;
          })
          .onTouch((event: TouchEvent) => {
            const touch = event.touches[0];
            const p: HwStrokePoint = { x: touch.x, y: touch.y };

            if (event.type === TouchType.Down) {
              this.currentLine = {
                points: [p],
                color: this.penColor,
                width: this.penWidth,
                isEraser: this.tool === 'eraser'
              };
            } else if (event.type === TouchType.Move && this.currentLine !== null) {
              this.currentLine.points.push(p);
              this.redraw();
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              if (this.currentLine !== null && this.currentLine.points.length > 1) {
                this.lines.push(this.currentLine);
                this.lines = [...this.lines];
              }
              this.currentLine = null;
            }
          })
      }
      .id('hwCanvasArea')
      .layoutWeight(1)
      .backgroundColor(Color.White)
      .border({ width: { top: 1 }, color: Theme.DIVIDER })

      this.toolBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG_CREAM)
  }
}
