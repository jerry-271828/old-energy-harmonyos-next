# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

「爆改新能源」HarmonyOS NEXT 移植版（原 Android 应用 `com.example.xny` 的鸿蒙端口）。

**重要：本项目已从「WebView 壳 + 油猴脚本」演进为原生优先的 ArkUI 应用。** 早期版本只是套壳跑原 APK 的三段油猴脚本；现在主体是用 ArkTS/ArkUI 重写的**原生 UI + 原生 REST 客户端**（直连后端，行为对照原 Vue 前端 `stu_app.js` 与油猴脚本逆向而来）。旧的 WebView+脚本注入链路**完整保留**，但已降级为隐藏的「网页版兼容模式」（`WebShellPage`），仅供原生未覆盖的长尾功能临时回退。

- 项目根目录是 `harmony/`（DevEco Studio 打开这个目录，不是仓库根）
- Bundle `com.betterxny.hm` · Label 爆改新能源 · Stage 模型 · ArkTS/ArkUI
- 后端：`https://bdfz.xnykcxt.com:5002`，API 都挂在 `/exam` 下（见 `ApiClient.BASE`）
- **SDK 以 `harmony/build-profile.json5` 为准**：compile/target = **6.1.1(24)**、compatible = **6.1.0(23)**。原生 UI 用到 `@kit.UIDesignKit` 的 `HdsTabs`（API 23 起），23 是实际地板。（`AppScope/app.json5` 里的 `minAPIVersion: 21` 已滞后；README 写的 6.0.2(22) 也过时。）

## 构建 / 运行 / 测试

仓库**未提交 hvigorw wrapper**，本地与 CI 走两条路：

- **本地（DevEco Studio 6.x+）**：`File → Open` 选 `harmony/`，等 hvigor sync；签名 `Project Structure → Signing Configs → Automatically generate signing`；选**真机** Run（模拟器对 ArkWeb 支持有差异且无相机）。Release：`Build → Build Hap(s)/APP(s)`。
- **命令行 / CI**（`.github/workflows/build-hap.yml`，push 到 `main` 触发）：用 HarmonyOS command-line-tools（自带内嵌 SDK），关键步骤：
  ```bash
  ohpm config set registry https://ohpm.openharmony.cn/ohpm/
  ohpm install --all                         # 工作目录 harmony/
  export DEVECO_SDK_HOME=$CLT/sdk            # CLT 内嵌 SDK 根（含 default/）
  hvigorw --mode module -p product=default -p buildMode=release assembleHap --no-daemon
  ```
  产物：`harmony/entry/build/default/outputs/**/*.hap`（**未签名**，装机需本地或 DevEco 重签）。
  - CI 内嵌 SDK 是 HarmonyOS 26.0.0(API 26 Beta)，不含 6.1.1(24)，所以 CI 用 `sed` 把 `compileSdkVersion`/`targetSdkVersion` 临时改成 `26.0.0(26.0.0)`（`compatibleSdkVersion` 仍 6.1.0(23)），源码 build-profile 不动以免破坏本地 API 24 构建。
  - 需要 JRE 17（打包/签名 jar 用）。`main` 构建后滚动发布到固定 `nightly` 预发布 Release。
- **Lint**：DevEco 内置 code linter，规则 `harmony/code-linter.json5`。
- **测试**：无单元测试（`@ohos/hypium` 仅在 devDependencies，无测试文件）。验证靠：① 真机手测；② WebView 兼容模式自检（把 `WebShellPage.ets` 的 `ENTRY_URL` 临时改成 `'resource://rawfile/selftest.html'` 验证 GM_*/AndroidBridge 四通道）；③ hilog 搜各模块 TAG（`ApiClient`/`SessionStore`/`WebShellPage`…）。

## 架构

### 启动与会话（改动前务必读懂这条链）

`EntryAbility.onCreate` 的初始化**顺序有约束**，不要随意调换：

```
GmStorage.init           → preferences 仓 'gm_storage'，必须最先（多个 Store 同步读它）
GmNotifier.init          → 通知
BrushEngineContext.setContext(this.context)   → Pen Kit 笔刷引擎从 globalThis 读 context，须先于任何 HandwriteComponent
SettingsStore/TodoStore.load → 同步读 GmStorage
SessionStore.init        → 装载 token/user 到 ApiClient，注册静默重登回调
SessionStore.tryAutoLogin → 后台自动登录（UI 由 booting 控制开屏）
Downloader.clearCache    → 清上次附件预览缓存
```

- `SessionStore`（`@ObservedV2` 单例）三个 `@Trace` 态驱动 `Index` 根 UI：`booting`（开屏 loading）→ `loggedIn` ? `mainTabs` : `LoginPage`。
- **自动登录乐观进入**：有缓存 token+user 就直接进主页、登录刷新丢后台；无缓存有凭据才做带 **8s 硬超时**的登录。这是「开屏卡死」的修复点——绝不阻塞首屏，token 失效由首个 API 401 的静默重登兜底。

