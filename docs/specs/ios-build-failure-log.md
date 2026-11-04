# SPEC：iOS 构建失败日志

> 2026-11-04 治理修订：本文的阶段要求和验证计划为历史记录；现行验证范围以 [开发说明 §1.3–1.4](../flutter-template-development-revised.md) 和 [阶段计划](../flutter-template-phase-plan.md) 为准，iOS 验证不再是阶段门。

- 治理依据：[开发说明 §17.1 阶段 A：基础 CI](../flutter-template-development-revised.md#171-分阶段实施与阶段门)；[Phase 1 SPEC](phase-1-minimal-skeleton.md) 记录该阶段已获确认。
- 范围：维护现有 iOS Simulator 构建，在构建失败时保留日志；不改变工具链、构建命令或阶段验收状态。
- 契约：构建命令的失败状态不得被日志管道掩盖；仅构建步骤失败时尝试上传日志，保留 7 天。
- 验证：检查工作流语法及变更；macOS 构建和失败时的实际 artifact 上传须由后续 GitHub Actions 运行验证。
