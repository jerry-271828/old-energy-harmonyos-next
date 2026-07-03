// AI 页面：对齐官方网页端 /ai?pageid=2。
// 结构：学科对比 / 教师列表 + 每日最佳回顾、错题、知识模块。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../theme/Theme';
import { UiStore } from '../store/UiStore';
import { GlassCard, EmptyView, LoadingView, SquishButton } from '../components/glass/GlassKit';
import { HtmlRichText } from '../components/HtmlRichText';
import { ApiClient } from '../net/ApiClient';
import { AiApi, AiTeacher, AiOverviewItem, AiWrongQuestionOverview, AiWrongQuestion,
  AiKnowledgeLibOverview, AiKnowledgeLibItem, AiReformBody } from '../net/api/AiApi';

const DOMAIN = 0x0002;
const TAG = 'AiPage';

const TAB_LOOKBACK = 2;
const TAB_WRONG = 0;
const TAB_LIB = 1;

@ComponentV2
export struct AiPage {
  ui: UiStore = UiStore.instance;

  @Local private teachers: AiTeacher[] = [];
  @Local private selectedIdx: number = 0; // 0=学科对比，其他=teachers 下标 + 1
  @Local private tab: number = TAB_LOOKBACK;
  @Local private lookBackTime: number = 15;

  @Local private loadingTeachers: boolean = true;
  @Local private loadingContent: boolean = false;
  @Local private errorText: string = '';

  @Local private overviewItems: AiOverviewItem[] = [];
  @Local private wrongOverview: AiWrongQuestionOverview | null = null;
  @Local private wrongQuestions: AiWrongQuestion[] = [];
  @Local private knowledgeOverview: AiKnowledgeLibOverview | null = null;
  @Local private knowledgeItems: AiKnowledgeLibItem[] = [];
  @Local private selectedQuestionId: number = 0;
  @Local private selectedLibId: number = 0;
  @Local private libQuestions: AiWrongQuestion[] = [];
  @Local private loadingLibQuestions: boolean = false;
  @Local private reformingId: number = 0;

  aboutToAppear(): void {
    this.loadTeachers();
  }

  private async loadTeachers(): Promise<void> {
    this.loadingTeachers = true;
    this.errorText = '';
    try {
      const list = await AiApi.teachers();
      list.forEach((teacher: AiTeacher) => {
        if (teacher.lookBackTime === undefined || teacher.lookBackTime <= 0) {
          teacher.lookBackTime = this.lookBackTime;
        }
      });
      this.teachers = list;
      this.selectedIdx = 0;
      await this.loadCurrentContent();
      hilog.info(DOMAIN, TAG, 'ai teachers loaded: %{public}d', list.length);
    } catch (e) {
      const err = e as Error;
      this.errorText = err.message || 'AI 数据加载失败';
      hilog.error(DOMAIN, TAG, 'loadTeachers failed: %{public}s', this.errorText);
    } finally {
      this.loadingTeachers = false;
    }
  }

  private currentTeacher(): AiTeacher | null {
    if (this.selectedIdx <= 0 || this.selectedIdx > this.teachers.length) {
      return null;
    }
    return this.teachers[this.selectedIdx - 1];
  }

  private currentTitle(): string {
    const t = this.currentTeacher();
    if (t === null) {
      return '学科对比';
    }
    return `${t.userName} (${t.subjectName})`;
  }

  private currentSubjectName(): string {
    const t = this.currentTeacher();
    return t === null ? '--' : t.subjectName;
  }

  private currentSubjectColor(): ResourceColor {
    const t = this.currentTeacher();
    return t === null ? Theme.TEXT : this.subjectColor(t.subjectName);
  }

  private async selectTeacher(idx: number): Promise<void> {
    if (this.selectedIdx === idx && this.errorText.length === 0) {
      return;
    }
    this.selectedIdx = idx;
    this.selectedQuestionId = 0;
    this.selectedLibId = 0;
    this.libQuestions = [];
    await this.loadCurrentContent();
  }

  private async selectTab(tab: number): Promise<void> {
    if (this.tab === tab && this.errorText.length === 0) {
      return;
    }
    this.tab = tab;
    this.selectedQuestionId = 0;
    this.selectedLibId = 0;
    this.libQuestions = [];
    await this.loadCurrentContent();
  }

  private async loadCurrentContent(): Promise<void> {
    this.loadingContent = true;
    this.errorText = '';
    this.overviewItems = [];
    this.wrongOverview = null;
    this.wrongQuestions = [];
    this.knowledgeOverview = null;
    this.knowledgeItems = [];
    try {
      const teacher = this.currentTeacher();
      if (teacher === null) {
        await this.loadOverview();
      } else if (this.tab === TAB_LIB) {
        await this.loadKnowledge(teacher.id);
      } else {
        await this.loadWrong(teacher.id, this.tab === TAB_LOOKBACK ? this.lookBackTime : 0);
      }
    } catch (e) {
      const err = e as Error;
      this.errorText = err.message || 'AI 数据加载失败';
      hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', this.errorText);
    } finally {
      this.loadingContent = false;
    }
  }

