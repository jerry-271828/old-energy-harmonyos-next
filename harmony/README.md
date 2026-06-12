# betterxny-hm · 鸿蒙适配版

把 `com.example.xny`（爆改新能源 5.0，原作者「程序猿」）的 **HarmonyOS NEXT** 端口。原 App 是个 Android WebView 壳，所有"爆改"功能都靠注入的三段油猴脚本实现（圆角 UI / 护眼配色 / 快捷提交 / 侧栏改造 / PDF 批注 / 登出动效……）；这份鸿蒙版完全复用原脚本，只重写了壳层。

> 目标 SDK: **HarmonyOS 6.0.2 (API 22)** · 模型: Stage · 语言: ArkTS / ArkUI
> Bundle: `com.betterxny.hm` · Label: 爆改新能源

---

## 工作原理

```
                  ┌──────────────────────────────────────────────┐
                  │  ArkUI @Entry Index.ets                       │
                  │                                               │
                  │     ┌────────────── Web ──────────────┐       │
                  │     │ src = bdfz.xnykcxt.com:5002/... │       │
                  │     │                                  │       │
                  │     │  javaScriptOnDocumentStart =     │       │
                  │     │    gm_shim + viewport_fix +      │       │
                  │     │    pinyin-match + main_pack +    │       │
                  │     │    pack2                          │       │
                  │     │                                  │       │
                  │     │  javaScriptProxy(AndroidBridge)  │       │
                  │     └──────────────┬──────────────────┘       │
                  └───────────────────┬┴──────────────────────────┘
                                      │
                                      ▼
            ┌───────────────────────────────────────────────────┐
            │  AndroidBridge.ets (JS 同名,无需改脚本)            │
            │    getValue(k)         → GmStorage (preferences)   │
            │    setValue(k,v)       → GmStorage (preferences)   │
            │    showNotification()  → GmNotifier (Notification) │
            │    xhrRequest(json)    → GmHttp (NetworkKit/http)  │
            │                            └─ 回调 runJavaScript()  │
            └───────────────────────────────────────────────────┘
```

注入顺序与原 Android 完全一致：

| # | 文件 | 作用 |
|---|------|------|
| 1 | `gm_shim.js` | `GM_addStyle / GM_getValue / GM_setValue / GM_xmlhttpRequest / GM_notification / unsafeWindow` |
| 2 | `viewport_fix.js` | 锁定 `width=device-width, viewport-fit=cover` |
| 3 | `pinyin-match.js` | `window.PinyinMatch`（main_pack 依赖）|
| 4 | `main_pack.js` | 主体 9135 行 |
| 5 | `pack2.js` | PDF 阅读器批注（`*/pdf/web*` 匹配自动生效）|

`GM_xmlhttpRequest` 优先走原生 `@kit.NetworkKit` 的 `http` 客户端（绕 CORS / 不受 WebView 同源限制），失败时回退到页内 `fetch()`。

---

## 在 DevEco Studio 中打开

1. **环境**：DevEco Studio **6.0.2 Release** 或更新，HarmonyOS SDK 6.0.2(22) 已就绪
2. `File → Open` 选 `harmony/` 目录
3. 等待 hvigor sync（首次需联网下 ohpm 包，约 30s ~ 2 min）
4. 配置签名：`File → Project Structure → Project → Signing Configs → Automatically generate signing`，让 DevEco 自动签
5. 选一台真机（推荐 Mate 70 / Pura 70 / 新款 nova / MateBook X Pro）或 NEXT 模拟器
6. `Run` ▶️ —— 应直接进入登录页

> ⚠️ 模拟器对 ArkWeb 的支持有差异，且无相机；建议**真机调试**。

---

## 测试用例（手工）

| 项 | 操作 | 预期 |
|---|------|------|
| 注入是否生效 | 登录页加载后看 UI | 输入框 / 按钮全部圆角，背景米黄 |
| 桥连通性 | 在 webview 控制台执行 `AndroidBridge.getValue('x')` | 返回空字符串而非 ReferenceError |
| 持久化 | 设置中切个开关 → 杀进程 → 重开 | 设置保持 |
| GM_xmlhttpRequest | 触发登出 / 提交习题 | 网络日志显示请求成功，UI 流畅 |
| GM_notification | 出现"提示"弹窗的脚本路径 | 鸿蒙系统通知出现 |
| PDF 批注 | 进入任意课件 PDF | 顶部出现批注工具栏，可手写 / 高亮 |
| 拼音搜索 | 在课程列表搜索 "wlx" | 能匹配到拼音以 w-l-x 开头的"网络学"等 |
| 返回键 | 在二级页面点系统返回 | 回到上一页而不是直接退出 |
| 沉浸 | 任意页面 | 内容贯穿状态栏，无白边 |

