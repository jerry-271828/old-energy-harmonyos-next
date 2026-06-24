# betterxny-hm · 鸿蒙适配版

把 `com.example.xny`（爆改新能源 5.0，原作者「程序猿」）移植到 **HarmonyOS NEXT**。原 App 是个 Android WebView 壳 + 油猴脚本；鸿蒙版已**全面原生化**——登录 / 课程 / 考试 / AI 问答 / 收藏 / 课件详情 / 快捷提交 / PDF 批注 / 搜索 / 待办 均用 ArkUI 原生实现，只在「网页版兼容模式」里保留完整的 WebView + 油猴注入链路作为回退。

> 目标 SDK: **HarmonyOS 6.1.0 (API 23)** · 最低 API: 21 · 模型: Stage · 语言: ArkTS / ArkUI
> Bundle: `com.betterxny.hm` · Version: 1.1.0 · Label: 爆改新能源

---

## 架构总览

```
Navigation(Nav.stack)           ← @Entry Index.ets
├─ booting    → 开屏 loading（自动登录进行中）
├─ 未登录     → LoginPage（原生玻璃卡片登录）
└─ 已登录     → HdsTabs 底部悬浮页签（Liquid Glass）
                 ├─ Tab 0  CoursePage       课程（教师→目录→课件）
                 ├─ Tab 1  ExamPage         考试（同构）
                 ├─ Tab 2  AiPage           AI 问答 / 错题库 / 知识库
                 ├─ Tab 3  CollectionPage   收藏 / 标签管理
                 └─ Tab 4  SettingsPage     油猴设置项原生化 + 退出
NavDestination 推栈：
  ├─ CourseDetailPage    课件详情（富文本/附件/答题/快捷提交/手写批注）
  ├─ AttachmentViewerPage PDF/Office/视频/图片 全屏预览 + Pen Kit 批注
  ├─ WebShellPage        网页版兼容模式（完整 WebView + 油猴注入）
  ├─ SearchSpotlight     全局拼音/首字母搜索
  ├─ TodoPanel           待办 + 高考倒计时 + 学习计时器
  └─ FloatPdfWindow      浮动 PDF 窗口（WebShellPage 内）
```

核心模块：

| 层 | 目录 | 职责 |
|---|------|------|
| 网络 | `net/ApiClient.ets` + `net/api/*.ets` | 统一 HTTP 客户端（DES/ECB 认证头）、各业务 API（Auth/Study/User/Ai/Collect/Reddot/Ask/Atta/Notes/Qwc） |
| 数据模型 | `models/*.ets` | ApiTypes / User / Course / Catalog / Question |
| 状态 | `store/*.ets` | SessionStore（登录态/会话守护）、SettingsStore、TodoStore、UiStore |
| 组件 | `components/*.ets` | GlassKit（玻璃卡片/揉搓按钮/红点/空态）、CatalogTree、HtmlRichText、QuickSubmitSheet、HandwritePanel、AnnotationCanvas |
| 桥接 | `bridge/*.ets` | AndroidBridge / GmStorage / GmNotifier / GmHttp（仅 WebShellPage 使用） |
| 工具 | `utils/*.ets` | RawFile / ScriptBuilder / Nav / Des / Downloader / PinyinSearch / PhotoUploader / BrushEngineContext |
| 主题 | `theme/Theme.ets` | 设计令牌：米黄护眼底 / 大圆角 / 品牌蓝 / Liquid Glass |

---

## 网页版兼容模式（WebShellPage）

设置 → 关于 → 「打开网页版（兼容模式）」可进入完整 WebView 壳，保留油猴注入链路：

| # | 文件 | 作用 |
|---|------|------|
| 1 | `gm_shim.js` | `GM_addStyle / GM_getValue / GM_setValue / GM_xmlhttpRequest / GM_notification / unsafeWindow` |
| 2 | `viewport_fix.js` | 锁定 `width=device-width, viewport-fit=cover` |
| 3 | `pinyin-match.js` | `window.PinyinMatch`（main_pack 依赖）|
| 4 | `main_pack.js` | 主体 9135 行 |
| 5 | `pack2.js` | PDF 阅读器批注（`*/pdf/web*` 匹配自动生效）|

`GM_xmlhttpRequest` 优先走原生 `@kit.NetworkKit` 的 `http` 客户端（绕 CORS），失败时回退到页内 `fetch()`。