  private async loadOverview(): Promise<void> {
    if (this.tab === TAB_LIB) {
      this.overviewItems = await AiApi.libOverview();
      return;
    }
    if (this.tab === TAB_WRONG) {
      this.overviewItems = await AiApi.overview();
      return;
    }
    const payload: AiTeacher[] = [];
    for (const t of this.teachers) {
      payload.push({
        id: t.id,
        subjectId: t.subjectId,
        subjectName: t.subjectName,
        userName: t.userName,
        lookBackTime: t.lookBackTime && t.lookBackTime > 0 ? t.lookBackTime : this.lookBackTime
      });
    }
    const rows = await AiApi.lookbackOverview(payload);
    this.overviewItems = rows.filter((item: AiOverviewItem) => item.totalCount > 0);
  }

  private async loadWrong(teacherId: number, days: number): Promise<void> {
    const data = await AiApi.wrongQuestion(teacherId, days);
    this.wrongOverview = data;
    this.wrongQuestions = data && data.wrongQuestionList ? data.wrongQuestionList : [];
  }

  private async loadKnowledge(teacherId: number): Promise<void> {
    const data = await AiApi.knowledgeLib(teacherId);
    this.knowledgeOverview = data;
    const rows = data && data.knowledgeLibList ? data.knowledgeLibList : [];
    rows.sort((a: AiKnowledgeLibItem, b: AiKnowledgeLibItem) => {
      if (a.libType !== b.libType) {
        return a.libType - b.libType;
      }
      return this.compareLibNumber(a.libNumber, b.libNumber);
    });
    this.knowledgeItems = rows;
  }

  private compareLibNumber(a: string, b: string): number {
    const ap = a.split('.');
    const bp = b.split('.');
    const len = Math.max(ap.length, bp.length);
    for (let i = 0; i < len; i++) {
      const an = this.parseNumberPart(ap, i);
      const bn = this.parseNumberPart(bp, i);
      if (an !== bn) {
        return an - bn;
      }
    }
    return a.localeCompare(b);
  }

  private parseNumberPart(parts: string[], idx: number): number {
    if (idx < 0 || idx >= parts.length) {
      return 0;
    }
    const raw = parts[idx];
    if (raw === undefined) {
      return 0;
    }
    const value = parseInt(raw);
    return isNaN(value) ? 0 : value;
  }

  private async changeLookBack(delta: number): Promise<void> {
    const next = Math.max(1, Math.min(60, this.lookBackTime + delta));
    if (next === this.lookBackTime) {
      return;
    }
    this.lookBackTime = next;
    const t = this.currentTeacher();
    if (t !== null) {
      t.lookBackTime = next;
    }
    try {
      const userId = ApiClient.getUserId();
      if (userId > 0) {
        await AiApi.setLookbackTime(userId, next);
      }
    } catch (e) {
      const err = e as Error;
      hilog.warn(DOMAIN, TAG, 'save lookback failed: %{public}s', err.message);
    }
    if (this.tab === TAB_LOOKBACK) {
      await this.loadCurrentContent();
    }
  }

  private selectOverviewItem(item: AiOverviewItem): void {
    const idx = this.findTeacherIndex(item);
    if (idx > 0) {
      this.selectTeacher(idx);
    }
  }

  private questionType(type: number): string {
    switch (type) {
      case 0:
        return '单选';
      case 1:
        return '不定项';
      case 2:
        return '填空';
      case 3:
        return '简答';
      default:
        return '--';
    }
  }

  private difficultyText(level: number): string {
    switch (level) {
      case 1:
        return '困难';
      case 2:
        return '中等';
      case 3:
        return '基础';
      default:
        return '--';
    }
  }

  private difficultyColor(level: number): ResourceColor {
    switch (level) {
      case 1:
        return Theme.DANGER;
      case 2:
        return Theme.WARN;
      case 3:
        return Theme.SUCCESS;
      default:
        return Theme.TEXT_3;
    }
  }

  private redoValueText(score: number): string {
    if (score >= 14 && score <= 22) {
      return '高';
    }
    if (score > 6 && score < 14) {
      return '中';
    }
    if (score >= 0 && score <= 6) {
      return '一般';
    }
    return '--';
  }

  private reformText(type: number, time: string | null): string {
    if (time !== null && time.length > 0) {
      return this.formatDate(time);
    }
    switch (type) {
      case 1:
        return '全对';
      case 2:
        return '半对';
      case 3:
        return '错误';
      default:
        return '错题重做';
    }
  }

  private libReformText(item: AiKnowledgeLibItem): string {
    if (item.reformTime !== null && item.reformTime.length > 0) {
      const count = item.reformCount === null ? 0 : item.reformCount;
      return `${this.formatDate(item.reformTime)}(${count})`;
    }
    switch (item.reformType) {
      case 1:
        return '全部通过';
      case 2:
        return '部分通过';
      case 3:
        return '未通过';
      default:
        return '自我修正';
    }
  }

