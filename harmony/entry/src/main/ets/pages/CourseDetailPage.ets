// 课件详情页（NavDestination）：加载并渲染课件内容块。
// 内容块类型：0=富文本（HtmlRichText）、1=附件（卡片+占位）、2=题目（QuestionCard）。
// 也承载 paper（考试）的详情——结构同构。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { Theme } from '../theme/Theme';
import { UiStore } from '../store/UiStore';
import { Nav } from '../utils/Nav';
import { HtmlRichText } from '../components/HtmlRichText';
import { GlassCard, EmptyView, LoadingView, SquishButton } from '../components/glass/GlassKit';
import { StudyApi, StudyKind } from '../net/api/StudyApi';
import { ReddotApi } from '../net/api/ReddotApi';
import { CourseBlock, AttachmentEntity, CourseEntityInfo,
  CourseStatistics, CourseDetailParam } from '../models/Course';
import { QuestionContent, AnswerRecord } from '../models/Question';
import { SettingsStore } from '../store/SettingsStore';
import { ApiClient } from '../net/ApiClient';
import { PhotoUploader } from '../utils/PhotoUploader';
import { QuickSubmitSheet, QuickSubmitItem, QuickSubmitFill } from '../components/QuickSubmitSheet';
import { Downloader } from '../utils/Downloader';
import { AttachmentViewerParam } from './AttachmentViewerPage';
import { HandwritePanel } from '../components/HandwritePanel';

const DOMAIN = 0x0002;
const TAG = 'CourseDetailPage';

interface TitleAnchor {
  level: number;
  text: string;
  index: number;
}

@ComponentV2
export struct CourseDetailPage {
  ui: UiStore = UiStore.instance;
  settings: SettingsStore = SettingsStore.instance;

  @Local private entityId: number = 0;
  @Local private kind: StudyKind = 'course';
  @Local private blocks: CourseBlock[] = [];
  @Local private answers: AnswerRecord[] = [];
  @Local private entityInfo: CourseEntityInfo | null = null;
  @Local private statistics: CourseStatistics | null = null;
  @Local private titleAnchors: TitleAnchor[] = [];
  @Local private loading: boolean = true;
  @Local private error: string = '';
  @Local private showAnswers: boolean = false;
  @Local private showTitleNav: boolean = false;
  @Local private submitting: boolean = false;
  @Local private submitted: boolean = false;       // = entityInfo.mappingStatus === 1（已进入批阅/补交阶段）
  @Local private hasQuestions: boolean = false;     // 内容里是否含题目块（无题不显示提交栏，对照前端 questionCounts>0）
  @Local private countdownSec: number = 0;
  @Local private uploadingQuestionId: number = 0;
  @Local private capturingQuestionId: number = 0;  // 拍照上传中
  @Local private showAnnotation: boolean = false;
  @Local private handwriteQuestionId: number = 0;  // >0 时显示手写作答面板
  @Local private handwriteStem: string = '';
  @Local private showQuickSubmit: boolean = false;   // 快捷提交弹窗
  @Local private quickSubmitting: boolean = false;
  @Local private quickItems: QuickSubmitItem[] = [];
  // 点选乐观更新覆盖层：qid → studentAnswer。点击即写，给即时高亮反馈；
  // 保存成功/失败后重拉 answers() 再清除对应项，回到服务端真值（含判分）。
  @Local private pendingAnswers: Map<number, string> = new Map<number, string>();
  // 附件明文 URL 映射：content 接口的 attachmentLinkAddress 是 DES 加密串（不可用），
  // statistics 接口的 studentCourseAttachments 才是明文路径——用 id 做 key 反查。
  private attUrlMap: Map<number, string> = new Map<number, string>();

  private createTime: string = '';   // 列表项 createTime，补交时作为 courseBeginTime

  private scroller: Scroller = new Scroller();
  private countdownTimer: number = -1;

  aboutToAppear(): void {
    // param 为 CourseDetailParam {id, createTime, kind}；兼容旧版仅传 number/string
    const param = Nav.stack.getParamByName('courseDetail') as Object[];
    if (param.length > 0) {
      const raw: Object = param[param.length - 1];
      if (typeof raw === 'number') {
        this.entityId = raw as number;
      } else if (typeof raw === 'string') {
        this.entityId = parseInt(raw as string) || 0;
      } else {
        const p = raw as CourseDetailParam;
        this.entityId = p.id;
        this.createTime = p.createTime ?? '';
        this.kind = p.kind === 'paper' ? 'paper' : 'course';
      }
    }
    if (this.entityId > 0) {
      this.loadContent();
    }
  }

