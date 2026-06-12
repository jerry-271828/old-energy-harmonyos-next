// UI 仓库：窗口尺寸/断点（平板双栏 vs 手机单栏）与安全区高度。
// EntryAbility 在 windowStage 回调里喂数据。

@ObservedV2
export class UiStore {
  static readonly instance: UiStore = new UiStore();

  @Trace windowWidthVp: number = 1280;
  @Trace windowHeightVp: number = 800;
  @Trace topSafeVp: number = 0;        // 状态栏高度（沉浸式布局下内容自行避让）
  @Trace bottomSafeVp: number = 0;     // 导航条高度

  private constructor() {
  }

  // 宽屏（平板/2in1 横屏）→ 双栏布局；阈值取 840vp（官方推荐 lg 断点）
  @Computed
  get isWide(): boolean {
    return this.windowWidthVp >= 840;
  }

  // 中屏（竖屏平板）→ 目录树可抽屉化
  @Computed
  get isMedium(): boolean {
    return this.windowWidthVp >= 600 && this.windowWidthVp < 840;
  }
}