  private noMasterCount(item: AiOverviewItem): number {
    return item.noMasterCount === undefined ? 0 : item.noMasterCount;
  }

  private reformColor(type: number): ResourceColor {
    switch (type) {
      case 1:
        return Theme.SUCCESS;
      case 2:
        return Theme.WARN;
      case 3:
        return Theme.DANGER;
      default:
        return Theme.TEXT_2;
    }
  }

  private correctRateText(type: number): string {
    switch (type) {
      case 0:
        return '事半功倍';
      case 1:
        return '等值';
      case 2:
        return '事倍功半';
      default:
        return '--';
    }
  }

  private libTypeText(type: number): string {
    switch (type) {
      case 0:
        return '素';
      case 1:
        return '能';
      default:
        return '知';
    }
  }

  private libTypeColor(type: number): ResourceColor {
    switch (type) {
      case 0:
        return Theme.SUCCESS;
      case 1:
        return Theme.PRIMARY;
      default:
        return Theme.WARN;
    }
  }

  private subjectColor(subject: string): ResourceColor {
    switch (subject) {
      case '语文':
        return '#FF443F';
      case '数学':
        return '#007EF9';
      case '英语':
        return '#00AD66';
      case '历史':
        return '#00C2E8';
      case '地理':
        return '#6C78F0';
      case '政治':
        return '#9ECF3F';
      case '物理':
        return '#D69600';
      case '化学':
        return '#A96B42';
      case '生物':
        return '#E17701';
      default:
        return Theme.PRIMARY;
    }
  }

  private wrongCauseText(v: number | string | null): string {
    if (v === null) {
      return '--';
    }
    if (typeof v === 'string') {
      return v.length > 0 ? v : '--';
    }
    switch (v) {
      case 1:
        return '概念';
      case 2:
        return '审题';
      case 3:
        return '思路';
      case 4:
        return '计算';
      case 5:
        return '表达';
      case 6:
        return '其他';
      default:
        return `${v}`;
    }
  }

  private daysFromNow(time: string): string {
    if (time.length === 0) {
      return '--';
    }
    const published = new Date(time).getTime();
    if (isNaN(published)) {
      return '--';
    }
    const now = new Date().getTime();
    const diff = Math.ceil(Math.abs(now - published) / 86400000);
    if (diff <= 0) {
      return '今天';
    }
    if (diff === 1) {
      return '昨天';
    }
    if (diff === 2) {
      return '前天';
    }
    if (diff <= 30) {
      return `${diff}天`;
    }
    return '30+';
  }

  private formatDate(time: string): string {
    if (time.length < 10) {
      return time;
    }
    return time.substring(0, 10);
  }

  private questionHtml(q: AiWrongQuestion): string {
    const html = q.questionStem ?? q.stem ?? q.questionContent ?? q.content ?? '';
    if (html.length > 0) {
      return html;
    }
    return q.dataName;
  }

  private wrongTotalCount(): number {
    return this.wrongOverview === null ? 0 : this.wrongOverview.totalCount;
  }

  private wrongReformedCount(): number {
    return this.wrongOverview === null ? 0 : this.wrongOverview.reformedCount;
  }

  private wrongHighCount(): number {
    return this.wrongOverview === null ? 0 : this.wrongOverview.highCount;
  }

  private wrongMiddleCount(): number {
    return this.wrongOverview === null ? 0 : this.wrongOverview.middleCount;
  }

  private wrongLowCount(): number {
    return this.wrongOverview === null ? 0 : this.wrongOverview.lowCount;
  }

  private knowledgeTotalCount(): number {
    return this.knowledgeOverview === null ? 0 : this.knowledgeOverview.totalCount;
  }

  private knowledgeNoMasterCount(): number {
    return this.knowledgeOverview === null ? 0 : this.knowledgeOverview.noMasterCount;
  }

  private knowledgeReformedCount(): number {
    return this.knowledgeOverview === null ? 0 : this.knowledgeOverview.reformedCount;
  }

  private knowledgeHighCount(): number {
    return this.knowledgeOverview === null ? 0 : this.knowledgeOverview.highCount;
  }

  private knowledgeMiddleCount(): number {
    return this.knowledgeOverview === null ? 0 : this.knowledgeOverview.middleCount;
  }

  private knowledgeLowCount(): number {
    return this.knowledgeOverview === null ? 0 : this.knowledgeOverview.lowCount;
  }

  private updateWrongReform(questionId: number, type: number): void {
    this.wrongQuestions.forEach((item: AiWrongQuestion) => {
      if (item.questionId === questionId) {
        item.reformType = type;
        item.reformTime = new Date().toISOString();
      }
    });
    this.wrongQuestions = [...this.wrongQuestions];
  }

  private updateLibReform(libId: number, type: number): void {
    this.knowledgeItems.forEach((item: AiKnowledgeLibItem) => {
      if (item.libId === libId) {
        item.reformType = type;
        item.reformTime = new Date().toISOString();
        const count: number = item.reformCount === null ? 0 : item.reformCount;
        item.reformCount = count + 1;
      }
    });
    this.knowledgeItems = [...this.knowledgeItems];
  }

