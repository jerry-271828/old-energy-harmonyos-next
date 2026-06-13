// AI 页面：AI 提问 + 历史记录 + 错题库概览 + 知识库。

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Theme } from '../theme/Theme';
import { UiStore } from '../store/UiStore';
import { GlassCard, EmptyView, LoadingView, SquishButton } from '../components/glass/GlassKit';
import { HtmlRichText } from '../components/HtmlRichText';
import { AiApi, AiAnswer, LibOverview, WrongQuestion } from '../net/api/AiApi';

const DOMAIN = 0x0002;
const TAG = 'AiPage';

@ComponentV2
export struct AiPage {
  ui: UiStore = UiStore.instance;

  @Local private tab: number = 0; // 0=问答, 1=错题库, 2=知识库
  @Local private question: string = '';
  @Local private asking: boolean = false;
  @Local private history: AiAnswer[] = [];
  @Local private loadingHistory: boolean = false;
  @Local private libs: LibOverview[] = [];
  @Local private loadingLibs: boolean = false;
  @Local private wrongQuestions: WrongQuestion[] = [];
  @Local private loadingWrong: boolean = false;
  @Local private selectedLibId: number = 0;

  aboutToAppear(): void {
    this.loadHistory();
  }

  private async loadHistory(): Promise<void> {
    this.loadingHistory = true;
    try {
      this.history = await AiApi.history(1, 50);
    } catch (e) {
      const err = e as Error;
      hilog.warn(DOMAIN, TAG, 'loadHistory failed: %{public}s', err.message);
    } finally {
      this.loadingHistory = false;
    }
  }

  private async doAsk(): Promise<void> {
    const q = this.question.trim();
    if (q.length === 0 || this.asking) {
      return;
    }
    this.asking = true;
    try {
      const answer = await AiApi.ask(q);
      this.history.unshift(answer);
      this.history = [...this.history];
      this.question = '';
    } catch (e) {
      const err = e as Error;
      hilog.error(DOMAIN, TAG, 'ask failed: %{public}s', err.message);
    } finally {
      this.asking = false;
    }
  }

  private async loadLibs(): Promise<void> {
    this.loadingLibs = true;
    try {
      this.libs = await AiApi.libOverview();
    } catch (e) {
      const err = e as Error;
      hilog.warn(DOMAIN, TAG, 'loadLibs failed: %{public}s', err.message);
    } finally {
      this.loadingLibs = false;
    }
  }

  private async loadWrongQuestions(libId: number): Promise<void> {
    this.selectedLibId = libId;
    this.loadingWrong = true;
    this.wrongQuestions = [];
    try {
      this.wrongQuestions = await AiApi.wrongQuestions(libId, 1, 100);
    } catch (e) {
      const err = e as Error;
      hilog.warn(DOMAIN, TAG, 'loadWrong failed: %{public}s', err.message);
    } finally {
      this.loadingWrong = false;
    }
  }

