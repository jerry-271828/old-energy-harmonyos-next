// 待办列表管理（bdfz_todo_list）+ 高考倒计时 + 学习计时器。
// 待办列表 = 简单 JSON 数组存 GmStorage；高考日期硬编码每年 6.7。

import { GmStorage } from '../bridge/GmStorage';

const TODO_KEY = 'bdfz_todo_list';

export interface TodoItem {
  id: string;
  text: string;
  done: boolean;
  createTime: number;
}

@ObservedV2
export class TodoStore {
  static readonly instance: TodoStore = new TodoStore();

  @Trace items: TodoItem[] = [];

  private constructor() {
  }

  load(): void {
    const raw = GmStorage.getSync(TODO_KEY);
    if (raw.length > 0) {
      try {
        this.items = JSON.parse(raw) as TodoItem[];
      } catch (e) {
        this.items = [];
      }
    }
  }

  add(text: string): void {
    this.items.unshift({
      id: `todo_${Date.now()}`,
      text: text,
      done: false,
      createTime: Date.now()
    });
    this.persist();
  }

  toggle(id: string): void {
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].id === id) {
        this.items[i].done = !this.items[i].done;
        break;
      }
    }
    this.items = [...this.items];
    this.persist();
  }

  remove(id: string): void {
    this.items = this.items.filter((item: TodoItem) => item.id !== id);
    this.persist();
  }

  private persist(): void {
    GmStorage.putAsync(TODO_KEY, JSON.stringify(this.items));
  }
}

export class GaokaoCountdown {
  static daysRemaining(): number {
    const now = new Date();
    let year = now.getFullYear();
    let gaokao = new Date(year, 5, 7); // June 7
    if (now.getTime() > gaokao.getTime()) {
      gaokao = new Date(year + 1, 5, 7);
    }
    const diff = gaokao.getTime() - now.getTime();
    return Math.ceil(diff / (1000 * 60 * 60 * 24));
  }
}

@ObservedV2
export class StudyTimer {
  static readonly instance: StudyTimer = new StudyTimer();

  @Trace seconds: number = 0;
  @Trace running: boolean = false;
  private timerId: number = -1;

  private constructor() {
  }

  start(): void {
    if (this.running) {
      return;
    }
    this.running = true;
    this.timerId = setInterval(() => {
      this.seconds++;
    }, 1000) as number;
  }

  pause(): void {
    this.running = false;
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  reset(): void {
    this.pause();
    this.seconds = 0;
  }

  formatted(): string {
    const h = Math.floor(this.seconds / 3600);
    const m = Math.floor((this.seconds % 3600) / 60);
    const s = this.seconds % 60;
    if (h > 0) {
      return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    }
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }
}
