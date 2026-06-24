// 设置仓库：兼容油猴脚本的存储键 bdfz_enhancer_settings_v3。
// 兼容细节：脚本侧 GM_setValue(key, JSON.stringify(settings))，而 gm_shim 又会
// JSON.stringify 一次落到 preferences——所以旧数据是"双重编码"的 JSON 字符串。
// 读取时做两层解包，写回时同样双重编码，保证 WebView 回退模式读到一致设置。

import { GmStorage } from '../bridge/GmStorage';

const SETTINGS_KEY = 'bdfz_enhancer_settings_v3';

interface SettingsData {
  autoLogin?: boolean;
  enableMockEnhance?: boolean;
  enableImageInvert?: boolean;
  enableAnswerForce?: boolean;
  lgIntensity?: number;
}

@ObservedV2
export class SettingsStore {
  static readonly instance: SettingsStore = new SettingsStore();

  @Trace autoLogin: boolean = true;
  @Trace enableMockEnhance: boolean = false;
  @Trace enableImageInvert: boolean = false;
  @Trace enableAnswerForce: boolean = false;
  @Trace lgIntensity: number = 1;

  private constructor() {
  }

  load(): void {
    const raw = GmStorage.getSync(SETTINGS_KEY);
    if (raw.length === 0) {
      return;
    }
    let data: SettingsData | null = null;
    try {
      const once: object = JSON.parse(raw) as object;
      if (typeof once === 'string') {
        data = JSON.parse(once as string) as SettingsData;   // 旧脚本的双重编码
      } else {
        data = once as SettingsData;                          // 原生直存
      }
    } catch (e) {
      return;
    }
    if (data === null) {
      return;
    }
    if (data.autoLogin !== undefined) {
      this.autoLogin = data.autoLogin;
    }
    if (data.enableMockEnhance !== undefined) {
      this.enableMockEnhance = data.enableMockEnhance;
    }
    if (data.enableImageInvert !== undefined) {
      this.enableImageInvert = data.enableImageInvert;
    }
    if (data.enableAnswerForce !== undefined) {
      this.enableAnswerForce = data.enableAnswerForce;
    }
    if (data.lgIntensity !== undefined) {
      this.lgIntensity = data.lgIntensity;
    }
  }

  save(): void {
    const data: SettingsData = {
      autoLogin: this.autoLogin,
      enableMockEnhance: this.enableMockEnhance,
      enableImageInvert: this.enableImageInvert,
      enableAnswerForce: this.enableAnswerForce,
      lgIntensity: this.lgIntensity
    };
    // 双重编码，保持与 gm_shim + 脚本的旧格式互通
    GmStorage.putAsync(SETTINGS_KEY, JSON.stringify(JSON.stringify(data)));
  }
}
