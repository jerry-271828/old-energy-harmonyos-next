// Liquid Glass 基础组件族：玻璃卡片 / 揉搓按钮 / 红点 / 空态 / 加载态。
// 「物理揉搓」：按压时弹簧缩放（lgIntensity 越高动效越夸张），对应油猴
// makeRubbable / applySquishToElement 的原生化。

import { Theme } from '../../theme/Theme';
import { SettingsStore } from '../../store/SettingsStore';
import { curves } from '@kit.ArkUI';

@Builder
export function GlassEmptyBuilder() {
}

// 玻璃卡片容器：半透明底 + 组件级模糊 + 高光描边
@ComponentV2
export struct GlassCard {
  @BuilderParam content: () => void = GlassEmptyBuilder;
  @Param radius: number = Theme.R_XL;
  @Param innerPadding: Length = 16;
  @Param surfaceColor: ResourceColor = Theme.SURFACE;

  build() {
    Column() {
      this.content()
    }
    .padding(this.innerPadding)
    .backgroundColor(this.surfaceColor)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(this.radius)
    .border({ width: 1, color: '#4DFFFFFF' })
    .shadow(Theme.GLASS_SHADOW)
    .clip(true)
  }
}

// 揉搓按钮：包裹任意内容，按下弹性下陷
@ComponentV2
export struct SquishButton {
  @BuilderParam content: () => void = GlassEmptyBuilder;
  @Param onTap: () => void = () => {};
  @Local pressScale: number = 1;

  private squishDepth(): number {
    const lv = SettingsStore.instance.lgIntensity;
    if (lv >= 3) {
      return 0.86;
    }
    if (lv >= 2) {
      return 0.90;
    }
    return 0.94;
  }

  build() {
    Column() {
      this.content()
    }
    .scale({ x: this.pressScale, y: this.pressScale })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.getUIContext().animateTo(
          { curve: curves.springMotion(0.22, 0.9) },
          () => {
            this.pressScale = this.squishDepth();
          });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.getUIContext().animateTo(
          { curve: curves.springMotion(0.32, 0.6) },
          () => {
            this.pressScale = 1;
          });
      }
    })
    .onClick(() => {
      this.onTap();
    })
  }
}

// 红点
@ComponentV2
export struct RedDot {
  @Param show: boolean = false;
  @Param dotSize: number = 8;

  build() {
    if (this.show) {
      Circle({ width: this.dotSize, height: this.dotSize })
        .fill(Theme.RED_DOT)
        .shadow({ radius: 4, color: '#66FF4D4F' })
    }
  }
}

// 空态
@ComponentV2
export struct EmptyView {
  @Param text: string = '暂无数据';

  build() {
    Column({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.doc_plaintext'))
        .fontSize(44)
        .fontColor([Theme.TEXT_3])
      Text(this.text)
        .fontSize(Theme.F_SUB)
        .fontColor(Theme.TEXT_3)
    }
    .width('100%')
    .padding(40)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

// 加载态
@ComponentV2
export struct LoadingView {
  @Param text: string = '加载中...';

  build() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(42)
        .height(42)
        .color(Theme.PRIMARY)
      Text(this.text)
        .fontSize(Theme.F_SUB)
        .fontColor(Theme.TEXT_2)
    }
    .width('100%')
    .padding(40)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
