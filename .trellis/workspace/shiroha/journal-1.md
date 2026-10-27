# Journal - shiroha (Part 1)

> AI development session journal
> Started: 2026-10-22

---



## Session 1: 初始化 Flutter spec 并搭建项目骨架

**Date**: 2026-10-22
**Task**: 初始化 Flutter spec 并搭建项目骨架
**Branch**: `master`

### Summary

把 trellis init 生成的 backend/frontend spec 换成 Flutter 层并和开发者一起定下约定，然后按 spec 搭好项目骨架（依赖、app/core/l10n、测试）。

### Main Changes

- 00-bootstrap-guidelines: spec 改为单一 flutter/ 层，8 个规范文件，带 paths frontmatter 按路径注入
- 约定: 按功能分目录, Riverpod 3 + codegen, go_router + go_router_builder, dio, freezed + json_serializable, ARB + gen-l10n (zh 模板), mocktail
- 10-22-scaffold-project: 加依赖和配置, 建 lib/app、lib/core、lib/l10n、占位首页 features/home, 替换模板 main.dart 和测试
- go_router 停在 17.5.0 (18 迁到 material_ui 会丢页面切换动画); build_runner 2.16.2 受 go_router_builder 限制
- check 阶段修复: dio 无法解码的响应体 (unknown + FormatException) 改为 ParseException, 不再当网络错误重试

### Git Commits

| Hash | Message |
|------|---------|
| `413c7bd` | (see git log) |
| `26bfe34` | (see git log) |

### Testing

- [OK] dart run build_runner build 第二次运行 0 输出
- [OK] dart format --set-exit-if-changed lib test: 0 changed
- [OK] flutter analyze: No issues found
- [OK] flutter test: 35 passed

### Status

[OK] **Completed**

### Next Steps

- 第一个调接口的任务: 处理明文 HTTP (Android/iOS/macOS 平台配置), 确定 API 字段命名和分页格式
- 登录认证方案 (token 存储、刷新拦截器、路由重定向) 待定
- pubspec.yaml description 仍是模板文字


## Session 2: S1 free iPhone build and diagnostics probe

**Date**: 2026-10-22
**Task**: S1 free iPhone build and diagnostics probe
**Branch**: `ios-build/s1-probe`

### Summary

Reviewed and revised the lan-reader parity plan (GitHub Actions build host, fixed app identifier, file-based diagnostics export, refresh-limit evidence). Delegated S1 implementation to Codex CLI (gpt-6.1-sol high); review found timestamp-equality frame correlation would never match on device and switched it to engine frame numbers. Fixed CI (reserved FLUTTER_VERSION define, lipo argument order) and missed-vsync counting (>=12.5 ms). Signing route changed to 全能签 with a user-supplied certificate. On iPhone 14 Pro Max / iOS 27.0.1: BC1-BC6 passed; 1797/1797 frames correlated, vsync P50/P99 8.34/8.46 ms with one start-transition miss; marker survived build 3->4 update and re-sign. Physical presentation unverified. PR natumeAi/shiori#1 opened; S1 archived.

### Git Commits

| Hash | Message |
|------|---------|
| `1708520` | (see git log) |
| `4fc9475` | (see git log) |
| `9472fa0` | (see git log) |
| `5624af5` | (see git log) |
| `9943313` | (see git log) |

### Status

[OK] **Completed**


## Session 3: S2 phases 0-A complete; user-paused in Phase B

**Date**: 2026-10-22
**Task**: S2 phases 0-A complete; user-paused in Phase B
**Branch**: `ios-build/s2-reader-probe`

### Summary

Completed local Phase 0 and Phase A with passing oracle and Flutter gates. User explicitly paused during Phase B, roughly 25 percent effort; parser/source and CFI model drafts plus dependencies remain uncommitted and unverified. Resume from the S2 resume-handoff.md; no push, archive, device run or Phase B commit.

### Main Changes

- Created ios-build/s2-reader-probe and committed baseline/planning plus reproducible oracle tooling and synthetic fixtures.
- Recorded Phase B source and CFI drafts, agreed APIs, dependency versions/licences and exact pending work in S2 resume notes.

### Git Commits

| Hash | Message |
|------|---------|
| `4e15862` | (see git log) |
| `74932bb` | (see git log) |

### Testing

- [OK] Phase A: 45 byte-identical outputs, 4807 CFI samples per engine, private 168677 samples per engine, zero observed engine differences, 91 Flutter tests passed.
- [OK] Phase B: dependency installation exit 0 only; no formatter, codegen, analyzer, tests or gate run.

### Status

[PAUSED] **Paused at user request; Phase B is incomplete**

### Next Steps

- After user resumes, read .trellis/tasks/10-22-native-reader-feasibility/resume-handoff.md and both resume research notes; set this task's session pointer, preserve drafts, and continue Phase B.


## Session 4: S2 phases D-F, first iPhone run and S4 conditional GO

**Date**: 2026-10-26
**Task**: S2 phases D-F, first iPhone run and S4 conditional GO
**Branch**: `ios-build/s2-reader-probe`

### Summary

Phases D (page-turn controller, prepared surfaces), E (reader probe, Swift presentation probe, analyzer, two-IPA CI) and F (device runbook, report, specs) implemented with the Codex CLI gpt-6.1-sol and verified with gpt-6-astra; pushed and built by CI (39923417215, 40250493709). First iPhone run: 43 private exports; stage budgets pass (A1 30/30, R11 4/4), correctness passes where evaluable, resource failures recorded, admission latency and stall classification unverified by measurement limits; user stopped further instrumentation and recorded S4 conditional GO with seven conditions. Task archived.

### Git Commits

| Hash | Message |
|------|---------|
| `25bac2d` | (see git log) |
| `bf12416` | (see git log) |
| `862d999` | (see git log) |
| `417daf4` | (see git log) |
| `7ff10be` | (see git log) |

### Status

[OK] **Completed**


## Session 5: S3 device acceptance and closeout

**Date**: 2026-10-27
**Task**: S3 device acceptance and closeout
**Branch**: `ios-build/s3-runtime-server`

### Summary

Owner confirmed all S3 device tests passed on 2026-10-27. Recorded acceptance attribution and AC1-AC11 disposition, updated parent delivery status and S4 handoff, and archived S3. Existing code gates retained; documentation/task validations passed. S4 rendering/performance and all seven S2 conditions remain open. Archive hit a Windows research-directory lock; verified all 21 archived files, removed identical source duplicates, and committed the recovered archive. Only an empty locked source directory remains; no task metadata remains there.

### Git Commits

| Hash | Message |
|------|---------|
| `0ac4a86` | (see git log) |
| `bd9de27` | (see git log) |
| `a077ef3` | (see git log) |
| `f94c7ba` | (see git log) |

### Status

[OK] **Completed**