  private async loadContent(): Promise<void> {
    this.loading = true;
    this.error = '';
    const api = this.kind === 'paper' ? StudyApi.paper : StudyApi.course;

    try {
      const results = await Promise.all([
        api.content(this.entityId),
        api.answers(this.entityId),
        api.entityInfo(this.entityId)
      ]);
      this.blocks = results[0] as CourseBlock[];
      this.answers = results[1] as AnswerRecord[];
      this.entityInfo = results[2] as CourseEntityInfo;

      // build title anchors from text blocks with titleLevel > 0
      const anchors: TitleAnchor[] = [];
      for (let i = 0; i < this.blocks.length; i++) {
        const b = this.blocks[i];
        if (b.contentType === 0 && b.text !== null && b.text.titleLevel > 0) {
          const htmlContent = b.text.textContent || '';
          const plainText = htmlContent.replace(/<[^>]*>/g, '').trim();
          if (plainText.length > 0) {
            anchors.push({ level: b.text.titleLevel, text: plainText, index: i });
          }
        }
      }
      this.titleAnchors = anchors;

      // 是否含题目块（决定是否显示提交/补交栏，对照前端 questionCounts>0）
      let qCount = 0;
      for (let i = 0; i < this.blocks.length; i++) {
        if (this.blocks[i].contentType === 2) {
          qCount++;
        }
      }
      this.hasQuestions = qCount > 0;

      // eliminate reddot
      try {
        if (this.kind === 'course') {
          await ReddotApi.eliminateCourse(this.entityId);
        } else {
          await ReddotApi.eliminatePaper(this.entityId);
        }
      } catch (e) {
        // non-critical
      }

      // 提交态：以 mappingStatus 为准（对照前端 0===mappingStatus 显「提交」，1=== 显「补交」）。
      // 注意不要用 jobStatus——前端的提交栏/倒计时/统计全部以 mappingStatus 判定。
      if (this.entityInfo !== null) {
        this.submitted = this.entityInfo.mappingStatus === 1;

        // 仅未提交时跑自动提交倒计时
        if (!this.submitted && this.entityInfo.courseEndTime !== null) {
          this.startCountdown(this.entityInfo.courseEndTime, this.entityInfo.currTime);
        }
      }

      // load statistics in background
      this.loadStatistics(api);

      hilog.info(DOMAIN, TAG, 'loaded %{public}d blocks, %{public}d answers',
        this.blocks.length, this.answers.length);
    } catch (e) {
      const err = e as Error;
      this.error = err.message || '加载失败';
      hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', err.message);
    } finally {
      this.loading = false;
    }
  }

  private async loadStatistics(api: StudyApi): Promise<void> {
    try {
      this.statistics = await api.statistics(this.entityId);
      // 从 statistics 里的明文 attachmentLinkAddress 建 id→url 映射
      if (this.statistics !== null && this.statistics.studentCourseAttachments !== null) {
        const atts = this.statistics.studentCourseAttachments;
        for (let i = 0; i < atts.length; i++) {
          const a = atts[i];
          if (a.attachmentLinkAddress.length > 0) {
            this.attUrlMap.set(a.id, a.attachmentLinkAddress);
          }
        }
      }
    } catch (e) {
      // non-critical
    }
  }

  private startCountdown(endTime: string, serverNow: string): void {
    try {
      const end = new Date(endTime).getTime();
      const now = new Date(serverNow).getTime();
      let remaining = Math.floor((end - now) / 1000);
      if (remaining <= 0) {
        return;
      }
      this.countdownSec = remaining;
      this.countdownTimer = setInterval(() => {
        this.countdownSec--;
        if (this.countdownSec <= 0) {
          clearInterval(this.countdownTimer);
          this.countdownTimer = -1;
          this.autoSubmit();
        }
      }, 1000) as number;
    } catch (e) {
      // date parse error — skip countdown
    }
  }

  aboutToDisappear(): void {
    if (this.countdownTimer >= 0) {
      clearInterval(this.countdownTimer);
    }
  }

  private formatCountdown(sec: number): string {
    const h = Math.floor(sec / 3600);
    const m = Math.floor((sec % 3600) / 60);
    const s = sec % 60;
    if (h > 0) {
      return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    }
    return `${m}:${s.toString().padStart(2, '0')}`;
  }

