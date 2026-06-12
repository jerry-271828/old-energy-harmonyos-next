// 设计令牌：爆改新能源 Liquid Glass 设计语言的原生映射。
// 色板对照油猴脚本：米黄护眼底、24px 大圆角、玻璃卡片、品牌蓝。

export class Theme {
  // 颜色
  static readonly BG_CREAM: string = '#FAF6EC';
  static readonly BG_CREAM_DEEP: string = '#F3EDDF';
  static readonly SURFACE: string = '#F8FFFFFF';        // 玻璃卡片底（带透明度）
  static readonly SURFACE_SOLID: string = '#FFFFFF';
  static readonly PRIMARY: string = '#3367FF';
  static readonly PRIMARY_SOFT: string = '#1A3367FF';   // 10% 蓝
  static readonly TEXT: string = '#1F2329';
  static readonly TEXT_2: string = '#6B7280';
  static readonly TEXT_3: string = '#9CA3AF';
  static readonly DANGER: string = '#E94B4B';
  static readonly SUCCESS: string = '#52C41A';
  static readonly WARN: string = '#FAAD14';
  static readonly DIVIDER: string = '#14000000';
  static readonly RED_DOT: string = '#FF4D4F';

  // 圆角（脚本全局 24px 圆角语言）
  static readonly R_XL: number = 24;
  static readonly R_LG: number = 16;
  static readonly R_MD: number = 12;
  static readonly R_SM: number = 8;

  // 字号
  static readonly F_TITLE: number = 20;
  static readonly F_BODY: number = 15;
  static readonly F_SUB: number = 13;
  static readonly F_MINI: number = 11;

  // 玻璃投影
  static readonly GLASS_SHADOW: ShadowOptions = {
    radius: 18,
    color: '#22000000',
    offsetX: 0,
    offsetY: 6
  };
}
