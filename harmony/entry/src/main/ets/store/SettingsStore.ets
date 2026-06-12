// 设置仓库：兼容油猴脚本的存储键 bdfz_enhancer_settings_v3。
// 兼容细节：脚本侧 GM_setValue(key, JSON.stringify(settings))，而 gm_shim 又会
// JSON.stringify 一次落到 preferences——所以旧数据是"双重编码"的 JSON 字符串。
// 读取时做两层解包，写回时同样双重编码，保证 WebView 回退模式读到一致设置。

import { GmStorage } from '../bridge/GmStorage';

const SETTINGS_KEY = 'bdfz_enhancer_settings_v3';

// 与油猴设置页一一对应（标题/语义见 main_pack.js settingDefs）
interface SettingsData {
  autoLogin?: boolean;             // 自动登录（脚本强制 true，这里允许关）
  enableHandwritingFix?: boolean;  // 手写优化：批注/作答时防页面滚动
  forceShowPDFButtons?: boolean;   // 开启下载权限（原生化为：显示 PDF 下载按钮）
  enableSmartHints?: boolean;      // 智能提示（脚本强制 false）
  enableMockEnhance?: boolean;     // 图片加速上传：跳过增强和剪裁
  enableImageInvert?: boolean;     // 图片反色
  enableAnswerForce?: boolean;     // 允许作答前看答案
  autoExpandAnswerArea?: boolean;  // 自动展开答题区
  enableNewSidebar?: boolean;      // 新侧栏
  enableIconBeautify?: boolean;    // 图标美化
  enableSimpleMode?: boolean;      // 简洁模式
  lgIntensity?: number;            // Liquid Glass / 沉浸光感强度 1-3
}

@ObservedV2
export class SettingsStore {
  static readonly instance: SettingsStore = new SettingsStore();

  @Trace autoLogin: boolean = true;
  @Trace enableHandwritingFix: boolean = true;
  @Trace forceShowPDFButtons: boolean = false;
  @Trace enableSmartHints: boolean = false;
  @Trace enableMockEnhance: boolean = false;
  @Trace enableImageInvert: boolean = false;
  @Trace enableAnswerForce: boolean = false;
  @Trace autoExpandAnswerArea: boolean = true;
  @Trace enableNewSidebar: boolean = true;
  @Trace enableIconBeautify: boolean = true;
  @Trace enableSimpleMode: boolean = true;
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
    if (data.enableHandwritingFix !== undefined) {
      this.enableHandwritingFix = data.enableHandwritingFix;
    }
    if (data.forceShowPDFButtons !== undefined) {
      this.forceShowPDFButtons = data.forceShowPDFButtons;
    }
    if (data.enableSmartHints !== undefined) {
      this.enableSmartHints = data.enableSmartHints;
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
    if (data.autoExpandAnswerArea !== undefined) {
      this.autoExpandAnswerArea = data.autoExpandAnswerArea;
    }
    if (data.enableNewSidebar !== undefined) {
      this.enableNewSidebar = data.enableNewSidebar;
    }
    if (data.enableIconBeautify !== undefined) {
      this.enableIconBeautify = data.enableIconBeautify;
    }
    if (data.enableSimpleMode !== undefined) {
      this.enableSimpleMode = data.enableSimpleMode;
    }
    if (data.lgIntensity !== undefined) {
      this.lgIntensity = data.lgIntensity;
    }
  }

  save(): void {
    const data: SettingsData = {
      autoLogin: this.autoLogin,
      enableHandwritingFix: this.enableHandwritingFix,
      forceShowPDFButtons: this.forceShowPDFButtons,
      enableSmartHints: this.enableSmartHints,
      enableMockEnhance: this.enableMockEnhance,
      enableImageInvert: this.enableImageInvert,
      enableAnswerForce: this.enableAnswerForce,
      autoExpandAnswerArea: this.autoExpandAnswerArea,
      enableNewSidebar: this.enableNewSidebar,
      enableIconBeautify: this.enableIconBeautify,
      enableSimpleMode: this.enableSimpleMode,
      lgIntensity: this.lgIntensity
    };
    // 双重编码，保持与 gm_shim + 脚本的旧格式互通
    GmStorage.putAsync(SETTINGS_KEY, JSON.stringify(JSON.stringify(data)));
  }
}