  private async doSubmit(): Promise<void> {
    this.submitting = true;
    try {
      const api = this.kind === 'paper' ? StudyApi.paper : StudyApi.course;
      await api.submit(this.entityId);
      if (this.countdownTimer >= 0) {
        clearInterval(this.countdownTimer);
        this.countdownTimer = -1;
      }
      // 重拉实体信息/作答/统计：mappingStatus 翻 1 后按钮自动变「补交」
      await this.refreshState();
      hilog.info(DOMAIN, TAG, 'submitted entity %{public}d', this.entityId);
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'submit failed: %{public}s', err.message);
    } finally {
      this.submitting = false;
    }
  }

  private async doResubmit(): Promise<void> {
    this.submitting = true;
    try {
      const api = this.kind === 'paper' ? StudyApi.paper : StudyApi.course;
      // courseBeginTime 取列表项 createTime；缺失时退回 entityInfo.courseBeginTime
      let beginTime = this.createTime;
      if (beginTime.length === 0 && this.entityInfo !== null
        && this.entityInfo.courseBeginTime !== null) {
        beginTime = this.entityInfo.courseBeginTime;
      }
      await api.resubmit(this.entityId, beginTime);
      // 补交后 mappingStatus 仍为 1，按钮保持「补交」——可多次补交
      await this.refreshState();
      hilog.info(DOMAIN, TAG, 'resubmitted entity %{public}d', this.entityId);
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'resubmit failed: %{public}s', err.message);
    } finally {
      this.submitting = false;
    }
  }

  // 提交/补交后刷新：重拉 entityInfo + answers，并按 mappingStatus 重算提交态。
  private async refreshState(): Promise<void> {
    const api = this.kind === 'paper' ? StudyApi.paper : StudyApi.course;
    try {
      const results = await Promise.all([
        api.entityInfo(this.entityId),
        api.answers(this.entityId)
      ]);
      this.entityInfo = results[0] as CourseEntityInfo;
      this.answers = results[1] as AnswerRecord[];
      this.pendingAnswers = new Map<number, string>();
      this.submitted = this.entityInfo.mappingStatus === 1;
      this.loadStatistics(api);
    } catch (e) {
      const err = e as Error;
      hilog.warn(DOMAIN, TAG, 'refreshState failed: %{public}s', err.message);
    }
  }

  private autoSubmit(): void {
    hilog.info(DOMAIN, TAG, 'auto-submit triggered for entity %{public}d', this.entityId);
    this.doSubmit();
  }

  // 收集本页所有可快捷作答的选择题（含复合题的叶子子题），对照油猴脚本捕获逻辑。
  private buildQuickSubmitItems(): QuickSubmitItem[] {
    const items: QuickSubmitItem[] = [];
    for (let i = 0; i < this.blocks.length; i++) {
      const b = this.blocks[i];
      if (b.contentType !== 2 || b.question === null) {
        continue;
      }
      const q = b.question;
      if (q.childList !== null && q.childList.length > 0) {
        for (let c = 0; c < q.childList.length; c++) {
          const child = q.childList[c];
          if (child.answerCard !== null && child.answerCard.length > 0) {
            items.push({
              questionId: child.id,
              qNum: child.questionNumber,
              correctAnswer: child.answer ?? '',
              studentAnswer: this.getStudentAnswer(child.id)
            });
          }
        }
      } else if (q.answerCard !== null && q.answerCard.length > 0) {
        items.push({
          questionId: q.id,
          qNum: q.questionNumber,
          correctAnswer: q.answer ?? '',
          studentAnswer: this.getStudentAnswer(q.id)
        });
      }
    }
    return items;
  }

  private openQuickSubmit(): void {
    this.quickItems = this.buildQuickSubmitItems();
    this.showQuickSubmit = true;
  }

  // 快捷提交：把各段答案保存到对应题后，触发整卷提交/补交
  // （对照脚本：逐题 POST /question 后点「手动提交」按钮）。
  private async runQuickSubmit(fills: QuickSubmitFill[]): Promise<void> {
    if (this.quickSubmitting) {
      return;
    }
    this.quickSubmitting = true;
    const api = this.kind === 'paper' ? StudyApi.paper : StudyApi.course;
    // resubmitTag = mappingStatus===1 ? 1 : 0（与单题保存一致；脚本恒为 1 但以后端契约为准）
    const resubmitTag = (this.entityInfo !== null && this.entityInfo.mappingStatus === 1) ? 1 : 0;
    try {
      for (let i = 0; i < fills.length; i++) {
        try {
          await api.saveAnswer(this.entityId, fills[i].questionId, fills[i].studentAnswer, resubmitTag);
        } catch (e) {
          const err = e as Error;
          hilog.error(DOMAIN, TAG, 'quick save q%{public}d failed: %{public}s',
            fills[i].questionId, err.message);
        }
      }
      // 触发整卷提交/补交（doSubmit/doResubmit 内部会 refreshState 重拉真值）
      if (this.submitted) {
        await this.doResubmit();
      } else {
        await this.doSubmit();
      }
    } finally {
      this.quickSubmitting = false;
      this.showQuickSubmit = false;
    }
  }

  private findAnswer(questionId: number): AnswerRecord | null {
    for (let i = 0; i < this.answers.length; i++) {
      if (this.answers[i].questionId === questionId) {
        return this.answers[i];
      }
    }
    return null;
  }

  @Builder
  toolbarBuilder() {
    Row({ space: 12 }) {
      // Title navigation toggle
      if (this.titleAnchors.length > 0) {
        SymbolGlyph($r('sys.symbol.list_bullet'))
          .fontSize(22)
          .fontColor([this.showTitleNav ? Theme.PRIMARY : Theme.TEXT_2])
          .onClick(() => {
            this.showTitleNav = !this.showTitleNav;
          })
      }

      // Answer visibility toggle (gated by enableAnswerForce)
      if (this.settings.enableAnswerForce) {
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.eye'))
            .fontSize(18)
            .fontColor([this.showAnswers ? Theme.PRIMARY : Theme.TEXT_2])
          Text(this.showAnswers ? '隐藏答案' : '显示答案')
            .fontSize(Theme.F_SUB)
            .fontColor(this.showAnswers ? Theme.PRIMARY : Theme.TEXT_2)
        }
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .borderRadius(Theme.R_XL)
        .backgroundColor(this.showAnswers ? Theme.PRIMARY_SOFT : '#F0F2F5')
        .onClick(() => {
          this.showAnswers = !this.showAnswers;
        })
      }

      Blank().layoutWeight(1)

      // Stats summary
      if (this.entityInfo !== null && this.entityInfo.scoringRate !== null) {
        Text(`得分率 ${this.entityInfo.scoringRate}`)
          .fontSize(Theme.F_SUB)
          .fontColor(Theme.SUCCESS)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor('#1452C41A')
          .borderRadius(Theme.R_XL)
      }
    }
    .width('100%')
    .height(42)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  titleNavPanel() {
    Column() {
    GlassCard({ innerPadding: 12 }) {
      Column({ space: 2 }) {
        Text('标题跳转')
          .fontSize(Theme.F_SUB)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_2)
          .padding({ bottom: 6 })

        ForEach(this.titleAnchors, (a: TitleAnchor, idx: number) => {
          Text(a.text)
            .fontSize(a.level === 1 ? Theme.F_BODY : Theme.F_SUB)
            .fontWeight(a.level === 1 ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(Theme.PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .padding({
              left: a.level > 1 ? 16 : 4,
              top: 6, bottom: 6
            })
            .onClick(() => {
              // 偏移量：statistics card + submit bar 在 List 顶部占了额外 ListItem
              const offset = (this.statistics !== null ? 1 : 0) + (this.hasQuestions ? 1 : 0);
              this.scroller.scrollToIndex(a.index + offset);
              this.showTitleNav = false;
            })
        }, (a: TitleAnchor, idx: number) => `anchor_${idx}`)
      }
      .width('100%')
    }
    }
    .width('100%')
    .margin({ left: 16, right: 16, bottom: 8 })
  }

  @Builder
  textBlock(block: CourseBlock) {
    if (block.text !== null) {
      HtmlRichText({ html: block.text.textContent })
        .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    }
  }

  @Builder
  attachmentBlock(att: AttachmentEntity) {
    Column() {
    GlassCard({ innerPadding: 14 }) {
      Row({ space: 12 }) {
        SymbolGlyph(this.attachmentIcon(att))
          .fontSize(28)
          .fontColor([Theme.PRIMARY])

        Column({ space: 3 }) {
          Text(att.attachmentName)
            .fontSize(Theme.F_BODY)
            .fontColor(Theme.TEXT)
            .fontWeight(FontWeight.Medium)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: 8 }) {
            Text(att.attachmentExtraName.toUpperCase())
              .fontSize(Theme.F_MINI)
              .fontColor(Theme.TEXT_3)
            if (att.attachmentSize) {
              Text(att.attachmentSize)
                .fontSize(Theme.F_MINI)
                .fontColor(Theme.TEXT_3)
            }
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(18)
          .fontColor([Theme.TEXT_3])
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    }
    .width('100%')
    .margin({ left: 16, right: 16, top: 4, bottom: 4 })
    .onClick(() => {
      this.openAttachment(att);
    })
  }

  private resolveAttUrl(att: AttachmentEntity): string {
    const plain = this.attUrlMap.get(att.id);
    if (plain !== undefined && plain.length > 0) {
      return plain;
    }
    // statistics 尚未加载完或无此附件——回退 content 的原始值（可能是加密串）
    return att.attachmentLinkAddress;
  }

  private openAttachment(att: AttachmentEntity): void {
    const url = this.resolveAttUrl(att);
    if (url.length === 0) {
      return;
    }
    const param: AttachmentViewerParam = {
      name: att.attachmentName,
      url: url,
      ext: att.attachmentExtraName
    };
    Nav.push('attachmentViewer', param as object);
  }

  private async downloadAttachment(att: AttachmentEntity): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const url = this.resolveAttUrl(att);
      const ok = await Downloader.download(ctx, url, att.attachmentName);
      hilog.info(DOMAIN, TAG, 'download %{public}s: %{public}s',
        att.attachmentName, ok ? 'ok' : 'failed');
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'download error: %{public}s', err.message);
    }
  }

  private attachmentIcon(att: AttachmentEntity): Resource {
    const ext = att.attachmentExtraName.toLowerCase();
    if (ext === '.pdf') {
      return $r('sys.symbol.doc_plaintext');
    }
    if (ext === '.mp4' || ext === '.mov' || ext === '.avi') {
      return $r('sys.symbol.play_circle');
    }
    if (ext === '.png' || ext === '.jpg' || ext === '.jpeg' || ext === '.gif') {
      return $r('sys.symbol.picture');
    }
    return $r('sys.symbol.paperclip');
  }

  @Builder
  questionBlock(q: QuestionContent, blockIdx: number) {
    Column() {
    GlassCard({ innerPadding: 16 }) {
      Column({ space: 10 }) {
        // Question header: number + score + type
        Row({ space: 8 }) {
          Text(q.questionNumber)
            .fontSize(Theme.F_BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
          Text(`(${q.questionScore}分)`)
            .fontSize(Theme.F_SUB)
            .fontColor(Theme.TEXT_2)
          Blank().layoutWeight(1)
          Text(this.questionTypeName(q.questionType))
            .fontSize(Theme.F_MINI)
            .fontColor(Theme.PRIMARY)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor(Theme.PRIMARY_SOFT)
            .borderRadius(Theme.R_SM)
        }
        .width('100%')

        // Question stem
        HtmlRichText({ html: q.questionStem })

        // Choice options (for single/multiple choice)
        if (q.answerCard !== null && q.answerCard.length > 0) {
          this.choiceOptions(q)
        }

        // Child questions (composite)
        if (q.childList !== null && q.childList.length > 0) {
          ForEach(q.childList, (child: QuestionContent, ci: number) => {
            Column({ space: 8 }) {
              Text(`(${ci + 1})`)
                .fontSize(Theme.F_SUB)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT)
              HtmlRichText({ html: child.questionStem })

              if (child.answerCard !== null && child.answerCard.length > 0) {
                this.choiceOptions(child)
              }

              this.answerArea(child)
            }
            .width('100%')
            .padding({ top: 8 })
          }, (child: QuestionContent, ci: number) => `child_${q.id}_${ci}`)
        }

        // Answer area for the main question (if no children)
        if (q.childList === null || q.childList.length === 0) {
          this.answerArea(q)
        }

        // Show standard answer if enabled
        if (this.showAnswers && q.answer !== null && q.answer.length > 0) {
          Column({ space: 4 }) {
            Divider().color(Theme.DIVIDER)
            Row({ space: 6 }) {
              Text('参考答案')
                .fontSize(Theme.F_SUB)
                .fontWeight(FontWeight.Medium)
                .fontColor(Theme.SUCCESS)
              Text(q.answer)
                .fontSize(Theme.F_BODY)
                .fontColor(Theme.TEXT)
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ top: 6 })
          }
          .width('100%')
        }

        // Analysis
        if (this.showAnswers && q.questionAnalysis !== null && q.questionAnalysis.length > 0) {
          Column({ space: 4 }) {
            Text('解 析')
              .fontSize(Theme.F_SUB)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.WARN)
            HtmlRichText({ html: q.questionAnalysis })
          }
          .width('100%')
          .padding({ top: 4 })
        }
      }
      .width('100%')
    }
    }
    .width('100%')
    .margin({ left: 16, right: 16, top: 4, bottom: 4 })
  }

  @Builder
  choiceOptions(q: QuestionContent) {
    Column({ space: 6 }) {
      ForEach((q.answerCard ?? '').split(','), (opt: string) => {
        if (opt.trim().length > 0) {
          Row({ space: 10 }) {
            Text(opt.trim())
              .fontSize(Theme.F_BODY)
              .fontColor(this.optionTextColor(this.getOptionState(q, opt.trim())))
              .fontWeight(FontWeight.Medium)
              .width(32)
              .height(32)
              .textAlign(TextAlign.Center)
              .borderRadius(16)
              .backgroundColor(this.optionBgColor(this.getOptionState(q, opt.trim())))
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
          .onClick(() => {
            this.selectOption(q, opt.trim());
          })
        }
      }, (opt: string) => `opt_${q.id}_${opt}`)
    }
    .width('100%')
  }

  private isOptionSelected(q: QuestionContent, opt: string): boolean {
    const ans = this.currentAnswer(q.id);
    if (ans.length === 0) {
      return false;
    }
    // studentAnswer 为逗号分隔（单选 "A"，多选 "A,B"）——按项精确匹配，避免子串误判
    const parts = ans.split(',');
    for (let i = 0; i < parts.length; i++) {
      if (parts[i].trim() === opt) {
        return true;
      }
    }
    return false;
  }

  // 当前作答：优先读乐观覆盖层（点击即时反馈），否则读服务端记录。
  private currentAnswer(questionId: number): string {
    if (this.pendingAnswers.has(questionId)) {
      const v = this.pendingAnswers.get(questionId);
      return v !== undefined ? v : '';
    }
    const rec = this.findAnswer(questionId);
    return (rec !== null && rec.studentAnswer !== null) ? rec.studentAnswer : '';
  }

  private async selectOption(q: QuestionContent, opt: string): Promise<void> {
    const current = this.currentAnswer(q.id);

    let newAnswer: string;
    if (q.questionType === 1) {
      // 多选：维护一个排序后的选项集合，逗号拼接（对照前端 answerArr.sort().toString()）
      const parts: string[] = current.length > 0
        ? current.split(',').map((s: string) => s.trim()).filter((s: string) => s.length > 0)
        : [];
      const idx = parts.indexOf(opt);
      if (idx >= 0) {
        parts.splice(idx, 1);
      } else {
        parts.push(opt);
      }
      parts.sort();
      newAnswer = parts.join(',');
    } else {
      // 单选/判断：直接取该选项
      newAnswer = opt;
    }

    // 1) 乐观更新：先写覆盖层，UI 立刻高亮（不依赖后端往返）
    this.pendingAnswers.set(q.id, newAnswer);
    this.pendingAnswers = new Map<number, string>(this.pendingAnswers);

    // 2) 保存：body 必带 resubmitTag/abandonTag，否则后端 10000「请求参数错误！」
    //    resubmitTag = mappingStatus===1 ? 1 : 0（编辑批阅/补交阶段答案）
    const resubmitTag = (this.entityInfo !== null && this.entityInfo.mappingStatus === 1) ? 1 : 0;
    const api = this.kind === 'paper' ? StudyApi.paper : StudyApi.course;
    try {
      await api.saveAnswer(this.entityId, q.id, newAnswer, resubmitTag);
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'saveAnswer failed: %{public}s', err.message);
    }
    // 3) 重拉服务端真值（含判分），再清除覆盖层——成功则高亮保留，失败则回退
    try {
      this.answers = await api.answers(this.entityId);
    } catch (e) {
      const err = e as Error;
      hilog.warn(DOMAIN, TAG, 'reload answers failed: %{public}s', err.message);
    }
    this.pendingAnswers.delete(q.id);
    this.pendingAnswers = new Map<number, string>(this.pendingAnswers);
  }

  @Builder
  answerArea(q: QuestionContent) {
    if (q.answerCard === null || q.answerCard.length === 0) {
      Column({ space: 6 }) {
        Divider().color(Theme.DIVIDER)

        ForEach(this.getAnswerAttachments(q.id), (att: AttachmentEntity) => {
          Image(ApiClient.assetUrl(att.attachmentLinkAddress))
            .width('100%')
            .objectFit(ImageFit.Contain)
            .borderRadius(Theme.R_SM)
            .colorFilter(this.settings.enableImageInvert
              ? [-1, 0, 0, 0, 1, 0, -1, 0, 0, 1, 0, 0, -1, 0, 1, 0, 0, 0, 1, 0]
              : undefined)
        }, (att: AttachmentEntity) => `ans_att_${att.id}`)

        if (this.getStudentAnswer(q.id).length > 0) {
          Text(this.getStudentAnswer(q.id))
            .fontSize(Theme.F_BODY)
            .fontColor(Theme.TEXT)
            .width('100%')
            .padding(8)
            .backgroundColor('#F0F2F5')
            .borderRadius(Theme.R_SM)
        }

        if (q.answerWayPhoto > 0 || q.answerWayHandle > 0) {
          Row({ space: 8 }) {
            // 拍照上传：调用系统相机
            SquishButton({
              onTap: () => {
                this.capturePhoto(q.id);
              }
            }) {
              Row({ space: 6 }) {
                if (this.capturingQuestionId === q.id) {
                  LoadingProgress().width(16).height(16).color(Theme.PRIMARY)
                } else {
                  SymbolGlyph($r('sys.symbol.camera'))
                    .fontSize(18)
                    .fontColor([Theme.PRIMARY])
                }
                Text(this.capturingQuestionId === q.id ? '上传中...' : '拍照上传')
                  .fontSize(Theme.F_SUB)
                  .fontColor(Theme.PRIMARY)
              }
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor(Theme.PRIMARY_SOFT)
              .borderRadius(Theme.R_XL)
            }

            // 手写作答：打开画布
            SquishButton({
              onTap: () => {
                this.handwriteQuestionId = q.id;
                this.handwriteStem = q.questionStem;
              }
            }) {
              Row({ space: 6 }) {
                SymbolGlyph($r('sys.symbol.card_writer'))
                  .fontSize(18)
                  .fontColor([Theme.WARN])
                Text('手写作答')
                  .fontSize(Theme.F_SUB)
                  .fontColor(Theme.WARN)
              }
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor('#1AFAAD14')
              .borderRadius(Theme.R_XL)
            }
          }
          .width('100%')
        }

        if (this.getJudgeTag(q.id) >= 0) {
          Row({ space: 6 }) {
            SymbolGlyph(this.getJudgeTag(q.id) === 1
              ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.xmark_circle'))
              .fontSize(18)
              .fontColor([this.getJudgeTag(q.id) === 1 ? Theme.SUCCESS : Theme.DANGER])
            Text(this.getJudgeTag(q.id) === 1 ? '正确'
              : (this.getJudgeTag(q.id) === 2 ? '部分正确' : '错误'))
              .fontSize(Theme.F_SUB)
              .fontColor(this.getJudgeTag(q.id) === 1 ? Theme.SUCCESS : Theme.DANGER)
            if (this.getStudentScore(q.id) >= 0) {
              Text(`${this.getStudentScore(q.id)}/${q.questionScore}分`)
                .fontSize(Theme.F_SUB)
                .fontColor(Theme.TEXT_2)
            }
          }
        }
      }
      .width('100%')
    }
  }

  private async uploadPhoto(questionId: number): Promise<void> {
    if (this.uploadingQuestionId > 0) {
      return;
    }
    this.uploadingQuestionId = questionId;
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const result = await PhotoUploader.pickAndUpload(ctx, this.entityId, questionId, this.kind);
      if (result !== null) {
        const api = this.kind === 'paper' ? StudyApi.paper : StudyApi.course;
        this.answers = await api.answers(this.entityId);
      }
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'uploadPhoto failed: %{public}s', err.message);
    } finally {
      this.uploadingQuestionId = 0;
    }
  }

  private async capturePhoto(questionId: number): Promise<void> {
    if (this.capturingQuestionId > 0) {
      return;
    }
    this.capturingQuestionId = questionId;
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const result = await PhotoUploader.captureAndUpload(ctx, this.entityId, questionId, this.kind);
      if (result !== null) {
        const api = this.kind === 'paper' ? StudyApi.paper : StudyApi.course;
        this.answers = await api.answers(this.entityId);
      }
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'capturePhoto failed: %{public}s', err.message);
    } finally {
      this.capturingQuestionId = 0;
    }
  }

  // 选项状态：仅对「已作答且已判分」的题目按正确答案着色。
  // 未提交作答的题目（无作答记录 / studentAnswer 为空）一律不揭示正确答案（不显示绿色）。
  // 返回: 'default' | 'selected' | 'correct' | 'wrong'
  private getOptionState(q: QuestionContent, opt: string): string {
    const selected = this.isOptionSelected(q, opt);
    if (!this.submitted) {
      return selected ? 'selected' : 'default';
    }
    const rec = this.findAnswer(q.id);
    // 学生未作答此题 → 不揭示正确选项（即便整卷已提交，空白题也不标绿）。
    const studentAns = (rec !== null && rec.studentAnswer !== null) ? rec.studentAnswer.trim() : '';
    if (rec === null || studentAns.length === 0 || rec.judgeTag === null || rec.judgeTag < 0) {
      return selected ? 'selected' : 'default';
    }
    const correctRaw = q.answer ?? '';
    const correctParts = correctRaw.split(',').map((s: string) => s.trim()).filter((s: string) => s.length > 0);
    let isCorrectOpt = false;
    for (let i = 0; i < correctParts.length; i++) {
      if (correctParts[i] === opt) {
        isCorrectOpt = true;
        break;
      }
    }
    if (isCorrectOpt) {
      return 'correct';
    }
    if (selected && !isCorrectOpt) {
      return 'wrong';
    }
    return 'default';
  }

  private optionBgColor(state: string): ResourceColor {
    if (state === 'correct') {
      return Theme.SUCCESS;
    }
    if (state === 'wrong') {
      return Theme.DANGER;
    }
    if (state === 'selected') {
      return Theme.PRIMARY;
    }
    return '#F0F2F5';
  }

  private optionTextColor(state: string): ResourceColor {
    if (state === 'default') {
      return Theme.TEXT;
    }
    return Color.White;
  }

  private getAnswerAttachments(questionId: number): AttachmentEntity[] {
    const rec = this.findAnswer(questionId);
    if (rec === null || rec.attachments === null) {
      return [];
    }
    return rec.attachments;
  }

  private getStudentAnswer(questionId: number): string {
    const rec = this.findAnswer(questionId);
    if (rec === null || rec.studentAnswer === null) {
      return '';
    }
    return rec.studentAnswer;
  }

  private getJudgeTag(questionId: number): number {
    const rec = this.findAnswer(questionId);
    if (rec === null || rec.judgeTag === null) {
      return -1;
    }
    return rec.judgeTag;
  }

  private getStudentScore(questionId: number): number {
    const rec = this.findAnswer(questionId);
    if (rec === null || rec.studentScore === null) {
      return -1;
    }
    return rec.studentScore;
  }

  private questionTypeName(qt: number): string {
    if (qt === 0) {
      return '单选';
    }
    if (qt === 1) {
      return '多选';
    }
    if (qt === 2) {
      return '判断';
    }
    if (qt === 3) {
      return '填空';
    }
    return '解答';
  }

  @Builder
  statisticsCard() {
    if (this.statistics !== null) {
      Column() {
      GlassCard({ innerPadding: 16 }) {
        Column({ space: 10 }) {
          Text('统计概览')
            .fontSize(Theme.F_BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)

          Row({ space: 20 }) {
            this.statItem('我的得分率', this.statistics!.scoringRate ?? '-')
            this.statItem('最高得分率', this.statistics!.scoringRateMax ?? '-')
            this.statItem('平均得分率', this.statistics!.scoringRateAvg ?? '-')
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceEvenly)

          if (this.entityInfo !== null && this.entityInfo.courseTime > 0) {
            Text(`累计用时 ${this.entityInfo.courseTime} 分钟`)
              .fontSize(Theme.F_SUB)
              .fontColor(Theme.TEXT_2)
          }
        }
        .width('100%')
      }
      }
      .width('100%')
      .margin({ left: 16, right: 16, top: 8, bottom: 8 })
    }
  }

  @Builder
  statItem(label: string, value: string) {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.PRIMARY)
      Text(label)
        .fontSize(Theme.F_MINI)
        .fontColor(Theme.TEXT_2)
    }
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          // 标题栏：沉浸光感材质
          Column() {
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.chevron_left'))
                .fontSize(24)
                .fontColor([Theme.TEXT])
                .onClick(() => {
                  Nav.pop();
                })
              Text(this.kind === 'paper' ? '考试详情' : '课件详情')
                .fontSize(Theme.F_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT)
                .layoutWeight(1)
            }
            .width('100%')
            .height(50)
            .padding({ left: 16, right: 16, top: this.ui.topSafeVp })
            .alignItems(VerticalAlign.Center)

            // 快捷操作栏
            if (!this.loading && this.error.length === 0) {
              Row({ space: 10 }) {
                if (this.hasQuestions) {
                  SquishButton({
                    onTap: () => {
                      this.openQuickSubmit();
                    }
                  }) {
                    Row({ space: 6 }) {
                      SymbolGlyph($r('sys.symbol.share'))
                        .fontSize(16)
                        .fontColor([Color.White])
                      Text(this.submitted ? '快捷补交' : '快捷提交')
                        .fontSize(Theme.F_SUB)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Color.White)
                    }
                    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                    .backgroundColor(this.submitted ? Theme.WARN : Theme.PRIMARY)
                    .borderRadius(Theme.R_XL)
                  }
                }

                SquishButton({
                  onTap: () => {
                    this.showAnnotation = true;
                  }
                }) {
                  Row({ space: 6 }) {
                    SymbolGlyph($r('sys.symbol.card_writer'))
                      .fontSize(16)
                      .fontColor([Theme.TEXT])
                    Text('批注')
                      .fontSize(Theme.F_SUB)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Theme.TEXT)
                  }
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .backgroundColor('#F0F2F5')
                  .borderRadius(Theme.R_XL)
                }

                Blank().layoutWeight(1)

                if (!this.submitted && this.countdownSec > 0) {
                  Text(`${this.formatCountdown(this.countdownSec)}`)
                    .fontSize(Theme.F_SUB)
                    .fontColor(this.countdownSec < 300 ? Theme.DANGER : Theme.TEXT_2)
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 8 })
            }
          }
          .width('100%')
          .backgroundColor('#E8FAF6EC')
          .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
          .border({ width: { bottom: 1 }, color: '#14000000' })

          if (this.loading) {
            LoadingView()
              .layoutWeight(1)
          } else if (this.error.length > 0) {
            EmptyView({ text: this.error })
              .layoutWeight(1)
          } else {
            Column() {
              this.toolbarBuilder()
              if (this.showTitleNav) {
                this.titleNavPanel()
              }

              List({ scroller: this.scroller, space: 4 }) {
                // 统计概览：随内容自然滚动
                if (this.statistics !== null) {
                  ListItem() {
                    this.statisticsCard()
                  }
                }

                // 提交/补交栏
                if (this.hasQuestions) {
                  ListItem() {
                    Row({ space: 12 }) {
                      if (!this.submitted && this.countdownSec > 0) {
                        Text(`剩余 ${this.formatCountdown(this.countdownSec)}`)
                          .fontSize(Theme.F_SUB)
                          .fontColor(this.countdownSec < 300 ? Theme.DANGER : Theme.TEXT_2)
                      }
                      Blank().layoutWeight(1)
                      SquishButton({
                        onTap: () => {
                          if (!this.submitting) {
                            if (this.submitted) {
                              this.doResubmit();
                            } else {
                              this.doSubmit();
                            }
                          }
                        }
                      }) {
                        Row({ space: 6 }) {
                          if (this.submitting) {
                            LoadingProgress().width(18).height(18).color(Color.White)
                          }
                          Text(this.submitting ? '提交中...'
                            : (this.submitted ? '补 交' : '提 交'))
                            .fontSize(Theme.F_BODY)
                            .fontWeight(FontWeight.Medium)
                            .fontColor(Color.White)
                        }
                        .padding({ left: 24, right: 24, top: 8, bottom: 8 })
                        .backgroundColor(this.submitted ? Theme.WARN : Theme.PRIMARY)
                        .borderRadius(Theme.R_XL)
                      }
                    }
                    .width('100%')
                    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
                  }
                }

                // 内容块
                ForEach(this.blocks, (block: CourseBlock, idx: number) => {
                  ListItem() {
                    if (block.contentType === 0 && block.text !== null) {
                      this.textBlock(block)
                    } else if (block.contentType === 1 && block.attachment !== null) {
                      this.attachmentBlock(block.attachment)
                    } else if (block.contentType === 2 && block.question !== null) {
                      this.questionBlock(block.question, idx)
                    }
                  }
                }, (block: CourseBlock, idx: number) => `block_${idx}`)
              }
              .width('100%')
              .layoutWeight(1)
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .padding({ bottom: 80 })
            }
            .width('100%')
            .layoutWeight(1)
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Theme.BG_CREAM)

        // 批注覆盖层
        if (this.showAnnotation) {
          HandwritePanel({
            mode: 'annotation',
            onClose: () => {
              this.showAnnotation = false;
            }
          })
        }

        // 手写作答覆盖层
        if (this.handwriteQuestionId > 0) {
          HandwritePanel({
            mode: 'answer',
            questionStem: this.handwriteStem,
            entityId: this.entityId,
            questionId: this.handwriteQuestionId,
            kind: this.kind,
            onClose: () => {
              this.handwriteQuestionId = 0;
              this.handwriteStem = '';
            },
            onSubmitted: () => {
              const api = this.kind === 'paper' ? StudyApi.paper : StudyApi.course;
              api.answers(this.entityId).then((ans: AnswerRecord[]) => {
                this.answers = ans;
              });
            }
          })
        }

        // 快捷提交弹窗
        if (this.showQuickSubmit) {
          QuickSubmitSheet({
            items: this.quickItems,
            allowCheck: this.settings.enableAnswerForce && this.kind === 'course',
            submitting: this.quickSubmitting,
            onClose: () => {
              if (!this.quickSubmitting) {
                this.showQuickSubmit = false;
              }
            },
            onSubmit: (fills: QuickSubmitFill[]) => {
              this.runQuickSubmit(fills);
            }
          })
        }
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      if (this.showQuickSubmit) {
        if (!this.quickSubmitting) {
          this.showQuickSubmit = false;
        }
        return true;
      }
      if (this.showAnnotation) {
        this.showAnnotation = false;
        return true;
      }
      if (this.handwriteQuestionId > 0) {
        this.handwriteQuestionId = 0;
        return true;
      }
      Nav.pop();
      return true;
    })
  }
}
