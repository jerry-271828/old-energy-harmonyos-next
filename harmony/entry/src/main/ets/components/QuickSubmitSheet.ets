// 快捷提交弹窗：对照油猴脚本 createQuickSubmitModal 的原生重写。
//
// 行为（与脚本逐条对齐）：
//   1. 列出本课件/试卷的所有选择题题号；已作答的标灰、不可作为起点、填充时跳过。
//   2. 点未作答的题号选「答题起点」，弹出输入框。
//   3. 输入一串答案：含空格按空格分词（每段可多选，如 "AD"→A,D），
//      不含空格则逐字符拆分（"BCA"→B、C、A 三题）。答案从起点起依次填入未作答题。
//   4.「检查答案」（仅 allowCheck 时显示）：逐题比对正确答案，显示正确/错误。
//   5.「确认提交」：把每段答案保存到对应题（studentAnswer 逗号分隔），由父级在
//      全部保存后触发整卷提交/补交（脚本结尾点「手动提交」按钮的等价动作）。
//
// 数据全部来自原生页面状态（content/question 接口），不依赖 GM 存储。

import { Theme } from '../theme/Theme';
import { SquishButton } from './glass/GlassKit';

// 一道可快捷作答的选择题
export interface QuickSubmitItem {
  questionId: number;
  qNum: string;
  correctAnswer: string;   // 正确答案（可能为空，为空时无法检查）
  studentAnswer: string;   // 学生当前作答（逗号分隔，空串=未作答）
}

// 一次填充：要保存的单题答案
export interface QuickSubmitFill {
  questionId: number;
  studentAnswer: string;   // 逗号分隔，如 "A,D"
}

interface QsCheckRow {
  qNum: string;
  userDisp: string;        // 显示用的你的答案，如 "A,D"
  known: boolean;          // 是否有正确答案可比对
  correct: boolean;
  expected: string;
}

@ComponentV2
export struct QuickSubmitSheet {
  @Param items: QuickSubmitItem[] = [];
  @Param allowCheck: boolean = false;     // 是否显示「检查答案」（enableAnswerForce 且非考试）
  @Param submitting: boolean = false;     // 提交中（父级控制）
  @Param onClose: () => void = () => {};
  @Param onSubmit: (fills: QuickSubmitFill[]) => void = (_f: QuickSubmitFill[]) => {};

  @Local private startIndex: number = 0;
  @Local private inInput: boolean = false;
  @Local private input: string = '';
  @Local private checked: boolean = false;
  @Local private checkRows: QsCheckRow[] = [];

  aboutToAppear(): void {
    this.startIndex = this.firstUnansweredIndex();
  }

  private firstUnansweredIndex(): number {
    for (let i = 0; i < this.items.length; i++) {
      if (!this.isAnswered(this.items[i])) {
        return i;
      }
    }
    return 0;
  }

  private isAnswered(it: QuickSubmitItem): boolean {
    return it.studentAnswer.trim().length > 0;
  }

  // 含空格按空格分词；否则逐字符拆分（对照脚本 includes(' ') ? split(/\s+/) : split('')）
  private parseTokens(raw: string): string[] {
    const s = raw.trim();
    if (s.length === 0) {
      return [];
    }
    if (s.indexOf(' ') >= 0) {
      return s.split(/\s+/).filter((t: string) => t.length > 0);
    }
    return s.split('');
  }

  // 单段 → 逗号分隔答案（对照脚本 token.toUpperCase().split('').join(',')）
  private tokenToAnswer(token: string): string {
    return token.toUpperCase().split('').join(',');
  }

  // 比对用归一化：取字母数字、排序、逗号连接（兼容 "AD"/"A,D"/"DA"）
  private normSet(s: string): string {
    const m = s.toUpperCase().match(/[A-Z0-9]/g);
    if (m === null) {
      return '';
    }
    return m.sort().join(',');
  }

