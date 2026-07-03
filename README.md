# 爆改新能源 · HarmonyOS NEXT

[![Build HAP](https://github.com/jerry-271828/xny-harmonyos-next/actions/workflows/build-hap.yml/badge.svg)](https://github.com/jerry-271828/xny-harmonyos-next/actions/workflows/build-hap.yml)
![HarmonyOS](https://img.shields.io/badge/HarmonyOS-NEXT-3367FF?logo=harmonyos)
![API](https://img.shields.io/badge/API-24-blue)

将「爆改新能源」从 Android（`com.example.xny`，原作者 Aushen）移植到 **HarmonyOS NEXT**。

原 App 是 Android WebView 壳 + 油猴脚本；鸿蒙版以 **ArkTS/ArkUI 原生 UI** 为主体，直连后端 REST API，仅在「网页版兼容模式」中保留完整的 WebView 注入链路作为长尾功能回退。

> 项目代码位于 [`harmony/`](harmony/) 目录下，DevEco Studio 打开这个目录。

---

## 快速开始

```bash
# 用 DevEco Studio 打开
File → Open → 选 harmony/

# 等待 hvigor sync，自动签名后连接真机运行
```

**环境要求：** DevEco Studio 6.x + · SDK 6.1.0(23)+ · HarmonyOS NEXT 真机

详细构建说明 → [`harmony/README.md`](harmony/README.md)

---

## 功能一览

| 功能 | 说明 |
|---|---|
| 📚 课程 & 考试 | 课件/试卷浏览、题目作答、快捷提交、错因选择 |
| ✍️ 手写批注 | Pen Kit 官方手写套件、PDF 画布批注 |
| 🤖 AI 问答 | 与后端 AI API 交互、错题库 |
| 📎 附件预览 | PDF / 视频 / 图片全屏查看、拍照上传 |
| 🔍 拼音搜索 | 全局拼音/首字母模糊搜索 |
| 🌐 网页版兼容 | 完整 WebView + 油猴脚本回退（设置 → 关于） |

---

## 架构

| 层 | 目录 | 技术 |
|---|---|---|
| 网络 | `net/` | `@kit.NetworkKit` http + Cookie 认证 |
| 原生 UI | `pages/` `components/` | ArkUI (ArkTS) + HdsTabs + GlassKit |
| 状态 | `store/` | `@ObservedV2` 单例 |
| JS 桥 | `bridge/` | `javaScriptProxy` + GmStorage/GmHttp |
| 工具 | `utils/` | DES 加密、拼音搜索、下载器 |

---

## CI 构建

push 到 `main` 自动用 HarmonyOS command-line-tools 构建 HAP，发布为 GitHub Release。

---

## 致谢

- 原 Android 端「爆改新能源」—— **Aushen**
- 网页版兼容模式沿用原 APK 的 `main_pack.js` / `pack2.js` 油猴脚本

---

**HarmonyOS NEXT 原生版 · Bundle `com.betterxny.hm` · Version 1.2.1**