原生版未覆盖的长尾功能可临时回到这里使用。

---

## 在 DevEco Studio 中打开

1. **环境**：DevEco Studio **6.0.2 Release** 或更新，HarmonyOS SDK 6.1.0(23) 已就绪
2. `File → Open` 选 `harmony/` 目录
3. 等待 hvigor sync（首次需联网下 ohpm 包，约 30s ~ 2 min）
4. 配置签名：`File → Project Structure → Project → Signing Configs → Automatically generate signing`，让 DevEco 自动签
5. 选一台真机（推荐 Mate 70 / Pura 70 / 新款 nova / MateBook X Pro）或 NEXT 模拟器
6. `Run` ▶️ —— 应直接进入登录页

> ⚠️ 模拟器对 ArkWeb / Pen Kit 的支持有差异，且无相机；建议**真机调试**。

---

## 测试用例（手工）

| 项 | 操作 | 预期 |
|---|------|------|
| 登录 | 输入学号密码 → 登录 | 原生登录成功，进入课程页（HdsTabs 五页签） |
| 课程浏览 | 切换教师 → 展开目录 → 点课件 | 课件详情页正常渲染（富文本/附件/题目） |
| 快捷提交 | 课件详情 → 快捷提交 → 输入答案 | 答案正确填入未作答题 |
| 考试 | Tab 1 考试 → 同课程流程 | 试卷列表 / 详情正常 |
| AI 问答 | Tab 2 AI → 输入问题 | 返回 AI 回答，历史记录可查 |
| 收藏 | Tab 3 → 文件夹 → 收藏题目 | 列表加载、标签管理正常 |
| 拼音搜索 | 首页右上角搜索 → 输入 "wlx" | 匹配拼音以 w-l-x 开头的课程 |
| PDF 批注 | 附件预览 PDF → 点「批注」 | Pen Kit 手写层叠加，可画/橡皮/撤销，持久化 .hwt |
| 待办 | 首页右上角锤子 → TodoPanel | 待办列表 / 高考倒计时 / 学习计时器 |
| 持久化 | 设置中切个开关 → 杀进程 → 重开 | ��置保持 |
| 返回键 | 在二级页面点系统返回 | 回到上一页而不是直接退出 |
| 沉浸 | 任意页面 | 内容贯穿状态栏，无白边 |
| 网页版回退 | 设置 → 关于 → 打开网页版 | 进入 WebShellPage，油猴注入生效 |

---

## 内置自检页

`entry/src/main/resources/rawfile/selftest.html` 是开发期桥连通性自检页。在 `WebShellPage.ets` 中临时把 `ENTRY_URL` 改成

```
'resource://rawfile/selftest.html'
```

就能在不连 xnykcxt 服务器的前提下验证 `GM_*` 与 `AndroidBridge` 的四条通道。

---

## 打包 release

```bash
# 在 DevEco Studio 里:
Build → Build Hap(s)/APP(s) → Build APP(s)
```

产物在 `build/outputs/default/` 下，`.app` 文件可上传 AppGallery Connect。

`obfuscation-rules.txt` 保留**关键属性名 / 文件名白名单**（`AndroidBridge`、`getValue`、`xhrRequest` 等），全局 property obfuscation 没开 —— WebShellPage 兼容模式仍把 main_pack.js（2.2 MB）按字面值注入 WebView，ArkGuard 改名会破坏脚本。

---

## 已知限制 / 后续可做

- **未做暗色模式**：原生页面使用固定米黄色板（Theme.ets），WebShellPage 中脚本大量 `!important` 写死色值，原 App 也是 Off。
- **未做卡片 / 快捷方式 / Push**：原 App 没有。
- **Office 预览受限**：.xls/.xlsx 服务端不转换，不支持预览（与 Vue 前端一致）。
- **手写批注真机验证**：HandwriteComponent 透明叠加 PdfView 的手势归属、滚动标定需真机核对。

---

## 目录速览

