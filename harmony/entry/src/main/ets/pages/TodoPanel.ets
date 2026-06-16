// 待办 + 高考倒计时 + 学习计时器 面板（NavDestination）。
//
// 实时刷新修复（第三次，终于对症）：根因不是 @Local，而是
//   ① 响应式读取被放在 GlassCard 的 @BuilderParam content 里——@ComponentV2 下
//      子组件 BuilderParam 边界不会随父状态变化重渲染（对照 AiPage：可用的列表是把
//      ForEach 放在 GlassCard 之外、GlassCard 只包每个静态条目）。
//   ② StudyTimer.seconds++ 是「深层 @Trace 原地改」，本仓未验证能跨对象观测；
//      可靠触发只有「组件自己的 @Local 整体重新赋值」（AiPage 的 history 即如此）。
// 故这里：把计时秒数/待办列表镜像进本组件 @Local，靠重新赋值驱动刷新；计时用本地
// 轮询把单例 StudyTimer 的值搬进镜像（单例仍负责跨页持久计时）；卡片玻璃样式内联，
// 不再走 GlassCard 的 BuilderParam。见 [[arkts-v2-plain-member-not-observed]]。

import { Theme } from '../theme/Theme';
import { UiStore } from '../store/UiStore';
import { Nav } from '../utils/Nav';
import { SquishButton } from '../components/glass/GlassKit';
import { TodoStore, TodoItem, GaokaoCountdown, StudyTimer } from '../store/TodoStore';

@ComponentV2
export struct TodoPanel {
  // 单例引用：仅用于动作调用与镜像取值，本身不依赖其响应式（刷新靠下面的 @Local 镜像）。
  ui: UiStore = UiStore.instance;
  todo: TodoStore = TodoStore.instance;
  timer: StudyTimer = StudyTimer.instance;

  @Local private newTodoText: string = '';
  @Local private gaokaoDay: number = 0;
  // 显示镜像（靠重新赋值触发重渲染）
  @Local private displaySeconds: number = 0;
  @Local private timerRunning: boolean = false;
  @Local private displayItems: TodoItem[] = [];

  private uiTick: number = -1;

  aboutToAppear(): void {
    this.todo.load();
    this.gaokaoDay = GaokaoCountdown.daysRemaining();
    this.syncTodo();
    this.displaySeconds = this.timer.seconds;
    this.timerRunning = this.timer.running;
    // 本地轮询把单例计时值搬进镜像 —— 单例的 setInterval 负责真正计时与跨页持久，
    // 这里只负责把最新值反映到 UI（@Local 重新赋值，可靠刷新）。
    this.uiTick = setInterval(() => {
      const s = this.timer.seconds;
      if (s !== this.displaySeconds) {
        this.displaySeconds = s;
      }
      const r = this.timer.running;
      if (r !== this.timerRunning) {
        this.timerRunning = r;
      }
    }, 500) as number;
  }

  aboutToDisappear(): void {
    if (this.uiTick >= 0) {
      clearInterval(this.uiTick);
      this.uiTick = -1;
    }
  }

  private syncTodo(): void {
    this.displayItems = this.todo.items.slice();
  }

  private addTodo(): void {
    const t = this.newTodoText.trim();
    if (t.length === 0) {
      return;
    }
    this.todo.add(t);
    this.newTodoText = '';
    this.syncTodo();
  }

  private fmt(sec: number): string {
    const h = Math.floor(sec / 3600);
    const m = Math.floor((sec % 3600) / 60);
    const s = sec % 60;
    if (h > 0) {
      return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    }
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }

  @Builder
  countdownCard() {
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
    .padding(20)
    .backgroundColor(Theme.SURFACE)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(Theme.R_XL)
    .border({ width: 1, color: '#4DFFFFFF' })
    .shadow(Theme.GLASS_SHADOW)
    .clip(true)
  }

  @Builder
  timerCard() {
    Column({ space: 10 }) {
      Text('学习计时')
        .fontSize(Theme.F_BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT)

      Text(this.fmt(this.displaySeconds))
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.timerRunning ? Theme.PRIMARY : Theme.TEXT_2)
        .fontFamily('monospace')

      Row({ space: 12 }) {
        SquishButton({
          onTap: () => {
            if (this.timer.running) {
              this.timer.pause();
            } else {
              this.timer.start();
            }
            this.timerRunning = this.timer.running;
            this.displaySeconds = this.timer.seconds;
          }
        }) {
          Text(this.timerRunning ? '暂停' : '开始')
            .fontSize(Theme.F_BODY)
            .fontColor(Color.White)
            .padding({ left: 24, right: 24, top: 8, bottom: 8 })
            .backgroundColor(this.timerRunning ? Theme.WARN : Theme.PRIMARY)
            .borderRadius(Theme.R_XL)
        }

        if (this.displaySeconds > 0) {
          SquishButton({
            onTap: () => {
              this.timer.reset();
              this.timerRunning = false;
              this.displaySeconds = 0;
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
    .padding(16)
    .backgroundColor(Theme.SURFACE)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(Theme.R_XL)
    .border({ width: 1, color: '#4DFFFFFF' })
    .shadow(Theme.GLASS_SHADOW)
    .clip(true)
  }

  @Builder
  todoList() {
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

      if (this.displayItems.length === 0) {
        Text('暂无待办')
          .fontSize(Theme.F_SUB)
          .fontColor(Theme.TEXT_3)
          .padding(12)
      } else {
        ForEach(this.displayItems, (item: TodoItem) => {
          Row({ space: 10 }) {
            Checkbox()
              .select(item.done)
              .selectedColor(Theme.PRIMARY)
              .width(20)
              .height(20)
              .onChange((_v: boolean) => {
                this.todo.toggle(item.id);
                this.syncTodo();
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
                this.syncTodo();
              })
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
        }, (item: TodoItem) => `${item.id}_${item.done ? 1 : 0}`)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Theme.SURFACE)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(Theme.R_XL)
    .border({ width: 1, color: '#4DFFFFFF' })
    .shadow(Theme.GLASS_SHADOW)
    .clip(true)
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
