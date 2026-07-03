# 爆改新能源 · HarmonyOS NEXT

把 `com.example.xny`（爆改新能源 5.0，原作者「Aushen」）移植到 **HarmonyOS NEXT**。

原 App 是 Android WebView 壳 + 油猴脚本；鸿蒙版以 **ArkTS/ArkUI 原生 UI** 为主体，直连后端 REST API（行为对照原 Vue 前端逆向而来），仅在「网页版兼容模式」中保留完整的 WebView 注入链路作为长尾功能回退。

- Bundle：`com.betterxny.hm` · Target SDK：6.1.1(24) · Compatible：6.1.0(23)
- 模型：Stage · 语言：ArkTS + ArkUI

---

## 功能特性

### 📚 课程与考试
- 教师列表 → 目录树 → 课件/试卷详情
- 富文本渲染（`HtmlRichText`，将 Quill HTML 转原生组件）
- 附件预览（`PdfView`、`Video`、`Image` 全屏查看）
- 题目作答：文本输入 / 拍照上传 / Pen Kit 手写
- 快捷提交面板（`QuickSubmitSheet`）
- 答案绑定附件（上传 → `bindAnswerAttachment`）
- 补交、错因选择
- 全局拼音/首字母搜索（`PinyinSearch`）

### ✍️ 手写与批注
- **Pen Kit 手写**：`HandwritePanel` 基于官方 `HandwriteComponent`+`HandwriteController`，支持笔刷/橡皮/撤销
- **PDF 批注**：`AnnotationCanvas` 叠加在 `PdfView` 上，批注以 JSON 持久化到本地
- 手写/批注可导出为 PNG 并上传

### 🤖 AI 与收藏
- AI 问答（与后端 AI API 交互）
- 错题库浏览
- 收藏夹管理（文件夹 + 标签）
- 红点提示（`ReddotApi`）

### ⚙️ 原生设置
- 油猴设置项原生化（`SettingsStore` 沿用 `bdfz_enhancer_settings_v3`）
- 玻璃组件揉搓力度调节
- 待办列表 + 高考倒计时 + 学习计时器
- 自动登录与会话守护（静默重登）

### 🌐 网页版兼容模式
- 完整 WebView + 油猴脚本注入链路
- `AndroidBridge` JS 桥（`getValue`/`setValue`/`xhrRequest`/`showNotification`/`openFloatPdf`）
- **浮动 PDF 窗口**：检测 `<iframe src*="/exam/pdf/web/viewer.html">` 后自动弹出浮窗，支持拖拽/缩放/最小化/最大化/关闭；通过 `WebCookieManager.configCookieSync` 预置跨路径 Cookie 解决认证问题
- `pack2.js` 批注工具自动注入到 PDF.js viewer

---

## 架构示意

```
Navigation 根页 (Index.ets)
├─ 开屏 loading（自动登录中）
├─ LoginPage（原生玻璃卡片登录）
└─ HdsTabs 五页签
   ├─ 课程 (CoursePage)
   ├─ 考试 (ExamPage)
   ├─ AI (AiPage)
   ├─ 收藏 (CollectionPage)
   └─ 设置 (SettingsPage)

NavDestination 二级页：
  CourseDetailPage / AttachmentViewerPage / WebShellPage
  SearchSpotlight / TodoPanel
```

核心层：

| 层 | 目录 | 职责 |
|---|---|---|
| 网络 | `net/ApiClient.ets` + `net/api/` | 统一 HTTP 客户端（DES/ECB 认证头）、各业务 API |
| 数据模型 | `models/` | ApiTypes / User / Course / Catalog / Question |
| 状态 | `store/` | SessionStore / SettingsStore / TodoStore / UiStore |
| 组件 | `components/` | GlassKit / CatalogTree / HtmlRichText / QuickSubmitSheet / HandwritePanel |
| 桥接 | `bridge/` | AndroidBridge / GmStorage / GmNotifier / GmHttp（仅 WebShellPage） |
| 工具 | `utils/` | RawFile / ScriptBuilder / Nav / Des / Downloader / PinyinSearch / PhotoUploader |

---

## 构建与运行

### 环境要求

- DevEco Studio **6.x Release**（推荐最新）
- HarmonyOS SDK **6.1.0(23)+**（API 23）
- 一台运行 HarmonyOS NEXT 的真机（Mata 70 / Pura 70 / nova 系列 / MateBook X Pro）

模拟器对 ArkWeb 和 Pen Kit 支持不完整，且无相机，建议真机调试。

### 步骤

```bash
# 1. 在 DevEco Studio 中打开
File → Open → 选 harmony/ 目录

# 2. 等待 hvigor sync（首次需联网下 ohpm 包）
# 3. 自动签名：File → Project Structure → Signing Configs → Automatically generate signing
# 4. 连接真机，点击 Run ▶️
```

### CI 构建

push 到 `main` 触发 GitHub Actions，用 HarmonyOS command-line-tools 构建未签名 HAP。详见 `.github/workflows/build-hap.yml`。

---

## 网页版兼容模式

设置 → 关于 → 「打开网页版（兼容模式）」进入 `WebShellPage`：

| 脚本 | 来源 | 作用 |
|---|---|---|
| `gm_shim.js` | 自写 | GM_\* API shim（`GM_addStyle` / `GM_getValue` / `GM_xmlhttpRequest` 等）|
| `viewport_fix.js` | 自写 | 安全区/视口修复 |
| `pinyin-match.js` | 拷自原 APK | `window.PinyinMatch` 依赖 |
| `main_pack.js` | 拷自原 APK (2.2 MB) | 主体功能脚本 |
| `pack2.js` | 拷自原 APK | PDF 阅读器批注工具（`*/pdf/web*` 匹配自动注入）|

`GM_xmlhttpRequest` 走原生 `@kit.NetworkKit` 的 `http` 客户端（绕 CORS），失败时回退到页内 `fetch()`。

---

## 已知限制

- 无暗色模式（原生页面固定米黄色板，WebShell 脚本 `!important` 写死色值）
- 无卡片/快捷方式/Push（原 App 没有）
- `.xls`/`.xlsx` 不支持预览（服务端不转换，与 Vue 前端一致）
- 手写批注手势归属需在真机上核对（`HandwriteComponent` 叠加 `PdfView` 的手势分层）

---

## 致谢

- 原 Android 端「爆改新能源」作者 **Aushen**
- `main_pack.js` / `pack2.js` 沿用于网页版兼容模式