  // 从起点起，输入的最后一段答案会落在哪个题号（用于高亮预览）
  private landingIndex(): number {
    const tokens = this.parseTokens(this.input);
    if (tokens.length === 0) {
      return this.startIndex;
    }
    let toPlace = tokens.length;
    let last = this.startIndex;
    for (let i = this.startIndex; i < this.items.length && toPlace > 0; i++) {
      if (!this.isAnswered(this.items[i])) {
        last = i;
        toPlace--;
      }
    }
    return last;
  }

  private buildFills(): QuickSubmitFill[] {
    const tokens = this.parseTokens(this.input);
    const fills: QuickSubmitFill[] = [];
    let placed = 0;
    for (let i = this.startIndex; i < this.items.length && placed < tokens.length; i++) {
      const it = this.items[i];
      if (this.isAnswered(it)) {
        continue;
      }
      fills.push({ questionId: it.questionId, studentAnswer: this.tokenToAnswer(tokens[placed]) });
      placed++;
    }
    return fills;
  }

  private runCheck(): void {
    const tokens = this.parseTokens(this.input);
    const rows: QsCheckRow[] = [];
    let placed = 0;
    for (let i = this.startIndex; i < this.items.length && placed < tokens.length; i++) {
      const it = this.items[i];
      if (this.isAnswered(it)) {
        continue;
      }
      const token = tokens[placed];
      const known = it.correctAnswer.trim().length > 0;
      rows.push({
        qNum: it.qNum,
        userDisp: this.tokenToAnswer(token),
        known: known,
        correct: known && this.normSet(token) === this.normSet(it.correctAnswer),
        expected: it.correctAnswer
      });
      placed++;
    }
    this.checkRows = rows;
    this.checked = true;
  }

  private selectStart(index: number): void {
    this.startIndex = index;
    this.inInput = true;
    this.checked = false;
    this.checkRows = [];
  }

  private onInputChange(v: string): void {
    this.input = v;
    // 输入变化后旧的检查结果作废（清空显示），但保留「已检查」态以维持提交按钮可见
    this.checkRows = [];
  }

  // ---- chip 着色 ----
  private chipState(index: number): string {
    if (this.isAnswered(this.items[index])) {
      return 'answered';
    }
    if (!this.inInput) {
      return 'normal';
    }
    if (index === this.startIndex) {
      return 'start';
    }
    if (index > this.startIndex && index <= this.landingIndex()) {
      return 'range';
    }
    return 'normal';
  }

  private chipBg(state: string): ResourceColor {
    if (state === 'start') {
      return Theme.PRIMARY;
    }
    if (state === 'range') {
      return Theme.PRIMARY_SOFT;
    }
    if (state === 'answered') {
      return '#EDEFF2';
    }
    return '#F0F2F5';
  }

  private chipText(state: string): ResourceColor {
    if (state === 'start') {
      return Color.White;
    }
    if (state === 'range') {
      return Theme.PRIMARY;
    }
    if (state === 'answered') {
      return Theme.TEXT_3;
    }
    return Theme.TEXT;
  }

  private showSubmitBtn(): boolean {
    if (!this.inInput) {
      return false;
    }
    // allowCheck：先检查后才出现提交；否则直接可提交（对照脚本 switchToInputMode）
    return this.allowCheck ? this.checked : true;
  }

