// 待办 + 高考倒计时 + 学习计时器 面板（NavDestination）。

import { Theme } from '../theme/Theme';
import { UiStore } from '../store/UiStore';
import { Nav } from '../utils/Nav';
import { GlassCard, SquishButton, EmptyView } from '../components/glass/GlassKit';
import { TodoStore, TodoItem, GaokaoCountdown, StudyTimer } from '../store/TodoStore';

@ComponentV2
export struct TodoPanel {
  // 必须用 @Local 持有这些 @ObservedV2 单例：@ComponentV2 里「常规（无装饰器）成员变量」
  // 不被观察——初始化后不再响应变化，导致计时器秒数自增、待办增删都不触发本页重渲染
  // （只有返回再进、aboutToAppear 重新读取时才更新）。@Local + @ObservedV2/@Trace 才建立深度观察。
  @Local ui: UiStore = UiStore.instance;
  @Local todo: TodoStore = TodoStore.instance;
  @Local timer: StudyTimer = StudyTimer.instance;

  @Local private newTodoText: string = '';
  @Local private gaokaoDay: number = 0;

  aboutToAppear(): void {
    this.todo.load();
    this.gaokaoDay = GaokaoCountdown.daysRemaining();
  }

  private addTodo(): void {
    const t = this.newTodoText.trim();
    if (t.length === 0) {
      return;
    }
    this.todo.add(t);
    this.newTodoText = '';
  }

  @Builder
  countdownCard() {
    Column() {
      GlassCard({ innerPadding: 20 }) {
        Column({ space: 8 }) {
          Text('高考倒计时')
            .fontSize(Theme.F_SUB)
            .fontColor(Theme.TEXT_2)
          Text(`${this.gaokaoDay}`)
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.PRIMARY)
          Text('天')
            .fontSize(Theme.F_BODY)
            .fontColor(Theme.TEXT_2)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
  }

  @Builder
  timerCard() {
    Column() {
      GlassCard({ innerPadding: 16 }) {
      Column({ space: 10 }) {
        Text('学习计时')
          .fontSize(Theme.F_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)

        Text(this.timer.formatted())
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.timer.running ? Theme.PRIMARY : Theme.TEXT_2)
          .fontFamily('monospace')

        Row({ space: 12 }) {
          SquishButton({
            onTap: () => {
              if (this.timer.running) {
                this.timer.pause();
              } else {
                this.timer.start();
              }
            }
          }) {
            Text(this.timer.running ? '暂停' : '开始')
              .fontSize(Theme.F_BODY)
              .fontColor(Color.White)
              .padding({ left: 24, right: 24, top: 8, bottom: 8 })
              .backgroundColor(this.timer.running ? Theme.WARN : Theme.PRIMARY)
              .borderRadius(Theme.R_XL)
          }

          if (this.timer.seconds > 0) {
            SquishButton({
              onTap: () => {
                this.timer.reset();
              }
            }) {
              Text('重置')
                .fontSize(Theme.F_BODY)
                .fontColor(Theme.TEXT_2)
                .padding({ left: 24, right: 24, top: 8, bottom: 8 })
                .backgroundColor('#F0F2F5')
                .borderRadius(Theme.R_XL)
            }
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
  }

  @Builder
  todoList() {
    Column() {
      GlassCard({ innerPadding: 16 }) {
      Column({ space: 10 }) {
        Text('待 办')
          .fontSize(Theme.F_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
          .width('100%')

        Row({ space: 8 }) {
          TextInput({ placeholder: '添加待办事项...', text: this.newTodoText })
            .layoutWeight(1)
            .height(40)
            .borderRadius(Theme.R_LG)
            .backgroundColor('#F0F2F5')
            .fontSize(Theme.F_BODY)
            .onChange((v: string) => {
              this.newTodoText = v;
            })
            .onSubmit(() => {
              this.addTodo();
            })

          SymbolGlyph($r('sys.symbol.plus_circle'))
            .fontSize(28)
            .fontColor([Theme.PRIMARY])
            .onClick(() => {
              this.addTodo();
            })
        }
        .width('100%')

        if (this.todo.items.length === 0) {
          Text('暂无待办')
            .fontSize(Theme.F_SUB)
            .fontColor(Theme.TEXT_3)
            .padding(12)
        } else {
          ForEach(this.todo.items, (item: TodoItem) => {
            Row({ space: 10 }) {
              Checkbox()
                .select(item.done)
                .selectedColor(Theme.PRIMARY)
                .width(20)
                .height(20)
                .onChange((_v: boolean) => {
                  this.todo.toggle(item.id);
                })

              Text(item.text)
                .fontSize(Theme.F_BODY)
                .fontColor(item.done ? Theme.TEXT_3 : Theme.TEXT)
                .decoration(item.done ? {
                  type: TextDecorationType.LineThrough,
                  color: Theme.TEXT_3
                } : { type: TextDecorationType.None })
                .layoutWeight(1)

              SymbolGlyph($r('sys.symbol.trash'))
                .fontSize(16)
                .fontColor([Theme.TEXT_3])
                .onClick(() => {
                  this.todo.remove(item.id);
                })
            }
            .width('100%')
            .padding({ top: 6, bottom: 6 })
          }, (item: TodoItem) => `${item.id}_${item.done ? 1 : 0}`)
        }
      }
      .width('100%')
      }
    }
    .width('100%')
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Row({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(24)
              .fontColor([Theme.TEXT])
              .onClick(() => {
                Nav.pop();
              })
            Text('工具箱')
              .fontSize(Theme.F_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.TEXT)
              .layoutWeight(1)
          }
          .width('100%')

          this.countdownCard()
          this.timerCard()
          this.todoList()
        }
        .width('100%')
        .padding({
          left: 20, right: 20,
          top: this.ui.topSafeVp + 12,
          bottom: 40
        })
        .constraintSize({ maxWidth: 600 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
      .backgroundColor(Theme.BG_CREAM)
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      Nav.pop();
      return true;
    })
  }
}
