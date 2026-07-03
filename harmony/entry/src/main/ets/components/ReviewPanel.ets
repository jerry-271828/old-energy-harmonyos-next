// 批阅面板 — 点击作答图片后全屏弹出。
// 功能：多图查看（缩放/旋转/平移）、画布批注（笔/橡皮）、
//       学生自评打分（selfReadOverSwitch>0 时显示）、题目导航。
// 批注坐标为屏幕空间（随图旋转/缩放时批注固定在屏幕位置，与 web 端行为一致）。
// 批注数据本地持久化，key = review_{entityId}_{questionId}。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../theme/Theme';
import { SquishButton, LoadingView } from './glass/GlassKit';
import { StudyApi, StudyKind } from '../net/api/StudyApi';
import { ApiClient } from '../net/ApiClient';
import { QuestionContent, AnswerRecord, ReadoverItem } from '../models/Question';
import { AttachmentEntity } from '../models/Course';
import { GmStorage } from '../bridge/GmStorage';
import { HtmlRichText } from './HtmlRichText';

const DOMAIN = 0x0002;
const TAG = 'ReviewPanel';

interface StrokePoint { x: number; y: number; }
interface StrokeLine {
  points: StrokePoint[];
  color: string;
  isEraser: boolean;
}
interface AnnotationData { lines: StrokeLine[]; }

const PEN_COLORS: string[] = ['#FF4040', '#3367FF', '#52C41A', '#FAAD14', '#1F2329'];
const SCALE_MIN = 0.4;
const SCALE_MAX = 4.0;
const SCALE_STEP = 0.3;

@ComponentV2
export struct ReviewPanel {
  @Param questions: QuestionContent[] = [];
  @Param answers: AnswerRecord[] = [];
  @Param entityId: number = 0;
  @Param kind: StudyKind = 'course';
  @Param initialQuestionIdx: number = 0;
  @Param studentId: number = 0;
  @Param onClose: () => void = () => {};
  @Param onScored: () => void = () => {};

