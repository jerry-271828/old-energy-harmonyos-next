// 快捷提交数据管理（bdfz_quick_submit_data）。
// 油猴脚本的快捷提交弹窗数据结构：数组，每项含 entityId + courseName + kind。

import { GmStorage } from '../bridge/GmStorage';

const KEY = 'bdfz_quick_submit_data';

export interface QuickSubmitEntry {
  entityId: number;
  courseName: string;
  kind: string;  // 'course' | 'paper'
}

export class QuickSubmitStore {
  private static entries: QuickSubmitEntry[] = [];
  private static loaded: boolean = false;

  private static ensureLoaded(): void {
    if (QuickSubmitStore.loaded) {
      return;
    }
    QuickSubmitStore.loaded = true;
    const raw = GmStorage.getSync(KEY);
    if (raw.length === 0) {
      return;
    }
    try {
      QuickSubmitStore.entries = JSON.parse(raw) as QuickSubmitEntry[];
    } catch (e) {
      QuickSubmitStore.entries = [];
    }
  }

  static getAll(): QuickSubmitEntry[] {
    QuickSubmitStore.ensureLoaded();
    return [...QuickSubmitStore.entries];
  }

  static add(entry: QuickSubmitEntry): void {
    QuickSubmitStore.ensureLoaded();
    // dedupe by entityId
    QuickSubmitStore.entries = QuickSubmitStore.entries.filter(
      (e: QuickSubmitEntry) => e.entityId !== entry.entityId);
    QuickSubmitStore.entries.unshift(entry);
    if (QuickSubmitStore.entries.length > 20) {
      QuickSubmitStore.entries = QuickSubmitStore.entries.slice(0, 20);
    }
    QuickSubmitStore.persist();
  }

  static remove(entityId: number): void {
    QuickSubmitStore.ensureLoaded();
    QuickSubmitStore.entries = QuickSubmitStore.entries.filter(
      (e: QuickSubmitEntry) => e.entityId !== entityId);
    QuickSubmitStore.persist();
  }

  static clear(): void {
    QuickSubmitStore.entries = [];
    QuickSubmitStore.persist();
  }

  private static persist(): void {
    GmStorage.putAsync(KEY, JSON.stringify(QuickSubmitStore.entries));
  }
}
