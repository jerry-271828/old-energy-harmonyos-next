import { common } from '@kit.AbilityKit';
import { RawFile } from './RawFile';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001;
const TAG = 'ScriptBuilder';

// 早期包：必须在页面脚本前就绪（GM_* shim、viewport/safe-area 修复、pinyin 依赖）。
// 体积小（~85KB），走 javaScriptOnDocumentStart 安全。
const EARLY: string[] = [
  'gm_shim.js',
  'viewport_fix.js',
  'pinyin-match.js'
];

// 延迟包：每个 userscript 一条，带上原文件 ==UserScript== 头里的 @match 模式。
// 注入时根据当前页 URL 过滤——还原 Tampermonkey 的语义，避免 pack2.js
// 这种"只在 /pdf/web*"运行的脚本被注入到登录页，导致 PDF 页的浮动批注
// UI 因初始化在错误 DOM 上而失效（点笔图标只变色不出工具栏）。
interface ScriptDef {
  name: string;
  patterns: string[];
}

const DEFERRED: ScriptDef[] = [
  {
    name: 'main_pack.js',
    patterns: [
      '*://bdfz.xnykcxt.com:5002/stu/*',
      '*://byfz.xnykcxt.com:5002/stu/*',
      '*://xnykcxt.com:5002/stu/*',
      '*://xnykcxt.com:5003/stu/*'
    ]
  },
  {
    name: 'pack2.js',
    patterns: [
      '*://*/pdf/web*',
      '*://*/*/pdf/web*'
    ]
  }
];

export interface UserScript {
  name: string;
  content: string;
  patterns: string[];
}

export interface InjectionBundle {
  early: string;
  scripts: UserScript[];
}

export class ScriptBuilder {
  static async build(ctx: common.UIAbilityContext): Promise<InjectionBundle> {
    const early = await ScriptBuilder.concat(ctx, EARLY);
    const scripts: UserScript[] = [];
    for (const def of DEFERRED) {
      const t0 = Date.now();
      const content = await RawFile.read(ctx, def.name);
      hilog.info(DOMAIN, TAG, 'loaded %{public}s (%{public}d bytes, %{public}dms, patterns=%{public}d)',
        def.name, content.length, Date.now() - t0, def.patterns.length);
      scripts.push({ name: def.name, content, patterns: def.patterns });
    }
    hilog.info(DOMAIN, TAG, 'bundles ready: early=%{public}d bytes, deferred-scripts=%{public}d',
      early.length, scripts.length);
    return { early, scripts };
  }

  // Tampermonkey @match 简化匹配：'*' 通配。已逐条 patterns 跑过逻辑测试。
  // - 不区分 scheme/host/path 三段，整串当 glob 比较——对我们目前的几条
  //   pattern 是充要的（域名带 host 全名、PDF 路径用 */pdf/web*）。
  static matchesUrl(url: string, patterns: string[]): boolean {
    if (!url || url.length === 0) {
      return false;
    }
    for (let i = 0; i < patterns.length; i++) {
      const re = ScriptBuilder.patternToRegExp(patterns[i]);
      if (re.test(url)) {
        return true;
      }
    }
    return false;
  }

  private static patternToRegExp(pattern: string): RegExp {
    // 先把正则元字符转义（保留 '*' 留给后续替换为 '.*'）。
    // 字符类里用显式 \[ \] \\，避开 ArkTS strict 解析对未转义中括号的歧义。
    const escaped = pattern.replace(/[.+?^${}()|\[\]\\]/g, '\\$&').replace(/\*/g, '.*');
    return new RegExp('^' + escaped + '$');
  }

  private static async concat(ctx: common.UIAbilityContext, names: string[]): Promise<string> {
    const parts: string[] = [];
    for (const name of names) {
      const t0 = Date.now();
      const src = await RawFile.read(ctx, name);
      hilog.info(DOMAIN, TAG, 'loaded %{public}s (%{public}d bytes, %{public}dms)',
        name, src.length, Date.now() - t0);
      parts.push(`/* ===== ${name} ===== */`);
      parts.push(src);
      parts.push(';');
    }
    return parts.join('\n');
  }
}