  @Local private currentIdx: number = 0;
  @Local private tool: string = 'pen';      // 'pen' | 'eraser' | 'move'
  @Local private penColor: string = '#FF4040';
  @Local private imgScale: number = 1.0;
  @Local private imgRot: number = 0;        // 0 / 90 / 180 / 270
  @Local private panX: number = 0;
  @Local private panY: number = 0;
  @Local private lines: StrokeLine[] = [];
  @Local private currentLine: StrokeLine | null = null;
  @Local private showAnswer: boolean = false;
  @Local private scoring: boolean = false;
  @Local private selectedScore: number = -1;
  // 画布尺寸（在 onAreaChange 里拿到容器真实 vp 尺寸后更新）
  @Local private cvW: number = 360;
  @Local private cvH: number = 500;

  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings);
  // move 模式下记录上次触点（临时复用，不入 lines）
  private lastTouchX: number = 0;
  private lastTouchY: number = 0;

  // ---- 生命周期 ----

  aboutToAppear(): void {
    this.currentIdx = this.initialQuestionIdx;
    this.loadState();
  }

  private switchTo(idx: number): void {
    this.saveAnnotation();
    this.currentIdx = idx;
    this.resetView();
    this.loadState();
  }

  private resetView(): void {
    this.imgScale = 1.0;
    this.imgRot = 0;
    this.panX = 0;
    this.panY = 0;
    this.showAnswer = false;
    this.lines = [];
    this.currentLine = null;
  }

  private loadState(): void {
    const q = this.currentQuestion();
    if (q === null) { return; }
    const raw = GmStorage.getSync(this.annotKey());
    if (raw.length > 0) {
      try {
        const data = JSON.parse(raw) as AnnotationData;
        this.lines = data.lines ?? [];
      } catch (_) { this.lines = []; }
    } else {
      this.lines = [];
    }
    const rec = this.findAnswer(q.id);
    this.selectedScore =
      (rec !== null && rec.studentScore !== null && rec.studentScore >= 0)
        ? rec.studentScore : -1;
    this.redraw();
  }

  private saveAnnotation(): void {
    const data: AnnotationData = { lines: this.lines };
    GmStorage.putAsync(this.annotKey(), JSON.stringify(data));
  }

  private annotKey(): string {
    const q = this.currentQuestion();
    return `review_${this.entityId}_${q !== null ? q.id : 0}`;
  }

  // ---- 数据查询 ----

  private currentQuestion(): QuestionContent | null {
    if (this.currentIdx < 0 || this.currentIdx >= this.questions.length) { return null; }
    return this.questions[this.currentIdx];
  }

  private findAnswer(questionId: number): AnswerRecord | null {
    for (let i = 0; i < this.answers.length; i++) {
      if (this.answers[i].questionId === questionId) { return this.answers[i]; }
    }
    return null;
  }

  // 去重后的作答图片（同 id type4/5 两条只取一次）
  private answerImages(): AttachmentEntity[] {
    const q = this.currentQuestion();
    if (q === null) { return []; }
    const rec = this.findAnswer(q.id);
    if (rec === null || rec.attachments === null) { return []; }
    const seen: number[] = [];
    const out: AttachmentEntity[] = [];
    for (let i = 0; i < rec.attachments.length; i++) {
      const att = rec.attachments[i];
      if (seen.indexOf(att.id) >= 0) { continue; }
      seen.push(att.id);
      const ext = att.attachmentExtraName.toLowerCase();
      if (ext === '.png' || ext === '.jpg' || ext === '.jpeg' || ext === '.gif') {
        out.push(att);
      }
    }
    return out;
  }

  // 生成 0..max 的整数数组（用于分值按钮）
  private scoreRange(max: number): number[] {
    const arr: number[] = [];
    for (let i = 0; i <= max; i++) { arr.push(i); }
    return arr;
  }

  private hasSelfReadOver(): boolean {
    const q = this.currentQuestion();
    return q !== null && q.selfReadOverSwitch > 0;
  }

  // ---- Canvas 批注 ----

  private redraw(): void {
    this.ctx.clearRect(0, 0, this.cvW, this.cvH);
    for (let i = 0; i < this.lines.length; i++) { this.drawLine(this.lines[i]); }
    if (this.currentLine !== null) { this.drawLine(this.currentLine); }
  }

  private drawLine(line: StrokeLine): void {
    if (line.points.length < 2) { return; }
    this.ctx.beginPath();
    this.ctx.strokeStyle = line.isEraser ? Theme.BG_CREAM.toString() : line.color;
    this.ctx.lineWidth = line.isEraser ? 24 : 4;
    this.ctx.globalAlpha = line.isEraser ? 1.0 : 0.9;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
    this.ctx.moveTo(line.points[0].x, line.points[0].y);
    for (let j = 1; j < line.points.length; j++) {
      this.ctx.lineTo(line.points[j].x, line.points[j].y);
    }
    this.ctx.stroke();
    this.ctx.globalAlpha = 1.0;
  }

  // Canvas touch handler：笔/橡皮模式绘线，移动模式更新 pan 偏移
  private handleTouch(event: TouchEvent): void {
    if (event.touches.length === 0) { return; }
    const touch = event.touches[0];
    const tx = touch.x;
    const ty = touch.y;

    if (this.tool === 'move') {
      if (event.type === TouchType.Down) {
        this.lastTouchX = tx;
        this.lastTouchY = ty;
      } else if (event.type === TouchType.Move) {
        this.panX += tx - this.lastTouchX;
        this.panY += ty - this.lastTouchY;
        this.lastTouchX = tx;
        this.lastTouchY = ty;
      }
      return;
    }

    const p: StrokePoint = { x: tx, y: ty };
    if (event.type === TouchType.Down) {
      this.currentLine = {
        points: [p],
        color: this.penColor,
        isEraser: this.tool === 'eraser'
      };
    } else if (event.type === TouchType.Move && this.currentLine !== null) {
      this.currentLine.points.push(p);
      this.redraw();
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      if (this.currentLine !== null && this.currentLine.points.length > 1) {
        this.lines = [...this.lines, this.currentLine];
        this.saveAnnotation();
      }
      this.currentLine = null;
    }
  }

  // ---- Builders ----

  @Builder
  topBar() {
    Row({ space: 8 }) {
      // 关闭
      SquishButton({ onTap: () => { this.saveAnnotation(); this.onClose(); } }) {
        Text('✕')
          .fontSize(18)
          .fontColor(Theme.TEXT)
          .width(34).height(34)
          .textAlign(TextAlign.Center)
      }

      Blank().layoutWeight(1)

      // 题目导航
      Row({ space: 4 }) {
        Text('‹')
          .fontSize(24).fontColor(this.currentIdx > 0 ? Theme.PRIMARY : Theme.TEXT_3)
          .width(30).height(30).textAlign(TextAlign.Center)
          .onClick(() => { if (this.currentIdx > 0) { this.switchTo(this.currentIdx - 1); } })
        Text(`${this.currentIdx + 1} / ${this.questions.length}`)
          .fontSize(Theme.F_BODY).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
        Text('›')
          .fontSize(24)
          .fontColor(this.currentIdx < this.questions.length - 1 ? Theme.PRIMARY : Theme.TEXT_3)
          .width(30).height(30).textAlign(TextAlign.Center)
          .onClick(() => {
            if (this.currentIdx < this.questions.length - 1) {
              this.switchTo(this.currentIdx + 1);
            }
          })
      }
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor('#F0F2F5')
      .borderRadius(Theme.R_XL)

      Blank().layoutWeight(1)

      // 查看答案切换
      Text(this.showAnswer ? '隐藏答案' : '查看答案')
        .fontSize(Theme.F_SUB)
        .fontColor(this.showAnswer ? Theme.PRIMARY : Theme.TEXT_2)
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor(this.showAnswer ? Theme.PRIMARY_SOFT : '#F0F2F5')
        .borderRadius(Theme.R_XL)
        .onClick(() => { this.showAnswer = !this.showAnswer; })
    }
    .width('100%')
    .height(50)
    .padding({ left: 14, right: 14 })
    .backgroundColor('#EEF6F1EC')
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .border({ width: { bottom: 1 }, color: '#14000000' })
  }

  @Builder
  imageArea() {
    Stack({ alignContent: Alignment.Center }) {
      // 图片层（带变换）
      Column() {
        ForEach(this.answerImages(), (att: AttachmentEntity) => {
          Image(ApiClient.assetUrl(att.attachmentLinkAddress))
            .width('100%')
            .objectFit(ImageFit.Contain)
            .draggable(false)
            .margin({ bottom: 8 })
        }, (att: AttachmentEntity) => `img_${att.id}`)

        if (this.answerImages().length === 0) {
          Text('暂无作答图片')
            .fontSize(Theme.F_BODY)
            .fontColor(Theme.TEXT_3)
            .margin({ top: 60 })
        }
      }
      .width('100%')
      .height('100%')
      .scale({ x: this.imgScale, y: this.imgScale })
      .rotate({ angle: this.imgRot })
      .translate({ x: this.panX, y: this.panY })

      // 批注画布层（不随缩放/旋转变换，保持屏幕空间坐标）
      Canvas(this.ctx)
        .width(this.cvW)
        .height(this.cvH)
        .backgroundColor(Color.Transparent)
        .onReady(() => { this.redraw(); })
        .onTouch((evt: TouchEvent) => { this.handleTouch(evt); })
    }
    .width('100%')
    .layoutWeight(1)
    .clip(true)
    .onAreaChange((_old, newSize) => {
      const w = newSize.width as number;
      const h = newSize.height as number;
      if (w > 0 && h > 0 && (this.cvW !== w || this.cvH !== h)) {
        this.cvW = w;
        this.cvH = h;
        this.redraw();
      }
    })
  }

  @Builder
  toolBarRow() {
    Row({ space: 2 }) {
      // 工具按钮
      this.toolBtn('笔', 'pen')
      this.toolBtn('橡皮', 'eraser')
      this.toolBtn('移动', 'move')

      Divider().vertical(true).height(20).color(Theme.DIVIDER).margin({ left: 4, right: 4 })

      // 颜色点（笔模式下可见）
      ForEach(PEN_COLORS, (c: string) => {
        Circle({ width: 16, height: 16 })
          .fill(c)
          .border({ width: this.penColor === c ? 2.5 : 0, color: Theme.TEXT })
          .margin({ left: 2 })
          .onClick(() => { this.penColor = c; this.tool = 'pen'; })
      }, (c: string) => `clr_${c}`)

      Blank().layoutWeight(1)

      // 旋转
      Text('↺').fontSize(20).fontColor(Theme.TEXT_2).width(34).height(34)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.imgRot = (this.imgRot - 90 + 360) % 360; })
      Text('↻').fontSize(20).fontColor(Theme.TEXT_2).width(34).height(34)
        .textAlign(TextAlign.Center)
        .onClick(() => { this.imgRot = (this.imgRot + 90) % 360; })

      // 缩放
      Text('－').fontSize(20)
        .fontColor(this.imgScale <= SCALE_MIN ? Theme.TEXT_3 : Theme.TEXT_2)
        .width(34).height(34).textAlign(TextAlign.Center)
        .onClick(() => { this.imgScale = Math.max(SCALE_MIN, this.imgScale - SCALE_STEP); })
      Text('＋').fontSize(20)
        .fontColor(this.imgScale >= SCALE_MAX ? Theme.TEXT_3 : Theme.TEXT_2)
        .width(34).height(34).textAlign(TextAlign.Center)
        .onClick(() => { this.imgScale = Math.min(SCALE_MAX, this.imgScale + SCALE_STEP); })

      // 清屏
      Text('清')
        .fontSize(Theme.F_SUB).fontColor(Theme.DANGER)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor('#14FF0000').borderRadius(Theme.R_SM)
        .onClick(() => {
          this.lines = [];
          this.ctx.clearRect(0, 0, this.cvW, this.cvH);
          this.saveAnnotation();
        })
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .backgroundColor('#EEF6F1EC')
    .backgroundBlurStyle(BlurStyle.COMPONENT_THIN)
    .border({ width: { top: 1 }, color: '#14000000' })
  }

  @Builder
  toolBtn(label: string, id: string) {
    Text(label)
      .fontSize(Theme.F_SUB)
      .fontColor(this.tool === id ? Theme.PRIMARY : Theme.TEXT_2)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(Theme.R_SM)
      .backgroundColor(this.tool === id ? Theme.PRIMARY_SOFT : Color.Transparent)
      .onClick(() => { this.tool = id; })
  }

  @Builder
  scoreSectionContent() {
    // hasSelfReadOver() が true なら currentQuestion() は非 null が保証される
    if (this.hasSelfReadOver()) {
      Column({ space: 8 }) {
        // 标题行
        Row({ space: 8 }) {
          Text('★').fontSize(14).fontColor(Theme.WARN)
          Text('自评打分')
            .fontSize(Theme.F_SUB).fontWeight(FontWeight.Medium).fontColor(Theme.TEXT)
          if (this.scoring) {
            LoadingProgress().width(14).height(14).color(Theme.PRIMARY)
          }
          Blank().layoutWeight(1)
          Text(`满分 ${(this.currentQuestion() as QuestionContent).questionScore} 分`)
            .fontSize(Theme.F_MINI).fontColor(Theme.TEXT_3)
        }
        .width('100%')

        // 分值按钮（0 ~ questionScore），允许换行；用 margin 代替 Flex space 避免 LengthMetrics 问题
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.scoreRange((this.currentQuestion() as QuestionContent).questionScore),
            (s: number) => {
              Text(`${s}`)
                .fontSize(Theme.F_SUB)
                .fontColor(this.selectedScore === s ? Color.White : Theme.TEXT)
                .width(36).height(28).textAlign(TextAlign.Center)
                .borderRadius(Theme.R_SM)
                .backgroundColor(this.selectedScore === s ? Theme.PRIMARY : '#F0F2F5')
                .margin({ right: 6, bottom: 6 })
                .onClick(() => { this.doScore(s); })
            }, (s: number) => `s_${s}`)
        }
        .width('100%')

        // 展开答案
        if (this.showAnswer) {
          if ((this.currentQuestion() as QuestionContent).answer !== null &&
              (this.currentQuestion() as QuestionContent).answer!.length > 0) {
            Column({ space: 4 }) {
              Divider().color(Theme.DIVIDER)
              Text('参考答案').fontSize(Theme.F_SUB).fontWeight(FontWeight.Medium)
                .fontColor(Theme.SUCCESS).width('100%')
              HtmlRichText({ html: (this.currentQuestion() as QuestionContent).answer! })
            }
            .width('100%')
            .padding({ top: 4 })
          }
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor(Theme.BG_CREAM)
      .border({ width: { top: 1 }, color: '#14000000' })
    }
  }

  // ---- 自评打分 ----

  private async doScore(score: number): Promise<void> {
    const q = this.currentQuestion();
    if (q === null || this.scoring) { return; }
    const rec = this.findAnswer(q.id);
    this.scoring = true;
    this.selectedScore = score;
    try {
      const api = this.kind === 'paper' ? StudyApi.paper : StudyApi.course;
      const item: ReadoverItem = {
        questionId: q.id,
        studentId: this.studentId,
        judgeTag: 2,
        readOverTag: 1,
        studentScore: score,
        answer: (rec !== null && rec.studentAnswer !== null) ? rec.studentAnswer : null,
        teacherReadOverContent: null,
        readAttachmentList: null
      };
      if (this.kind === 'course') { item.courseId = this.entityId; }
      else { item.paperId = this.entityId; }
      await api.readover([item]);
      this.onScored();
      hilog.info(DOMAIN, TAG, 'readover q%{public}d score=%{public}d', q.id, score);
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'readover failed: %{public}s', err.message);
      this.selectedScore = -1;
    } finally {
      this.scoring = false;
    }
  }

  // ---- build ----

  build() {
    Column() {
      this.topBar()
      this.imageArea()
      this.toolBarRow()
      if (this.hasSelfReadOver()) {
        this.scoreSectionContent()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG_CREAM)
  }
}