---

## 内置自检页

`entry/src/main/resources/rawfile/selftest.html` 是开发期桥连通性自检页。临时把 `Index.ets` 中的 `ENTRY_URL` 改成

```
'resource://rawfile/selftest.html'
```

就能在不连 xnykcxt 服务器的前提下点按钮验证 `GM_*` 与 `AndroidBridge` 的四条通道。

---

## 打包 release

```bash
# 在 DevEco Studio 里:
Build → Build Hap(s)/APP(s) → Build APP(s)
```

产物在 `build/outputs/default/` 下，`.app` 文件可上传 AppGallery Connect。

`obfuscation-rules.txt` 暂时只保留**关键属性名 / 文件名白名单**（`AndroidBridge`、`getValue`、`xhrRequest` 等），全局 property obfuscation 没开 —— 因为我们把整段 main_pack.js（2.2 MB）按字面值注入 WebView，ArkGuard 改名会破坏脚本。release 前再视体积评估是否分桶混淆 ArkTS 侧而不动 rawfile。

---

## 已知限制 / 后续可做

- **没有复刻 `floatWebView`**：原 App 用一个浮动 WebView 单独承载 PDF 弹层；首版用同一个 WebView 处理 `*/pdf/web*`，pack2.js 直接生效。如确需独立浮窗，可在 `Index.ets` 增加 `bindContentCover` + 第二个 `Web` 控件。
- **下载逻辑未完整**：`onDownloadStart` 仅 toast；如需自动落地到下载目录，调 `request.agent.create` + `Mode.BACKGROUND`。
- **未做暗色模式**：脚本里大量 `!important` 写死了色值，强行 `darkMode(WebDarkMode.On)` 会冲突，原 App 也是 Off。
- **未做卡片 / 快捷方式 / Push**：原 App 没有。
- **API 22 mention**：如需向下兼容 API 20/12，把 `javaScriptOnDocumentStart` 换成 `onControllerAttached` + `controller.runJavaScript`，注入时机会晚一点（首屏可能闪一下圆角才生效）。

---

## 目录速览

```
harmony/
├─ AppScope/
│  ├─ app.json5                                  bundleName=com.betterxny.hm
│  └─ resources/base/{element/string.json, media/app_icon.png}
├─ entry/
│  ├─ src/main/
│  │  ├─ ets/
│  │  │  ├─ entryability/EntryAbility.ets        UIAbility 入口
│  │  │  ├─ entrybackupability/EntryBackupAbility.ets
│  │  │  ├─ pages/Index.ets                       Web 容器 + 注入 + 桥
│  │  │  ├─ bridge/
│  │  │  │  ├─ AndroidBridge.ets                 JS 调用面: getValue/setValue/showNotification/xhrRequest
│  │  │  │  ├─ GmStorage.ets                     preferences (gm_storage)
│  │  │  │  ├─ GmNotifier.ets                    notificationManager
│  │  │  │  └─ GmHttp.ets                        http.createHttp() + runJavaScript 回调
│  │  │  └─ utils/{RawFile.ets, ScriptBuilder.ets}
│  │  ├─ resources/
│  │  │  ├─ base/{element, media, profile/main_pages.json, profile/backup_config.json}
│  │  │  └─ rawfile/
│  │  │     ├─ gm_shim.js                        ← 新写
│  │  │     ├─ viewport_fix.js                   ← 新写
│  │  │     ├─ pinyin-match.js                   ← 拷自原 APK
│  │  │     ├─ main_pack.js                      ← 拷自原 APK (2.2 MB)
│  │  │     ├─ pack2.js                          ← 拷自原 APK
│  │  │     └─ selftest.html                     开发期桥连通性自检
│  │  └─ module.json5                             权限 / 启动配置
│  ├─ build-profile.json5
│  ├─ oh-package.json5
│  ├─ hvigorfile.ts
│  └─ obfuscation-rules.txt
├─ build-profile.json5                            compileSdk=6.0.0(22)
├─ oh-package.json5                               根 ohpm 配置
├─ hvigorfile.ts
├─ hvigor/hvigor-config.json5
└─ code-linter.json5
```

---

## 致谢

- 原 Android 端「爆改新能源」作者 **程序猿**
- 油猴脚本核心逻辑全部沿用 `main_pack.js` / `pack2.js`
