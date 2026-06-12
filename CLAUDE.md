# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

「爆改新能源」HarmonyOS NEXT 移植版（原 Android 应用 `com.example.xny` 的鸿蒙端口）。原 App 是 Android WebView 壳，全部功能由注入的油猴脚本实现；本项目**原样复用这些脚本**，只用 ArkTS/ArkUI 重写了壳层。

- 项目根目录是 `harmony/`（DevEco Studio 打开这个目录，不是仓库根）
- Bundle `com.betterxny.hm` · Stage 模型 · ArkTS/ArkUI
- SDK：`harmony/build-profile.json5` 实际锁定 compile/compatible/target = **6.0.1(21)**（README 顶部写的 6.0.2(22) 已过时，以 build-profile 为准）
- 入口 URL：`https://bdfz.xnykcxt.com:5002/stu/#/login`（`Index.ets` 的 `ENTRY_URL` 常量）

## 构建与开发

没有提交 hvigorw 命令行 wrapper，构建全部走 DevEco Studio（6.0.2 Release+）：

- 打开：`File → Open` 选 `harmony/` 目录，等 hvigor sync（首次需联网拉 ohpm 包）
- 签名：`File → Project Structure → Signing Configs → Automatically generate signing`
- 运行：选真机后 Run（模拟器对 ArkWeb 支持有差异且无相机，优先真机调试）
- Release 打包：`Build → Build Hap(s)/APP(s) → Build APP(s)`，产物在 `build/outputs/default/`
- Lint：DevEco 内置 code linter，规则在 `harmony/code-linter.json5`（@performance/recommended + @typescript-eslint/recommended）
- WebView 远程调试已开启（`setWebDebuggingAccess(true)`），可用 DevTools 审查页面

### 测试

没有单元测试（@ohos/hypium 仅存在于 devDependencies，无测试文件）。验证手段：

1. **桥自检页**：把 `Index.ets` 的 `ENTRY_URL` 临时改为 `'resource://rawfile/selftest.html'`，不连服务器即可逐条验证 GM_* / AndroidBridge 通道
2. **手工测试矩阵**：见 `harmony/README.md`「测试用例」表（注入生效、持久化、通知、PDF 批注、拼音搜索、返回键、沉浸式）
3. **注入探针**：`onPageEnd` 末尾自动执行 probe，在 hilog 里搜 `inject-probe` 可看 gm/bridge/pack2/viewport 的挂载状态

## 架构

脚本注入管线 + JS↔ArkTS 桥是全部核心，改动前务必通读以下链路：

```
EntryAbility.onCreate            → GmStorage.init + GmNotifier.init（必须先于 WebView，桥的 getValue 是同步读）
EntryAbility.onWindowStageCreate → 完全隐藏状态栏/导航栏（沉浸式，H5 独占全屏）
Index.ets (@Entry)
  ├─ ScriptBuilder.build()       → 从 rawfile 读脚本，分两个包：
  │    early    = gm_shim + viewport_fix + pinyin-match → javaScriptOnDocumentStart（每页、文档开始前）
  │    deferred = main_pack.js / pack2.js（各带 @match 模式）→ onPageEnd 按当前 URL 过滤后逐条 runJavaScript
  ├─ Web(javaScriptProxy: AndroidBridge)
  └─ FloatPdfWindow              ← main_pack.js 调 AndroidBridge.openFloatPdf(url) 时挂载
AndroidBridge.ets（JS 侧同名对象，方法名即 ABI）
  ├─ getValue/setValue   → GmStorage（preferences 库 'gm_storage'）
  ├─ showNotification    → GmNotifier（notificationManager）
  ├─ xhrRequest(json)    → GmHttp（NetworkKit http，异步；结果经 controller.runJavaScript
  │                         回调页内 window.__gm_xhr_resolve(id, payload)）
  └─ openFloatPdf(url)   → Index.ets 注册的静态回调 → 挂载/重建 FloatPdfWindow
```

- `gm_shim.js`（自写）把 GM_addStyle/GM_getValue/GM_setValue/GM_xmlhttpRequest/GM_notification/unsafeWindow 映射到 AndroidBridge；GM_xmlhttpRequest 优先原生 http（绕 CORS），桥不可用时回退页内 fetch()
- `FloatPdfWindow.ets`：第二个 Web 组件承载 PDF 浮窗（标题栏拖动、四角 resize、最小化/最大化）。只按 @match 注入 pack2.js，**故意不挂 AndroidBridge**（pack2 只用 GM_addStyle，且避免抢占 GmHttp 的单一 controller 绑定）。换 URL 时先卸载、60ms 后重建，保证 pack2 的注入守卫在新文档里是干净的

### 关键约束（违反即破坏功能）

1. **rawfile 里的油猴脚本不可修改**：`main_pack.js`（2.2MB）、`pack2.js`、`pinyin-match.js` 拷贝自原 APK。壳层必须适配脚本，不能反过来改脚本。可以改的只有自写的 `gm_shim.js` / `viewport_fix.js` / `selftest.html`
2. **桥的命名是 ABI**：JS 按名字调 `AndroidBridge.getValue/setValue/showNotification/xhrRequest/openFloatPdf`，与 `javaScriptProxy` 的 `name`/`methodList` 必须逐字一致；因脚本不可改，这些名字实际上永远不要动
3. **混淆保持关闭**（debug/release 均 `enable: false`）：脚本按字面值注入 WebView，ArkGuard 改名会破坏它们；`entry/obfuscation-rules.txt` 维护着桥方法与 rawfile 文件名白名单，以备将来开启
4. **不要给 deferred 脚本再包外层 IIFE 或共享 guard**：每个 userscript 自身已是带幂等守卫的 IIFE。历史教训：曾把 main_pack + pack2 拼成单包共享 guard，pack2 在登录页就置位守卫，到 PDF 页反而被短路（`Index.ets` 的 onPageEnd 注释记录了原因）
5. **@match 过滤硬编码在 `ScriptBuilder.ets` 的 DEFERRED 数组**：matchesUrl 是整串 glob 匹配（`*` → `.*`），新增脚本或调整 URL 模式都改这里
6. **GmHttp 只绑一个 WebviewController**：`bridge.attach()` 只在主 WebView 调用，浮窗不要调
7. GmHttp 把 PATCH 映射为 POST（此 API 版本的 ArkTS http 枚举没有 PATCH）
8. **不要开 WebDarkMode**：脚本里大量 `!important` 写死色值，强行暗色会冲突（原 App 同样关闭）。沉浸式安全区由 viewport_fix.js（早期注入）+ `SAFE_AREA_KICK`（onPageBegin 兜底）双保险处理

### README 滞后说明

`harmony/README.md`「已知限制」称未复刻 floatWebView——已过时，`FloatPdfWindow.ets` 已实现浮动 PDF 窗。下载逻辑确实仍只是 toast（`onDownloadStart`）。
