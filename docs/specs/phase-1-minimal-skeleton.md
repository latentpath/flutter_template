# Phase 1 SPEC：最小工程骨架

状态：Phase 1 已由用户确认完成（2026-11-01）。

## 治理依据与范围

- [开发说明 §17.1：阶段 A 与 B](../flutter-template-development-revised.md#171-分阶段实施与阶段门)。
- [Phase Plan §3：Phase 1](../flutter-template-phase-plan.md#3-阶段计划)；前置 Phase 0 已由用户确认完成。
- 目标为固定工具链、依赖基线、最小工程、逻辑环境、基础 CI 和使用说明。按用户批准的 Phase 1 计划，提前实现纯配置解析与校验；开发说明将完整环境解析列入 B，启动协调、失败页和 Provider 集成仍属于 Phase 2。此处仅实现可独立测试的配置边界，不宣称 B 已完成。
- 不实施真实服务、设置持久化、路由、主题、国际化界面或平台发布。

## 阶段门与证据

干净检出依赖解析、静态分析、测试、Android debug 和 iOS Simulator 构建均通过，并记录最终代码版本、工具链及证据。完成阶段和推进须由人明确决定。首次 CI 运行及 `722ccdd` 的结果不代表本阶段最终代码通过。

| 检查 | 结果 / 证据 |
| --- | --- |
| 实施和依赖审查 | 已完成初步审查；插件运行行为留待后续阶段 |
| 干净检出依赖解析、分析、测试 | 提交 `bed7df4` 的 Android CI 通过；iOS CI 依赖解析通过 |
| Android debug 构建 | 提交 `bed7df4` 的 Android CI 通过 |
| iOS Simulator 构建 | 提交 `bed7df4` 的 macOS CI 通过 |
| 阶段验收 | 用户于 2026-11-01 明确确认完成 |

## 依赖审查记录（2026-11-01）

候选版本与锁文件解析一致；以包的 pub.dev 页面、锁文件和本地包 `pubspec.yaml` / `LICENSE` 为依据。候选包均有 Android/iOS 支持或为纯 Dart/Flutter 包；实际插件兼容性仍以双平台构建为准。

| 直接依赖及用途 | 许可证 / 兼容性与审查 |
| --- | --- |
| `flutter_riverpod` 3.4.3 | MIT；Dart ≥3.12；维护项目，应用容器和重试策略留待 Phase 2 验证。 |
| `go_router` 18.1.2 | BSD-3-Clause；Dart ≥3.12、Flutter ≥3.44；Flutter 团队维护；路由错误处理留待 Phase 2。 |
| `shared_preferences` 2.5.6 | BSD-3-Clause；Android 24+、iOS 13+；Flutter 团队维护。异步写入不保证设备故障下持久落盘，不保存秘密；实际失败处理留待 Phase 3。 |
| `dio` 5.11.1 | MIT；纯 Dart；维护项目。网络权限、取消与错误映射留待 Phase 4；当前未创建客户端。 |
| `intl` 0.20.3、Flutter `flutter_localizations` | BSD-3-Clause / Flutter SDK 许可证；由固定 Flutter SDK 约束；翻译资源与失败检查留待 Phase 2。 |
| `package_info_plus` 10.2.2 | BSD-3-Clause；iOS 13+、Java 17、Kotlin 2.2+、AGP 8.12.1+、Gradle 8.13+；Flutter Community 维护。插件调用及平台失败处理留待 Phase 4/5。 |
| `url_launcher` 6.3.3 | BSD-3-Clause；Flutter ≥3.41；Flutter 团队维护。外链依赖系统处理能力，失败与平台查询配置留待 Phase 4/5。 |
| `flutter_lints` 6.0.0 | BSD-3-Clause；Flutter 团队维护，开发期静态分析。 |

选择遵循章程冻结技术栈；替代方案包括分别采用其他状态、路由、存储或网络库，但会偏离已批准架构且本阶段无证据支持替换。这些依赖当前未被应用调用，不因加入而声称其功能或原生行为已经验证。插件所需权限及隐私清单在使用相应能力时继续审查；当前不增加业务权限、用户数据收集或网络调用。

参考：[Riverpod](https://pub.dev/packages/flutter_riverpod)、[go_router](https://pub.dev/packages/go_router)、[shared_preferences](https://pub.dev/packages/shared_preferences)、[Dio](https://pub.dev/packages/dio)、[intl](https://pub.dev/packages/intl)、[package_info_plus](https://pub.dev/packages/package_info_plus)、[url_launcher](https://pub.dev/packages/url_launcher)、[flutter_lints](https://pub.dev/packages/flutter_lints)。

## 本地实施记录

- 验证对象：基于 `722ccdd` 的未提交工作区，含用户原有的 Phase 0 / Phase Plan 文档修改；不等同于最终提交或干净检出。
- Ubuntu 26.04.1，Flutter 3.47.9 / Dart 3.13.7；Android SDK 36.1.0、JDK 25.0.4，项目配置 AGP 9.1.0 / Gradle 9.3.1 / Kotlin 2.4.0，iOS deployment target 15.0。`flutter doctor -v` 中 Android 检查通过；Linux desktop 工具链缺失，不属于首版验收平台。
- `flutter pub get --enforce-lockfile`、`flutter analyze`、`flutter test`：工作区通过；将版本控制文件和未跟踪源码复制到无项目构建缓存的临时快照后再次通过，15 项测试通过。快照不是最终提交的干净检出。
- `flutter build apk --debug`：工作区通过，产物 `build/app/outputs/flutter-apk/app-debug.apk`；非最终提交 CI 证据。
- [GitHub Actions 运行 #2](https://github.com/latentpath/flutter_template/actions/runs/41288782574) 对提交 `bed7df4ec3b71e61f0e0faff4fdf4311cc671363` 通过：Android job 的严格锁文件依赖解析、分析、测试和 debug APK 构建成功；macOS 26 job 选择 Xcode 26.6，严格锁文件依赖解析及 iOS Simulator 无签名构建成功。两项 job 均从 checkout 执行。
- FVM 4.3.2 已安装至用户 Pub 缓存；`fvm flutter --version` 和 `fvm flutter doctor -v` 显示 FVM 管理的 Flutter 3.47.9 / Dart 3.13.7，Android 检查通过；Linux desktop 工具链缺失。常规构建与测试使用 PATH 上版本一致的 Flutter。

用户已根据提交 `bed7df4` 的 CI 阶段门证据确认 Phase 1 完成；Phase 2 尚未开始。

上述 CI 证明该提交的构建与检查通过；插件原生运行行为、真机和发布验证不在此证据范围。当前文档更新为记录证据，不改变已验证的应用代码。
