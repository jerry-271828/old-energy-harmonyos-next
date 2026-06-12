// 批注画布 overlay：笔/橡皮/颜色/粗细/透明度。
// 覆盖在 PDF 视图上方，使用 Canvas 绘制。批注数据本地持久化（JSON per file）。

import { Theme } from '../theme/Theme';
import { GmStorage } from '../bridge/GmStorage';
import { SettingsStore } from '../store/SettingsStore';

interface StrokePoint {
  x: number;
  y: number;
}

interface StrokeLine {
  points: StrokePoint[];
  color: string;
  width: number;
  opacity: number;
  isEraser: boolean;
}

interface AnnotationData {
  lines: StrokeLine[];
}

const COLORS: string[] = ['#FF0000', '#3367FF', '#52C41A', '#FAAD14', '#1F2329'];
const WIDTHS: number[] = [2, 4, 6, 8];

@ComponentV2
export struct AnnotationCanvas {
  @Param fileKey: string = '';
  @Param enabled: boolean = false;
  @Param @Once canvasWidth: number = 600;
  @Param @Once canvasHeight: number = 800;

  @Local private lines: StrokeLine[] = [];
  @Local private currentLine: StrokeLine | null = null;
  @Local private tool: string = 'pen';  // 'pen' | 'eraser'
  @Local private penColor: string = '#FF0000';
  @Local private penWidth: number = 4;
  @Local private penOpacity: number = 1.0;
  @Local private showToolbar: boolean = true;

  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);

  aboutToAppear(): void {
    this.loadAnnotation();
  }

  private loadAnnotation(): void {
    if (this.fileKey.length === 0) {
      return;
    }
    const key = `annot_${this.fileKey}`;
    const raw = GmStorage.getSync(key);
    if (raw.length > 0) {
      try {
        const data = JSON.parse(raw) as AnnotationData;
        this.lines = data.lines || [];
      } catch (e) {
        this.lines = [];
      }
    }
  }

  private saveAnnotation(): void {
    if (this.fileKey.length === 0) {
      return;
    }
    const key = `annot_${this.fileKey}`;
    const data: AnnotationData = { lines: this.lines };
    GmStorage.putAsync(key, JSON.stringify(data));
  }

  private redraw(): void {
    this.ctx.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
    for (let i = 0; i < this.lines.length; i++) {
      this.drawLine(this.lines[i]);
    }
    if (this.currentLine !== null) {
      this.drawLine(this.currentLine);
    }
  }

  private drawLine(line: StrokeLine): void {
    if (line.points.length < 2) {
      return;
    }
    this.ctx.beginPath();
    this.ctx.strokeStyle = line.isEraser ? '#FFFFFF' : line.color;
    this.ctx.lineWidth = line.isEraser ? line.width * 3 : line.width;
    this.ctx.globalAlpha = line.isEraser ? 1.0 : line.opacity;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
    this.ctx.moveTo(line.points[0].x, line.points[0].y);
    for (let i = 1; i < line.points.length; i++) {
      this.ctx.lineTo(line.points[i].x, line.points[i].y);
    }
    this.ctx.stroke();
    this.ctx.globalAlpha = 1.0;
  }

  private clear(): void {
    this.lines = [];
    this.ctx.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
    this.saveAnnotation();
  }

  private undo(): void {
    if (this.lines.length > 0) {
      this.lines.pop();
      this.lines = [...this.lines];
      this.redraw();
      this.saveAnnotation();
    }
  }

  @Builder
  toolbar() {
    if (this.showToolbar && this.enabled) {
      GlassCardOverlay() {
        Row({ space: 8 }) {
          // Tool selection
          SymbolGlyph($r('sys.symbol.pencil'))
            .fontSize(20)
            .fontColor([this.tool === 'pen' ? Theme.PRIMARY : Theme.TEXT_2])
            .onClick(() => {
              this.tool = 'pen';
            })
          SymbolGlyph($r('sys.symbol.eraser'))
            .fontSize(20)
            .fontColor([this.tool === 'eraser' ? Theme.PRIMARY : Theme.TEXT_2])
            .onClick(() => {
              this.tool = 'eraser';
            })

          Divider().vertical(true).height(20).color(Theme.DIVIDER)

          // Color selection
          ForEach(COLORS, (c: string) => {
            Circle({ width: 18, height: 18 })
              .fill(c)
              .border({
                width: this.penColor === c ? 2 : 0,
                color: Theme.TEXT
              })
              .onClick(() => {
                this.penColor = c;
              })
          }, (c: string) => c)

          Divider().vertical(true).height(20).color(Theme.DIVIDER)

          // Width selection
          ForEach(WIDTHS, (w: number) => {
            Circle({ width: w + 8, height: w + 8 })
              .fill(this.penWidth === w ? Theme.PRIMARY : Theme.TEXT_3)
              .onClick(() => {
                this.penWidth = w;
              })
          }, (w: number) => `w${w}`)

          Divider().vertical(true).height(20).color(Theme.DIVIDER)

          // Undo / Clear
          SymbolGlyph($r('sys.symbol.arrow_uturn_backward'))
            .fontSize(20)
            .fontColor([Theme.TEXT_2])
            .onClick(() => {
              this.undo();
            })
          SymbolGlyph($r('sys.symbol.trash'))
            .fontSize(20)
            .fontColor([Theme.DANGER])
            .onClick(() => {
              this.clear();
            })
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.enabled) {
        Canvas(this.ctx)
          .width(this.canvasWidth)
          .height(this.canvasHeight)
          .backgroundColor(Color.Transparent)
          .onReady(() => {
            this.redraw();
          })
          .onTouch((event: TouchEvent) => {
            if (!this.enabled) {
              return;
            }
            const touch = event.touches[0];
            const p: StrokePoint = { x: touch.x, y: touch.y };

            if (event.type === TouchType.Down) {
              this.currentLine = {
                points: [p],
                color: this.penColor,
                width: this.penWidth,
                opacity: this.penOpacity,
                isEraser: this.tool === 'eraser'
              };
            } else if (event.type === TouchType.Move && this.currentLine !== null) {
              this.currentLine.points.push(p);
              this.redraw();
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              if (this.currentLine !== null && this.currentLine.points.length > 1) {
                this.lines.push(this.currentLine);
                this.lines = [...this.lines];
                this.saveAnnotation();
              }
              this.currentLine = null;
            }
          })

        this.toolbar()
      }
    }
  }
}

@ComponentV2
struct GlassCardOverlay {
  @BuilderParam content: () => void = () => {};

  build() {
    Row() {
      this.content()
    }
    .backgroundColor('#E8FFFFFF')
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(Theme.R_XL)
    .border({ width: 1, color: '#30000000' })
    .shadow({ radius: 12, color: '#22000000', offsetY: 4 })
    .margin({ bottom: 16 })
  }
}