  private async markQuestionReform(item: AiWrongQuestion, type: number): Promise<void> {
    const teacher = this.currentTeacher();
    if (teacher === null || this.reformingId !== 0) {
      return;
    }
    this.reformingId = item.questionId;
    try {
      const body: AiReformBody = {
        studentId: ApiClient.getUserId(),
        sourceId: item.questionId,
        sourceType: 0,
        subjectId: teacher.subjectId,
        reformType: type,
        sourceFirstType: item.dataType
      };
      await AiApi.reform(body);
      this.updateWrongReform(item.questionId, type);
    } catch (e) {
      const err = e as Error;
      this.errorText = err.message || '错题重做状态保存失败';
      hilog.warn(DOMAIN, TAG, 'mark question reform failed: %{public}s', this.errorText);
    } finally {
      this.reformingId = 0;
    }
  }

  private async markLibReform(item: AiKnowledgeLibItem, type: number): Promise<void> {
    const teacher = this.currentTeacher();
    if (teacher === null || this.reformingId !== 0) {
      return;
    }
    this.reformingId = item.libId;
    try {
      const body: AiReformBody = {
        studentId: ApiClient.getUserId(),
        sourceId: item.libId,
        sourceType: 1,
        subjectId: teacher.subjectId,
        reformType: type
      };
      await AiApi.reform(body);
      this.updateLibReform(item.libId, type);
    } catch (e) {
      const err = e as Error;
      this.errorText = err.message || '自我修正状态保存失败';
      hilog.warn(DOMAIN, TAG, 'mark lib reform failed: %{public}s', this.errorText);
    } finally {
      this.reformingId = 0;
    }
  }

  private async toggleLibQuestions(item: AiKnowledgeLibItem): Promise<void> {
    const teacher = this.currentTeacher();
    if (teacher === null) {
      return;
    }
    if (this.selectedLibId === item.libId) {
      this.selectedLibId = 0;
      this.libQuestions = [];
      return;
    }
    this.selectedLibId = item.libId;
    this.libQuestions = [];
    this.loadingLibQuestions = true;
    try {
      const rows = await AiApi.libWrongQuestion(teacher.id, item.libId);
      rows.sort((a: AiWrongQuestion, b: AiWrongQuestion) => {
        return this.selfReadSortValue(a) - this.selfReadSortValue(b);
      });
      this.libQuestions = rows;
    } catch (e) {
      const err = e as Error;
      this.errorText = err.message || '知识模块试题加载失败';
      hilog.warn(DOMAIN, TAG, 'load lib questions failed: %{public}s', this.errorText);
    } finally {
      this.loadingLibQuestions = false;
    }
  }

  private selfReadSortValue(item: AiWrongQuestion): number {
    return item.selfReadOverSwitch === undefined ? 0 : item.selfReadOverSwitch;
  }