### 原生网络层（`net/`）

- `ApiClient`（`@kit.NetworkKit` 的 `http`）是唯一 HTTP 客户端：
  - `ORIGIN = https://bdfz.xnykcxt.com:5002`，`BASE = ORIGIN + '/exam'`。
  - **认证靠 Cookie**：登录从响应头 `Set-Cookie: token=<hex>` 提取 token（`extractToken`），之后每个请求带 `Cookie: token=…`。
  - **统一响应包 `{code, message, extra}`**：`code===0` 成功、业务数据在 `extra`；`request()` 直接返回 `extra`，非 0 抛 `ApiError`。
  - **会话守护**：HTTP 401/403 或 message 含「登录/token」→ 回调 `reloginProvider`（`SessionStore` 注册的静默重登）重登一次再重试。
  - `assetUrl()`：静态资源绝对化——**附件明文路径 `/jyhr/...` 缺 `/exam` 段，必须补 `/exam` 否则 404**（近期修复点）。
  - 已知坑：此 SDK `http` 枚举**无 PATCH**，需要时映射 POST。`uploadFile()` 走 multipart（拍照/手写图上传）。
- `net/api/*` 每个文件包一个后端域，方法/请求体对照 Vue 源码逐条确认：`AuthApi`(登录登出) `StudyApi`(课件/考试，见下) `UserApi`(用户/我的教师) `CollectApi`(收藏) `AiApi`(AI 提问/错题库) `AskApi`(问答) `NotesApi`(笔记) `QwcApi`(错题原因) `AttaApi`(附件上传/图片增强) `ReddotApi`(红点)。`models/` 是这些接口的类型定义。
- **课件(course)与考试(paper)完全同构**：`StudyApi` 用 `StudyKind` 参数化，`StudyApi.course` / `StudyApi.paper` 两个单例共用一份实现；`CoursePage`(Tab0) 与 `ExamPage`(Tab1)、目录/列表/详情同理同构。

### 导航与 UI

- 单 `Navigation(Nav.stack)` 模型。`Index.ets`(`@Entry`) 用 `@kit.UIDesignKit` 的 `HdsTabs` 悬浮玻璃页签承载 5 个主 Tab（课程/考试/AI/收藏/设置）。
- 二级页一律 `NavDestination`，经 `Nav.push(name, param)` 入栈、`Index.pageMap(name)` 分发。已注册路由名：`webshell`(网页版兼容) `courseDetail` `search` `todo` `attachmentViewer`。
- `theme/Theme.ets` 是设计令牌（米黄护眼底、24px 大圆角、品牌蓝 `#3367FF`）；`components/glass/GlassKit.ets` 是玻璃组件族（`GlassCard`/`SquishButton`/`RedDot`/`EmptyView`/`LoadingView`，揉搓力度读 `SettingsStore.lgIntensity`）。复用组件还有 `HtmlRichText`（quill HTML→原生渲染）、`CatalogTree`（懒加载目录树）。

### 作答 / 提交契约（脆弱，逆向自后端，改动需真机验证）

`StudyApi` 的写接口字段是后端**必填硬契约**，缺字段会被判 `code 10000「请求参数错误」`：

- `saveAnswer` → `POST .../entity/{id}/question/{qid}`，body 必带 `studentAnswer`（多选**逗号分隔**）+ `resubmitTag` + `abandonTag`。`resubmitTag=1` 仅用于编辑已批阅/补交阶段（`mappingStatus===1`）的答案，否则 0；`abandonTag` 正常作答恒 0。**返回值是 boolean 不是作答记录——存完必须重新 `answers()` 拉最新状态**。
- `submit` → `POST .../submit`，body `{courseId|paperId}`。
- `resubmit`（补交）→ `POST .../resubmit`，**必带 `courseBeginTime`（= 列表项 `CourseListItem.createTime`，不是 `entityInfo.courseBeginTime`）**。
- 提交态从 `mappingStatus` 读。作答附件经 `bindAnswerAttachment`/`deleteAnswerAttachment`（GET `.../attachment/{aid}`）绑定/删除。

### 手写 / 下载 / 附件 / 拍照

- **Pen Kit 手写**（`@kit.Penkit`）：`HandwritePanel` 用官方 `HandwriteComponent`+`HandwriteController`，工具栏（笔刷/橡皮/撤销）套件内置。前置条件：`globalThis._brushEngineContext` 必须在挂载组件前由 `EntryAbility` 设好——这就是 `BrushEngineContext` **写成 `.ts` 而非 `.ets`** 的原因（ArkTS 不允许对 `globalThis` 任意增广）。导出：`getThumbnail(getContentRange())` → PNG → `AttaApi.upload`。（`AnnotationCanvas` 是另一回事：PDF 上的 Canvas 批注 overlay，本地 JSON 持久化。）
- **下载/附件**：`Downloader` 用 `http` 流式落盘到**沙箱缓存**，冷启动清一次（`EntryAbility`）。`AttachmentViewerPage`：PDF → 下到沙箱 → `PdfView`(`@kit.PDFKit`，**只认本地路径**)；视频 → `Video` 流式播网络地址。
- **拍照作答**：`PhotoUploader` = `cameraPicker`/`photoPicker` → 沙箱复制 → `AttaApi.upload` →（可选 `imgEnhance`）→ `bindAnswerAttachment`。需 `ohos.permission.CAMERA`（`module.json5` 已声明）。

