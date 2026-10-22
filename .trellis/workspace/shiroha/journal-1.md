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