  @Builder
  teacherList() {
    Column({ space: 8 }) {
      Text('目 录')
        .fontSize(Theme.F_BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 4 })

      List({ space: 6 }) {
        ListItem() {
          this.teacherRow(0, '学科对比', '')
        }
        ForEach(this.teachers, (t: AiTeacher, idx: number) => {
          ListItem() {
            this.teacherRow(idx + 1, t.userName, t.subjectName)
          }
        }, (t: AiTeacher) => `ai_teacher_${t.id}`)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 10, right: 10 })
      .contentEndOffset(Theme.TABBAR_CLEARANCE)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  teacherRow(idx: number, name: string, subject: string) {
    Row({ space: 8 }) {
      Circle({ width: 8, height: 8 })
        .fill(idx === 0 ? Theme.PRIMARY : this.subjectColor(subject))

      Column({ space: 2 }) {
        Text(name)
          .fontSize(Theme.F_BODY)
          .fontWeight(this.selectedIdx === idx ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.selectedIdx === idx ? Theme.PRIMARY : Theme.TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (subject.length > 0) {
          Text(subject)
            .fontSize(Theme.F_MINI)
            .fontColor(Theme.TEXT_3)
            .maxLines(1)
        } else if (idx === 0) {
          Text('全部学科')
            .fontSize(Theme.F_MINI)
            .fontColor(Theme.TEXT_3)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .borderRadius(Theme.R_LG)
    .backgroundColor(this.selectedIdx === idx ? Theme.PRIMARY_SOFT : Color.Transparent)
    .onClick(() => {
      this.selectTeacher(idx);
    })
  }

  @Builder
  mobileTeacherTabs() {
    Scroll() {
      Row({ space: 8 }) {
        this.teacherPill(0, '学科对比', '')
        ForEach(this.teachers, (t: AiTeacher, idx: number) => {
          this.teacherPill(idx + 1, t.userName, t.subjectName)
        }, (t: AiTeacher) => `ai_pill_${t.id}`)
      }
      .padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(46)
  }

  @Builder
  teacherPill(idx: number, name: string, subject: string) {
    Row({ space: 5 }) {
      Text(idx === 0 ? name : `${name} (${subject})`)
        .fontSize(Theme.F_SUB)
        .fontWeight(this.selectedIdx === idx ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selectedIdx === idx ? Color.White : Theme.TEXT)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(34)
    .padding({ left: 14, right: 14 })
    .backgroundColor(this.selectedIdx === idx ? Theme.PRIMARY : Theme.SURFACE)
    .backgroundBlurStyle(this.selectedIdx === idx ? BlurStyle.NONE : BlurStyle.COMPONENT_REGULAR)
    .borderRadius(Theme.R_XL)
    .border({ width: 1, color: this.selectedIdx === idx ? Theme.PRIMARY : '#20000000' })
    .onClick(() => {
      this.selectTeacher(idx);
    })
  }

  @Builder
  tabBar() {
    Row({ space: 8 }) {
      this.tabChip(TAB_LOOKBACK, '每日最佳回顾')
      this.tabChip(TAB_WRONG, '错 题')
      this.tabChip(TAB_LIB, '知识模块')
      Blank().layoutWeight(1)
      if (this.tab === TAB_LOOKBACK) {
        this.lookbackControl()
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  tabChip(tab: number, label: string) {
    Text(label)
      .fontSize(Theme.F_BODY)
      .fontWeight(this.tab === tab ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.tab === tab ? Color.White : Theme.TEXT_2)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .borderRadius(Theme.R_XL)
      .backgroundColor(this.tab === tab ? Theme.PRIMARY : '#F0F2F5')
      .onClick(() => {
        this.selectTab(tab);
      })
  }

  @Builder
  lookbackControl() {
    Row({ space: 6 }) {
      Text('最佳回顾时间设定')
        .fontSize(Theme.F_MINI)
        .fontColor(Theme.TEXT_3)
      SquishButton({
        onTap: () => {
          this.changeLookBack(-1);
        }
      }) {
        Text('-')
          .fontSize(Theme.F_BODY)
          .fontColor(Theme.PRIMARY)
          .width(24)
          .height(24)
          .textAlign(TextAlign.Center)
          .backgroundColor(Theme.PRIMARY_SOFT)
          .borderRadius(12)
      }
      Text(`${this.lookBackTime} 天`)
        .fontSize(Theme.F_SUB)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT)
      SquishButton({
        onTap: () => {
          this.changeLookBack(1);
        }
      }) {
        Text('+')
          .fontSize(Theme.F_BODY)
          .fontColor(Theme.PRIMARY)
          .width(24)
          .height(24)
          .textAlign(TextAlign.Center)
          .backgroundColor(Theme.PRIMARY_SOFT)
          .borderRadius(12)
      }
    }
    .padding({ left: 8, right: 8, top: 5, bottom: 5 })
    .backgroundColor(Theme.SURFACE)
    .borderRadius(Theme.R_XL)
  }

  @Builder
  errorBanner() {
    if (this.errorText.length > 0) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
          .fontSize(18)
          .fontColor([Theme.DANGER])
        Text(this.errorText)
          .fontSize(Theme.F_SUB)
          .fontColor(Theme.DANGER)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('重试')
          .fontSize(Theme.F_SUB)
          .fontColor(Theme.PRIMARY)
          .onClick(() => {
            this.loadCurrentContent();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor('#12E94B4B')
      .borderRadius(Theme.R_LG)
      .margin({ left: 16, right: 16, bottom: 8 })
    }
  }

  @Builder
  contentHeader() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(this.currentTitle())
          .fontSize(Theme.F_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.selectedIdx > 0) {
          Text(this.currentSubjectName())
            .fontSize(Theme.F_SUB)
            .fontColor(Color.White)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor(this.currentSubjectColor())
            .borderRadius(Theme.R_XL)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4 })

      this.tabBar()
    }
    .width('100%')
  }

  @Builder
  overviewList() {
    if (this.loadingContent) {
      LoadingView()
        .layoutWeight(1)
    } else if (this.overviewItems.length === 0) {
      EmptyView({ text: this.tab === TAB_LOOKBACK ? '暂无相关回顾数据' : '暂无相关数据' })
        .layoutWeight(1)
    } else {
      List({ space: 8 }) {
        ListItem() {
          this.overviewTableHeader()
        }
        ForEach(this.overviewItems, (item: AiOverviewItem) => {
          ListItem() {
            this.overviewCard(item)
          }
        }, (item: AiOverviewItem) => `overview_${item.id}_${item.subjectName}`)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 12, right: 12 })
      .contentEndOffset(Theme.TABBAR_CLEARANCE)
    }
  }

  @Builder
  overviewTableHeader() {
    GlassCard({ innerPadding: 12, surfaceColor: Theme.BG_CREAM_DEEP }) {
      Column({ space: 6 }) {
        Row() {
          Text('学科')
            .fontSize(Theme.F_SUB)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .layoutWeight(2)
          Text(this.tab === TAB_LIB ? '未掌握/知识模块' :
            (this.tab === TAB_LOOKBACK ? '每日错题' : '错题总数'))
            .fontSize(Theme.F_SUB)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Text(this.tab === TAB_LIB ? '已修正次数' : '待重做错题')
            .fontSize(Theme.F_SUB)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }
        Row() {
          Blank().layoutWeight(2)
          Text('高')
            .fontSize(Theme.F_MINI)
            .fontColor(Theme.TEXT_3)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Text('中')
            .fontSize(Theme.F_MINI)
            .fontColor(Theme.TEXT_3)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Text('一般')
            .fontSize(Theme.F_MINI)
            .fontColor(Theme.TEXT_3)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
    }
  }

  @Builder
  overviewCard(item: AiOverviewItem) {
    Column() {
      GlassCard({ innerPadding: 14 }) {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Circle({ width: 10, height: 10 })
              .fill(this.subjectColor(item.subjectName))
            Text(`${item.subjectName}(${item.userName})`)
              .fontSize(Theme.F_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.TEXT)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(16)
              .fontColor([Theme.TEXT_3])
          }
          Row() {
            this.metricBlock(
              this.tab === TAB_LIB ? `${this.noMasterCount(item)}/${item.totalCount}` : `${item.totalCount}`,
              this.tab === TAB_LIB ? '未掌握/模块' : '错题')
            this.metricBlock(`${item.reformedCount}`, this.tab === TAB_LIB ? '已修正' : '待重做')
            this.metricBlock(`${item.highCount}`, '高')
            this.metricBlock(`${item.middleCount}`, '中')
            this.metricBlock(`${item.lowCount}`, '一般')
          }
          .width('100%')
        }
        .width('100%')
      }
    }
    .width('100%')
    .onClick(() => {
      this.selectOverviewItem(item);
    })
  }

  private findTeacherIndex(item: AiOverviewItem): number {
    const id = item.teacherid ?? item.teacherId ?? item.id;
    let idx = 1;
    for (const teacher of this.teachers) {
      if (teacher.id === id) {
        return idx;
      }
      idx++;
    }
    idx = 1;
    for (const teacher of this.teachers) {
      if (teacher.subjectName === item.subjectName && teacher.userName === item.userName) {
        return idx;
      }
      idx++;
    }
    return 0;
  }

  @Builder
  metricBlock(value: string, label: string) {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(Theme.F_BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(label)
        .fontSize(Theme.F_MINI)
        .fontColor(Theme.TEXT_3)
        .maxLines(1)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  wrongContent() {
    if (this.loadingContent) {
      LoadingView()
        .layoutWeight(1)
    } else if (this.wrongQuestions.length === 0) {
      EmptyView({ text: this.tab === TAB_LOOKBACK ? '指定日期下暂无错题数据' : '暂无相关数据' })
        .layoutWeight(1)
    } else {
      List({ space: 8 }) {
        ListItem() {
          this.wrongSummaryCard()
        }
        ForEach(this.wrongQuestions, (item: AiWrongQuestion) => {
          ListItem() {
            this.wrongQuestionCard(item)
          }
        }, (item: AiWrongQuestion) => `wrong_${item.id}_${item.questionId}`)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 12, right: 12 })
      .contentEndOffset(Theme.TABBAR_CLEARANCE)
    }
  }

  @Builder
  wrongSummaryCard() {
    if (this.wrongOverview !== null) {
      GlassCard({ innerPadding: 14, surfaceColor: Theme.BG_CREAM_DEEP }) {
        Column({ space: 10 }) {
          Row() {
            Text('学科')
              .fontSize(Theme.F_SUB)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT_2)
              .layoutWeight(1)
            Text(this.tab === TAB_LOOKBACK ? '每日错题' : '错题总数')
              .fontSize(Theme.F_SUB)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT_2)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
            Text('待重做错题')
              .fontSize(Theme.F_SUB)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT_2)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
          }
          Row() {
            Text(this.currentSubjectName())
              .fontSize(Theme.F_BODY)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.currentSubjectColor())
              .layoutWeight(1)
            Text(`${this.wrongTotalCount()}`)
              .fontSize(Theme.F_BODY)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
            Text(`${this.wrongReformedCount()}`)
              .fontSize(Theme.F_BODY)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
          }
          Row() {
            this.metricBlock(`${this.wrongHighCount()}`, '高')
            this.metricBlock(`${this.wrongMiddleCount()}`, '中')
            this.metricBlock(`${this.wrongLowCount()}`, '一般')
          }
        }
        .width('100%')
      }
    }
  }

  @Builder
  wrongQuestionCard(item: AiWrongQuestion) {
    Column() {
      GlassCard({ innerPadding: 14 }) {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Text(item.dataName)
              .fontSize(Theme.F_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(item.dataType === 0 ? Theme.WARN : Theme.PRIMARY)
              .layoutWeight(1)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.reformText(item.reformType, item.reformTime))
              .fontSize(Theme.F_MINI)
              .fontColor(this.reformColor(item.reformType))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor('#F0F2F5')
              .borderRadius(Theme.R_XL)
          }
          Flex({ wrap: FlexWrap.Wrap }) {
            this.infoTag(this.questionType(item.questionType), Theme.TEXT_2)
            this.infoTag(`难度系数 ${Number(item.totalScoring / 100).toFixed(2)}`, Theme.TEXT_2)
            this.infoTag(this.difficultyText(item.difficultyLevel), this.difficultyColor(item.difficultyLevel))
            this.infoTag(`错因 ${this.wrongCauseText(item.wrongCause)}`, Theme.TEXT_2)
            this.infoTag(this.daysFromNow(item.publishTime), Theme.TEXT_2)
            this.infoTag(`重做价值 ${this.redoValueText(item.zhdf)}`, Theme.TEXT_2)
          }
          .width('100%')

          if (this.selectedQuestionId === item.questionId) {
            Divider().color(Theme.DIVIDER)
            HtmlRichText({ html: this.questionHtml(item) })
            if (item.answer !== null && item.answer !== undefined && item.answer.length > 0) {
              this.answerLine('正确答案', item.answer, Theme.SUCCESS)
            }
            if (item.studentAnswer !== null && item.studentAnswer !== undefined &&
              item.studentAnswer.length > 0) {
              this.answerLine('我的答案', item.studentAnswer, Theme.DANGER)
            }
            if (item.questionAnalysis !== null && item.questionAnalysis !== undefined &&
              item.questionAnalysis.length > 0) {
              this.answerLine('解析', item.questionAnalysis, Theme.TEXT_2)
            }
            this.reformButtons(item)
          }
        }
        .width('100%')
      }
    }
    .width('100%')
    .onClick(() => {
      this.selectedQuestionId = this.selectedQuestionId === item.questionId ? 0 : item.questionId;
    })
  }