```
harmony/
├─ AppScope/
│  ├─ app.json5                       bundleName=com.betterxny.hm, v1.1.0
│  └─ resources/base/{element/string.json, media/app_icon.png}
├─ entry/
│  ├─ src/main/
│  │  ├─ ets/
│  │  │  ├─ entryability/EntryAbility.ets          UIAbility 入口
│  │  │  ├─ entrybackupability/EntryBackupAbility.ets
│  │  │  ├─ pages/
│  │  │  │  ├─ Index.ets              Navigation 根页 + HdsTabs
│  │  │  │  ├─ LoginPage.ets          原生登录（玻璃卡片）
│  │  │  │  ├─ CoursePage.ets         课程（教师→目录→课件）
│  │  │  │  ├─ ExamPage.ets           考试
│  │  │  │  ├─ AiPage.ets             AI 问答 / 错题库 / 知识库
│  │  │  │  ├─ CollectionPage.ets     收藏 / 标签
│  │  │  │  ├─ SettingsPage.ets       设置 / 退出 / 网页版入口
│  │  │  │  ├─ CourseDetailPage.ets   课件详情（富文本/附件/答题）
│  │  │  │  ├─ AttachmentViewerPage.ets  PDF/视频/图片预览 + Pen Kit 批注
│  │  │  │  ├─ WebShellPage.ets       网页版兼容模式（WebView + 油猴）
│  │  │  │  ├─ FloatPdfWindow.ets     浮动 PDF 窗口
│  │  │  │  ├─ SearchSpotlight.ets    全局拼音搜索
│  │  │  │  └─ TodoPanel.ets          待办 / 倒计时 / 计时器
│  │  │  ├─ bridge/
│  │  │  │  ├─ AndroidBridge.ets      JS 调用面（仅 WebShellPage）
│  │  │  │  ├─ GmStorage.ets          preferences (gm_storage)
│  │  │  │  ├─ GmNotifier.ets         notificationManager
│  │  │  │  └─ GmHttp.ets             http + runJavaScript 回调
│  │  │  ├─ net/
│  │  │  │  ├─ ApiClient.ets          统一 HTTP（DES 认证 + 会话守护）
│  │  │  │  └─ api/                   Auth/Study/User/Ai/Collect/Reddot/Ask/Atta/Notes/Qwc
│  │  │  ├─ models/                   ApiTypes / User / Course / Catalog / Question
│  │  │  ├─ store/                    SessionStore / SettingsStore / TodoStore / UiStore
│  │  │  ├─ components/
│  │  │  │  ├─ glass/GlassKit.ets     玻璃卡片 / 揉搓按钮 / 红点 / 空态 / 加载态
│  │  │  │  ├─ CatalogTree.ets        目录树
│  │  │  │  ├─ HtmlRichText.ets       富文本渲染
│  │  │  │  ├─ QuickSubmitSheet.ets   快捷提交弹窗
│  │  │  │  ├─ HandwritePanel.ets     手写答题面板
│  │  │  │  └─ AnnotationCanvas.ets   批注画布
│  │  │  ├─ theme/Theme.ets           设计令牌（色板/字号/圆角）
│  │  │  └─ utils/
│  │  │     ├─ RawFile.ets / ScriptBuilder.ets
│  │  │     ├─ Nav.ets / Des.ets / Downloader.ets
│  │  │     ├─ PinyinSearch.ets / PhotoUploader.ets
│  │  │     └─ BrushEngineContext.ts
│  │  ├─ resources/
│  │  │  ├─ base/{element, media, profile/main_pages.json, profile/backup_config.json}
│  │  │  └─ rawfile/
│  │  │     ├─ gm_shim.js / viewport_fix.js   ← 新写
│  │  │     ├─ pinyin-match.js                 ← 拷自原 APK
│  │  │     ├─ main_pack.js                    ← 拷自原 APK (2.2 MB)
│  │  │     ├─ pack2.js                        ← 拷自原 APK
│  │  │     └─ selftest.html                   桥连通性自检
│  │  └─ module.json5                  权限(INTERNET/CAMERA/GET_NETWORK_INFO)
│  ├─ build-profile.json5
│  ├─ oh-package.json5
│  ├─ hvigorfile.ts
│  └─ obfuscation-rules.txt
├─ build-profile.json5                 compatibleSdk/targetSdk = 6.1.0(23)
├─ oh-package.json5
├─ hvigorfile.ts
├─ hvigor/hvigor-config.json5
└─ code-linter.json5
```

---

## 致谢

- 原 Android 端「爆改新能源」作者 **程序猿**
- 油猴脚本核心逻辑（`main_pack.js` / `pack2.js`）沿用于网页版兼容模式