  @Builder
  chipGrid() {
    Scroll() {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.items, (it: QuickSubmitItem, index: number) => {
          Text(it.qNum)
            .fontSize(Theme.F_SUB)
            .fontWeight(this.chipState(index) === 'start' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.chipText(this.chipState(index)))
            .textAlign(TextAlign.Center)
            .constraintSize({ minWidth: 38 })
            .height(34)
            .padding({ left: 10, right: 10 })
            .margin(4)
            .borderRadius(Theme.R_MD)
            .backgroundColor(this.chipBg(this.chipState(index)))
            .onClick(() => {
              if (!this.isAnswered(it)) {
                this.selectStart(index);
              }
            })
        }, (it: QuickSubmitItem) => `qs_${it.questionId}`)
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ maxHeight: 170 })
    .scrollBar(BarState.Off)
  }

  @Builder
  resultList() {
    Scroll() {
      Column({ space: 4 }) {
        ForEach(this.checkRows, (row: QsCheckRow, idx: number) => {
          Row() {
            Text(`${row.qNum}. `)
              .fontSize(Theme.F_SUB)
              .fontColor(Theme.TEXT_2)
            Text(`[${row.userDisp}] `)
              .fontSize(Theme.F_SUB)
              .fontColor(Theme.TEXT)
            if (!row.known) {
              Text('无答案可对')
                .fontSize(Theme.F_SUB)
                .fontColor(Theme.TEXT_3)
            } else if (row.correct) {
              Text('正确')
                .fontSize(Theme.F_SUB)
                .fontColor(Theme.SUCCESS)
            } else {
              Text(`错误 (应为 ${row.expected})`)
                .fontSize(Theme.F_SUB)
                .fontColor(Theme.DANGER)
            }
          }
          .width('100%')
        }, (row: QsCheckRow, idx: number) => `qsr_${idx}`)
      }
      .width('100%')
    }
    .width('100%')
    .constraintSize({ maxHeight: 140 })
    .scrollBar(BarState.Off)
    .margin({ top: 10 })
  }

  build() {
    Stack() {
      // 背景遮罩：点击空白处关闭
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.onClose();
        })

      // 居中卡片
      Column() {
        Column({ space: 12 }) {
          // 标题
          Column({ space: 2 }) {
            Text(`快捷提交 (${this.items.length}题)`)
              .fontSize(Theme.F_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT)
            Text(this.inInput ? '输入答案，可再次点击题号改起点' : '请点击未作答题号选择答题起点')
              .fontSize(Theme.F_MINI)
              .fontColor(Theme.TEXT_2)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          if (this.items.length === 0) {
            Text('本页没有可快捷作答的选择题')
              .fontSize(Theme.F_SUB)
              .fontColor(Theme.TEXT_3)
              .padding({ top: 20, bottom: 20 })
          } else {
            this.chipGrid()

            if (this.inInput) {
              TextInput({ placeholder: '如 BCA 或 B C AD', text: this.input })
                .width('100%')
                .height(44)
                .borderRadius(Theme.R_LG)
                .backgroundColor('#F0F2F5')
                .fontSize(Theme.F_BODY)
                .padding({ left: 12, right: 12 })
                .onChange((v: string) => {
                  this.onInputChange(v);
                })
                .onSubmit(() => {
                  if (this.allowCheck && !this.checked) {
                    this.runCheck();
                  } else if (!this.submitting) {
                    this.onSubmit(this.buildFills());
                  }
                })
            }

            if (this.checkRows.length > 0) {
              this.resultList()
            }

            // 按钮栏
            Row({ space: 10 }) {
              Blank().layoutWeight(1)

              if (this.inInput && this.allowCheck) {
                Text('检查答案')
                  .fontSize(Theme.F_BODY)
                  .fontColor(Theme.TEXT)
                  .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                  .borderRadius(Theme.R_XL)
                  .backgroundColor('#F0F2F5')
                  .onClick(() => {
                    this.runCheck();
                  })
              }

              if (this.showSubmitBtn()) {
                SquishButton({
                  onTap: () => {
                    if (!this.submitting) {
                      this.onSubmit(this.buildFills());
                    }
                  }
                }) {
                  Row({ space: 6 }) {
                    if (this.submitting) {
                      LoadingProgress().width(16).height(16).color(Color.White)
                    }
                    Text(this.submitting ? '提交中...' : '确认提交')
                      .fontSize(Theme.F_BODY)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Color.White)
                  }
                  .padding({ left: 18, right: 18, top: 8, bottom: 8 })
                  .backgroundColor(this.submitting ? Theme.TEXT_3 : Theme.PRIMARY)
                  .borderRadius(Theme.R_XL)
                }
              }
            }
            .width('100%')
            .margin({ top: 4 })
          }
        }
        .width('100%')
        .padding(20)
        .backgroundColor(Theme.SURFACE_SOLID)
        .borderRadius(Theme.R_XL)
        .shadow(Theme.GLASS_SHADOW)
        .onClick(() => {
          // 吸收点击，避免穿透到遮罩
        })
      }
      .width('86%')
      .constraintSize({ maxWidth: 460 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
