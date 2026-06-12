import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'GmStorage';
const STORE_NAME = 'gm_storage';

export class GmStorage {
  private static store: preferences.Preferences | null = null;

  static init(ctx: common.UIAbilityContext): void {
    if (GmStorage.store !== null) {
      return;
    }
    try {
      GmStorage.store = preferences.getPreferencesSync(ctx, { name: STORE_NAME });
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'init failed: %{public}s', err.message);
    }
  }

  static getSync(key: string): string {
    const s = GmStorage.store;
    if (!s) {
      return '';
    }
    try {
      const raw = s.getSync(key, '');
      return typeof raw === 'string' ? raw : String(raw);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'getSync(%{public}s) failed: %{public}s', key, err.message);
      return '';
    }
  }

  static putAsync(key: string, value: string): void {
    const s = GmStorage.store;
    if (!s) {
      return;
    }
    try {
      s.putSync(key, value);
      s.flush().catch((err: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'flush failed: %{public}s', err.message);
      });
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'putSync(%{public}s) failed: %{public}s', key, err.message);
    }
  }
}
