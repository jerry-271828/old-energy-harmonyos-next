/*
 * Pen Kit（手写套件）上下文配置。
 *
 * 官方手写套件的笔刷引擎在内部从 globalThis._brushEngineContext 读取
 * UIAbilityContext，因此 HandwriteComponent 挂载前必须先在 EntryAbility 里
 * 调用 BrushEngineContext.setContext(this.context)（对照官方 codelab 的
 * utils/ContextConfig.ts「在 EntryAbility 中设置 context」步骤）。
 *
 * 该全局属性的声明必须放在 .ts 文件里——ArkTS(.ets) 不允许对 globalThis
 * 做任意属性增广。
 */
import { common } from '@kit.AbilityKit';

declare namespace globalThis {
  let _brushEngineContext: common.UIAbilityContext;
}

export default class BrushEngineContext {
  static setContext(context: common.UIAbilityContext): void {
    globalThis._brushEngineContext = context;
  }

  static getContext(): common.UIAbilityContext {
    return globalThis._brushEngineContext;
  }
}