  @Builder
  infoTag(text: string, color: ResourceColor) {
    Text(text)
      .fontSize(Theme.F_MINI)
      .fontColor(color)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor('#F0F2F5')
      .borderRadius(Theme.R_XL)
      .margin({ right: 6, bottom: 6 })
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  answerLine(label: string, value: string, color: ResourceColor) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(Theme.F_SUB)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
      Text(value)
        .fontSize(Theme.F_SUB)
        .fontColor(Theme.TEXT)
        .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  reformButtons(item: AiWrongQuestion) {
    Row({ space: 8 }) {
      Text('全对')
        .fontSize(Theme.F_SUB)
        .fontColor(item.reformType === 1 ? Color.White : Theme.SUCCESS)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(item.reformType === 1 ? Theme.SUCCESS : '#1452C41A')
        .borderRadius(Theme.R_XL)
        .onClick(() => {
          this.markQuestionReform(item, 1);
        })
      Text('半对')
        .fontSize(Theme.F_SUB)
        .fontColor(item.reformType === 2 ? Color.White : Theme.WARN)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(item.reformType === 2 ? Theme.WARN : '#14FAAD14')
        .borderRadius(Theme.R_XL)
        .onClick(() => {
          this.markQuestionReform(item, 2);
        })
      Text('错误')
        .fontSize(Theme.F_SUB)
        .fontColor(item.reformType === 3 ? Color.White : Theme.DANGER)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor(item.reformType === 3 ? Theme.DANGER : '#12E94B4B')
        .borderRadius(Theme.R_XL)
        .onClick(() => {
          this.markQuestionReform(item, 3);
        })
    }
    .width('100%')
  }

  @Builder
  knowledgeContent() {
    if (this.loadingContent) {
      LoadingView()
        .layoutWeight(1)
    } else if (this.knowledgeItems.length === 0) {
      EmptyView({ text: '暂无相关数据' })
        .layoutWeight(1)
    } else {
      List({ space: 8 }) {
        ListItem() {
          this.knowledgeSummaryCard()
        }
        ForEach(this.knowledgeItems, (item: AiKnowledgeLibItem) => {
          ListItem() {
            this.knowledgeCard(item)
          }
        }, (item: AiKnowledgeLibItem) => `lib_${item.libId}`)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 12, right: 12 })
      .contentEndOffset(Theme.TABBAR_CLEARANCE)
    }
  }