  @Builder
  tabBar() {
    Row({ space: 0 }) {
      ForEach(['AI 问答', '错题库', '知识库'], (label: string, idx: number) => {
        Text(label)
          .fontSize(Theme.F_BODY)
          .fontWeight(this.tab === idx ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.tab === idx ? Theme.PRIMARY : Theme.TEXT_2)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .borderRadius(Theme.R_XL)
          .backgroundColor(this.tab === idx ? Theme.PRIMARY_SOFT : Color.Transparent)
          .onClick(() => {
            this.tab = idx;
            if (idx === 1 && this.libs.length === 0) {
              this.loadLibs();
            }
            if (idx === 2 && this.libs.length === 0) {
              this.loadLibs();
            }
          })
      }, (label: string) => label)
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  askTab() {
    Column({ space: 12 }) {
      // Input area
      Row({ space: 8 }) {
        TextInput({ placeholder: '输入你的问题...', text: this.question })
          .layoutWeight(1)
          .height(44)
          .borderRadius(Theme.R_LG)
          .backgroundColor('#F0F2F5')
          .fontSize(Theme.F_BODY)
          .onChange((v: string) => {
            this.question = v;
          })
          .onSubmit(() => {
            this.doAsk();
          })

        SquishButton({
          onTap: () => {
            this.doAsk();
          }
        }) {
          Row() {
            if (this.asking) {
              LoadingProgress().width(18).height(18).color(Color.White)
            } else {
              SymbolGlyph($r('sys.symbol.arrow_up_circle'))
                .fontSize(22)
                .fontColor([Color.White])
            }
          }
          .width(44)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(Theme.PRIMARY)
          .borderRadius(22)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      // History
      if (this.loadingHistory) {
        LoadingView()
      } else if (this.history.length === 0) {
        EmptyView({ text: '还没有提问记录' })
      } else {
        List({ space: 8 }) {
          ForEach(this.history, (item: AiAnswer) => {
            ListItem() {
              Column() {
                GlassCard({ innerPadding: 14 }) {
                  Column({ space: 8 }) {
                    Text(item.question)
                      .fontSize(Theme.F_BODY)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Theme.TEXT)
                      .width('100%')

                    Text(item.answer)
                      .fontSize(Theme.F_BODY)
                      .fontColor(Theme.TEXT_2)
                      .width('100%')

                    Text(item.createTime)
                      .fontSize(Theme.F_MINI)
                      .fontColor(Theme.TEXT_3)
                      .width('100%')
                      .textAlign(TextAlign.End)
                  }
                  .width('100%')
                }
              }
              .width('100%')
            }
          }, (item: AiAnswer) => `ai_${item.id}`)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .padding({ left: 12, right: 12, bottom: 80 })
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  wrongTab() {
    if (this.loadingLibs) {
      LoadingView()
    } else if (this.selectedLibId === 0) {
      // Show lib list
      if (this.libs.length === 0) {
        EmptyView({ text: '暂无知识库' })
      } else {
        List({ space: 8 }) {
          ForEach(this.libs, (lib: LibOverview) => {
            ListItem() {
              Column() {
                GlassCard({ innerPadding: 14 }) {
                  Row({ space: 12 }) {
                    Column({ space: 3 }) {
                      Text(lib.libName ?? `知识库 ${lib.id}`)
                        .fontSize(Theme.F_BODY)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Theme.TEXT)
                      Text(`总题 ${lib.totalCount} · 错题 ${lib.wrongCount}`)
                        .fontSize(Theme.F_MINI)
                        .fontColor(Theme.TEXT_3)
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)

                    if (lib.correctRate !== null) {
                      Text(lib.correctRate)
                        .fontSize(Theme.F_BODY)
                        .fontColor(Theme.SUCCESS)
                        .fontWeight(FontWeight.Bold)
                    }

                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([Theme.TEXT_3])
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                }
              }
              .width('100%')
              .onClick(() => {
                this.loadWrongQuestions(lib.id);
              })
            }
          }, (lib: LibOverview) => `lib_${lib.id}`)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .padding({ left: 12, right: 12, bottom: 80 })
      }
    } else {
      // Show wrong questions for selected lib
      Column() {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(18)
            .fontColor([Theme.PRIMARY])
          Text('返回知识库')
            .fontSize(Theme.F_BODY)
            .fontColor(Theme.PRIMARY)
        }
        .padding({ left: 12, top: 8, bottom: 8 })
        .onClick(() => {
          this.selectedLibId = 0;
          this.wrongQuestions = [];
        })

        if (this.loadingWrong) {
          LoadingView()
        } else if (this.wrongQuestions.length === 0) {
          EmptyView({ text: '暂无错题' })
        } else {
          List({ space: 8 }) {
            ForEach(this.wrongQuestions, (wq: WrongQuestion) => {
              ListItem() {
                Column() {
                  GlassCard({ innerPadding: 14 }) {
                    Column({ space: 6 }) {
                      HtmlRichText({ html: wq.questionStem })
                      if (wq.answer !== null) {
                        Row({ space: 6 }) {
                          Text('正确答案')
                            .fontSize(Theme.F_SUB)
                            .fontColor(Theme.SUCCESS)
                          Text(wq.answer)
                            .fontSize(Theme.F_SUB)
                            .fontColor(Theme.TEXT)
                        }
                      }
                      if (wq.studentAnswer !== null) {
                        Row({ space: 6 }) {
                          Text('我的答案')
                            .fontSize(Theme.F_SUB)
                            .fontColor(Theme.DANGER)
                          Text(wq.studentAnswer)
                            .fontSize(Theme.F_SUB)
                            .fontColor(Theme.TEXT)
                        }
                      }
                      if (wq.wrongCause !== null && wq.wrongCause.length > 0) {
                        Text(`错因：${wq.wrongCause}`)
                          .fontSize(Theme.F_MINI)
                          .fontColor(Theme.TEXT_3)
                      }
                    }
                    .width('100%')
                  }
                }
                .width('100%')
              }
            }, (wq: WrongQuestion) => `wq_${wq.id}`)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .padding({ left: 12, right: 12, bottom: 80 })
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
  }

  build() {
    Column({ space: 8 }) {
      Text('AI 助手')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)
        .width('100%')
        .padding({ top: this.ui.topSafeVp + 12, left: 20, right: 20, bottom: 4 })

      this.tabBar()

      if (this.tab === 0) {
        this.askTab()
      } else {
        this.wrongTab()
      }
    }
    .width('100%')
    .height('100%')
  }
}