### 持久化（原生与 WebView 两模式共享）

都落 `GmStorage`（preferences `'gm_storage'`），保证两模式状态一致：

- `SessionStore` 键前缀 `bxny_*`（token/account/pwd/remember/user_info）。
- `SettingsStore` **沿用油猴键 `bdfz_enhancer_settings_v3`**；注意旧数据是「双重编码」JSON 字符串（脚本侧 `GM_setValue(JSON.stringify)` + gm_shim 又 stringify 一次）。
- `TodoStore` 用 `bdfz_todo_list`（高考倒计时硬编码每年 6.7）。`UiStore` 不持久化，存窗口尺寸/断点（平板双栏 vs 手机单栏）/安全区高度，由 `EntryAbility` 的窗口回调喂数据。

### 旧 WebView 兼容模式（`WebShellPage` + `FloatPdfWindow`，约束仍生效）

入口：设置 → 关于 → 「打开网页版（兼容模式）」→ 路由 `webshell`，加载 `https://bdfz.xnykcxt.com:5002/stu/#/login`，注入油猴脚本。改动前先读 `ScriptBuilder.ets` 与 `WebShellPage.ets`：

```
ScriptBuilder.build()
  early    = gm_shim + viewport_fix + pinyin-match → javaScriptOnDocumentStart（每页、文档开始前）
  deferred = main_pack.js / pack2.js（各带 @match）→ onPageEnd 按当前 URL 逐条 runJavaScript
AndroidBridge（javaScriptProxy，方法名即 JS ABI）
  getValue/setValue → GmStorage ; showNotification → GmNotifier
  xhrRequest(json)  → GmHttp（http 异步，结果经 runJavaScript 回调 window.__gm_xhr_resolve）
  openFloatPdf(url) → 挂载 FloatPdfWindow（第二个 Web 承载 PDF 浮窗，故意不挂 AndroidBridge；★ 浮窗当前实际未生效，见文末「已知未完成」）
```

## 关键约束（违反即破坏功能）

1. **rawfile 里的油猴脚本不可修改**：`main_pack.js`(2.2MB)、`pack2.js`、`pinyin-match.js` 拷自原 APK；只能改自写的 `gm_shim.js`/`viewport_fix.js`/`selftest.html`。
2. **桥的命名是 ABI**：JS 按名字调 `AndroidBridge.getValue/setValue/showNotification/xhrRequest/openFloatPdf`，与 `javaScriptProxy` 的 `name`/`methodList` 必须逐字一致。
3. **混淆保持关闭**（debug/release 均 `enable: false`）：脚本按字面值注入；`entry/obfuscation-rules.txt` 维护桥方法与 rawfile 文件名白名单备用。
4. **deferred 脚本不要再包外层 IIFE/共享 guard**：每个 userscript 自身已是带幂等守卫的 IIFE（历史教训：拼包共享 guard 会让 pack2 在登录页置位、PDF 页被短路）。
5. **@match 过滤硬编码在 `ScriptBuilder.ets` 的 `DEFERRED`**：`matchesUrl` 整串 glob（`*`→`.*`），增删脚本/改 URL 模式都在这里。
6. **GmHttp 只绑一个 WebviewController**（`bridge.attach()` 仅主 WebView 调，浮窗不调）；PATCH 映射为 POST。
7. **不要开 WebDarkMode / WebView 全屏整窗隐藏**：脚本大量 `!important` 写死色值，暗色会冲突；原生版沉浸式是 `setWindowLayoutFullScreen(true)` 但**保留系统栏可见**（原生页面自己按安全区高度避让，与旧版整窗隐藏不同）。
8. **作答/提交契约**：见上节，字段缺失即 `code 10000`，改动须真机验证。
9. **Pen Kit context 必须先于组件挂载设置**；`BrushEngineContext` 保持 `.ts`。

## 文档滞后说明

`harmony/README.md` 仍按「纯 WebView 壳」描述（目标 SDK 6.0.2(22)、「没有复刻 floatWebView」、「下载逻辑仅 toast」）——**均已过时**：原生版是主体，下载/附件预览/拍照上传均已落地。以代码为准。

> **已知未完成**：`FloatPdfWindow.ets` 虽存在并被 `WebShellPage` 引用，但**浮动 PDF 实际尚未真正生效**——勿当作已完成功能（README 与本文件历史版本都曾误称「已实现」）。
