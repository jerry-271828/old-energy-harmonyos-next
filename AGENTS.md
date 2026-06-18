# Repository Guidelines

## Project Structure & Module Organization

This repository contains a HarmonyOS NEXT app in `harmony/`; open that directory in DevEco Studio, not the repository root. The main module is `harmony/entry`. ArkTS source lives in `harmony/entry/src/main/ets/`, organized by responsibility: `pages/` for ArkUI screens, `components/` for reusable UI, `store/` for shared state, `net/` and `net/api/` for service calls, `bridge/` for Web/GM compatibility, `models/` for data types, and `utils/` for helpers. App and module configuration are in `AppScope/app.json5`, `entry/src/main/module.json5`, and the `build-profile.json5` files. Static resources are under `entry/src/main/resources/`, with injected Web assets in `resources/rawfile/`.

## Build, Test, and Development Commands

Run commands from `harmony/` unless noted.

- `ohpm install`: restore Harmony/OpenHarmony package dependencies.
- `hvigor -p module=entry@default assembleHap`: build the entry HAP when the Harmony command-line tools are installed.
- `codelinter -c code-linter.json5`: run the configured performance and TypeScript lint rules, if `codelinter` is available.
- DevEco Studio: open `harmony/`, sync Hvigor, configure signing, then use `Run` or `Build > Build Hap(s)/APP(s)`.

## Coding Style & Naming Conventions

Use ArkTS/ArkUI idioms already present in the codebase: two-space indentation, semicolons, single-quoted strings, explicit interfaces for structured data, and declarative `@ComponentV2` builders for UI. Name pages and components in PascalCase (`CourseDetailPage.ets`), stores as `*Store.ets`, API wrappers as `*Api.ets`, and utility modules by their main responsibility (`Downloader.ets`, `PinyinSearch.ets`). Keep bridge method names stable when JavaScript assets depend on them.

## Testing Guidelines

No automated test files are currently checked in, although Hypium is declared as a dev dependency. For now, validate changes with the manual smoke cases in `harmony/README.md`: login loading, navigation/back behavior, persistence, GM bridge calls, network requests, notification paths, PDF annotation, and pinyin search. For bridge work, temporarily point `ENTRY_URL` in `Index.ets` to `resource://rawfile/selftest.html` and verify all `GM_*` and `AndroidBridge` paths.

## Commit & Pull Request Guidelines

Recent commits use short, outcome-focused Chinese summaries, often starting with `修复` or `新增`, plus merge commits from feature/fix branches. Follow that style: describe the user-visible change first, for example `修复计划页编辑不实时刷新`. Pull requests should include a concise description, affected screens or modules, manual test results, linked issues when applicable, and screenshots or screen recordings for UI changes.

## Security & Configuration Tips

Do not commit generated build outputs, signing material, local SDK paths, or account-specific DevEco configuration. Treat files in `resources/rawfile/` as runtime inputs: changing names, order, or public bridge APIs can break injected scripts.