  @Builder
  knowledgeSummaryCard() {
    if (this.knowledgeOverview !== null) {
      GlassCard({ innerPadding: 14, surfaceColor: Theme.BG_CREAM_DEEP }) {
        Column({ space: 10 }) {
          Row() {
            Text('学科')
              .fontSize(Theme.F_SUB)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT_2)
              .layoutWeight(1)
            Text('未掌握/知识模块')
              .fontSize(Theme.F_SUB)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT_2)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
            Text('已修正次数')
              .fontSize(Theme.F_SUB)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT_2)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
          }
          Row() {
            Text(this.currentSubjectName())
              .fontSize(Theme.F_BODY)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.currentSubjectColor())
              .layoutWeight(1)
            Text(`${this.knowledgeNoMasterCount()}/${this.knowledgeTotalCount()}`)
              .fontSize(Theme.F_BODY)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
            Text(`${this.knowledgeReformedCount()}`)
              .fontSize(Theme.F_BODY)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
          }
          Row() {
            this.metricBlock(`${this.knowledgeHighCount()}`, '高')
            this.metricBlock(`${this.knowledgeMiddleCount()}`, '中')
            this.metricBlock(`${this.knowledgeLowCount()}`, '一般')
          }
        }
        .width('100%')
      }
    }
  }

  @Builder
  knowledgeCard(item: AiKnowledgeLibItem) {
    Column() {
      GlassCard({ innerPadding: 14 }) {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Text(`【${this.libTypeText(item.libType)}】`)
              .fontSize(Theme.F_SUB)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.libTypeColor(item.libType))
            Text(`${item.libNumber}${item.libName}`)
              .fontSize(Theme.F_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.TEXT)
              .layoutWeight(1)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            SymbolGlyph(this.selectedLibId === item.libId
              ? $r('sys.symbol.chevron_down') : $r('sys.symbol.chevron_right'))
              .fontSize(16)
              .fontColor([Theme.TEXT_3])
          }
          Row() {
            this.metricBlock(item.scoringRate, '掌握程度')
            this.metricBlock(`${item.questionAllCount}`, '考查数')
            this.metricBlock(`${item.errorQuestionCount}`, '错题数')
            this.metricBlock(item.errorProportionRate, '错题比例')
          }
          Flex({ wrap: FlexWrap.Wrap }) {
            this.infoTag(this.correctRateText(item.correctRateType), Theme.TEXT_2)
            Text(this.libReformText(item))
              .fontSize(Theme.F_MINI)
              .fontColor(this.reformColor(item.reformType))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor('#F0F2F5')
              .borderRadius(Theme.R_XL)
              .margin({ right: 6, bottom: 6 })
            this.libReformButton(item, 1, '全部通过')
            this.libReformButton(item, 2, '部分通过')
            this.libReformButton(item, 3, '未通过')
          }
          .width('100%')

          if (this.selectedLibId === item.libId) {
            Divider().color(Theme.DIVIDER)
            if (this.loadingLibQuestions) {
              LoadingView({ text: '加载试题...' })
            } else if (this.libQuestions.length === 0) {
              EmptyView({ text: '该知识模块下没有试题' })
            } else {
              ForEach(this.libQuestions, (q: AiWrongQuestion) => {
                this.libQuestionPreview(q)
              }, (q: AiWrongQuestion) => `lib_q_${q.id}_${q.questionId}`)
            }
          }
        }
        .width('100%')
      }
    }
    .width('100%')
    .onClick(() => {
      this.toggleLibQuestions(item);
    })
  }

  @Builder
  libReformButton(item: AiKnowledgeLibItem, type: number, label: string) {
    Text(label)
      .fontSize(Theme.F_MINI)
      .fontColor(item.reformType === type ? Color.White : this.reformColor(type))
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor(item.reformType === type ? this.reformColor(type) : '#F0F2F5')
      .borderRadius(Theme.R_XL)
      .margin({ right: 6, bottom: 6 })
      .onClick(() => {
        this.markLibReform(item, type);
      })
  }

  @Builder
  libQuestionPreview(q: AiWrongQuestion) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(q.dataName)
          .fontSize(Theme.F_SUB)
          .fontColor(q.dataType === 0 ? Theme.WARN : Theme.PRIMARY)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.questionType(q.questionType))
          .fontSize(Theme.F_MINI)
          .fontColor(Theme.TEXT_3)
      }
      HtmlRichText({ html: this.questionHtml(q) })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  contentBody() {
    Column() {
      this.contentHeader()
      this.errorBanner()

      if (this.selectedIdx === 0) {
        this.overviewList()
      } else if (this.tab === TAB_LIB) {
        this.knowledgeContent()
      } else {
        this.wrongContent()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  wideModeLayout() {
    Row() {
      Column() {
        this.teacherList()
      }
      .width('32%')
      .constraintSize({ minWidth: 220, maxWidth: 360 })
      .height('100%')
      .backgroundColor(Theme.BG_CREAM_DEEP)

      Divider().vertical(true).color(Theme.DIVIDER).height('100%')

      Column() {
        this.contentBody()
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  narrowModeLayout() {
    Column() {
      this.mobileTeacherTabs()
      Divider().color(Theme.DIVIDER).width('100%')
      this.contentBody()
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      Text('AI')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .width('100%')
        .padding({ top: this.ui.topSafeVp + 12, left: 20, right: 20, bottom: 8 })

      if (this.loadingTeachers) {
        LoadingView()
          .layoutWeight(1)
      } else if (this.teachers.length === 0 && this.errorText.length === 0) {
        EmptyView({ text: '暂无教师' })
          .layoutWeight(1)
      } else if (this.ui.isWide) {
        this.wideModeLayout()
      } else {
        this.narrowModeLayout()
      }
    }
    .width('100%')
    .height('100%')
  }
}
