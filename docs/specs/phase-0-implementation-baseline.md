# Phase 0 SPEC：实施基线

> 2026-11-04 治理修订：本文的阶段要求和验证计划为历史记录；现行验证范围以 [开发说明 §1.3–1.4](../flutter-template-development-revised.md) 和 [阶段计划](../flutter-template-phase-plan.md) 为准，iOS 验证不再是阶段门。

> 日期：2026-11-01  
> 状态：Phase 0 已由用户确认完成（2026-11-01）；候选 Flutter SDK 与原生脚手架已通过 Android / iOS Simulator 首次 CI 构建。核心插件候选尚未纳入验证，属于 Phase 1 工作。
> 目标工程：`/home/chunmli/Development/apps/Flutter/flutter_template`  
> 依据：[`docs/flutter-template-development-revised.md` §17.1](../flutter-template-development-revised.md#171-分阶段实施与阶段门)、[`docs/flutter-template-phase-plan.md` §3](../flutter-template-phase-plan.md#3-阶段计划)

## 目标与范围

为 Phase 1 确定模板工程、应用标识、候选 SDK/原生工具链、核心依赖版本和 Android/iOS 构建执行路径，并给出可复核的 Phase 1 清单。Phase 0 的交付范围是决策、工具链版本配置和任务清单。随后配置的 CI 已提前产生 Android/iOS 首轮构建证据；这项证据不代表 Phase 1 的完整退出条件已满足。

治理阶段是 Phase Plan 的 Phase 0（实施基线）及开发说明 §17.1 的 A 阶段准备工作。工程骨架、锁定功能依赖、基础 CI 和首次双平台构建仍属于 Phase 1 / 阶段 A 的退出验证。

## 已确认的工程决策

| 项目 | 决策 | 状态/依据 |
| --- | --- | --- |
| 模板工程目录 | 采用当前目录 | 用户已确认；已有 Flutter Android/iOS 脚手架、`pubspec.lock` 和测试入口 |
| 工程名 / Dart package | `flutter_template` | 与 `pubspec.yaml` 和目录一致 |
| Android application ID | `com.example.flutter_template` | 保留现有脚手架值；这是示例命名空间，不是可发布的团队组织标识，模板实例化必须替换 |
| iOS bundle ID | `com.example.flutterTemplate` | 保留现有脚手架值；这是示例命名空间，模板实例化必须替换 |
| SDK 版本管理 | FVM，仓库 `.fvmrc` 固定 `3.47.9` stable | FVM 配置文件优先级高于全局和 PATH SDK；`.fvm/` 加入忽略规则。当前开发机没有安装 FVM；CI 通过 `subosito/flutter-action` 读取 `.fvmrc`，不依赖 FVM CLI |
| Flutter / Dart 候选 | Flutter `3.47.9` stable / Dart `3.13.7` | 本机 `flutter --version` 输出；Flutter 官方 stable changelog 列出 3.47.9，且 3.47.8 包含 Dart TLS 安全修复 |
| Android 最低版本候选 | minSdk 24；compile/target SDK 36 | 当前 Flutter SDK 默认值；须由 Phase 1 依赖解析与 Android 构建确认 |
| iOS 最低版本候选 | iOS 15.0 | 当前 Xcode 项目配置；依赖兼容性与 Simulator 构建须在 Phase 1 确认 |

应用标识目前只满足模板本地运行和实例化前的脚手架需求。Phase 6 必须将两平台标识替换为派生应用自己的唯一标识；不能把 `com.example` 当作模板发布或派生应用的正式标识。

## 候选工具链和依赖

Flutter SDK 与当前原生脚手架构成的基线已完成依赖解析及 Android debug / iOS Simulator 构建，可记录为首轮已验证工具链。下表中的核心插件仍是候选；加入 `pubspec.yaml` 并在锁定依赖下复跑双平台构建后，才纳入正式依赖基线。

| 范围 | Phase 1 候选 | 证据/备注 |
| --- | --- | --- |
| Android 主机 | Linux；Android SDK 36.1.0；JDK 25.0.4；Gradle 9.3.1；AGP 9.1.0；Kotlin 2.4.0 | `flutter doctor -v` 显示 Android toolchain 检查通过，CI Android debug 构建通过；版本组合以当前脚手架配置及 CI runner 环境为准 |
| Android 编译目标 | Java/Kotlin bytecode 17；NDK 28.2.13676358 | 当前工程配置及锁定 Flutter SDK 默认值 |
| iOS 主机 | GitHub Actions `macos-26`，Xcode 26.6；iOS Simulator 构建 | 首次构建已由 CI 通过；当前 Linux 主机无 Xcode / iOS Simulator |
| 偏好存储 | `shared_preferences` 2.5.6 | 新代码使用 `SharedPreferencesAsync`；插件支持 Android 24+ / iOS 13+，并说明写入不保证返回后已落盘 |
| 状态管理 | `flutter_riverpod` 3.4.3 | 符合章程 Riverpod 3.x；需在实现时核对 API 和自动重试契约 |
| 路由 | `go_router` 18.1.2 | 符合章程 go_router；候选要求 Dart 3.12+ |
| 网络 | `dio` 5.11.1 | 限于 API Service / 数据边界；Fake 默认实现不创建客户端、不访问公网 |
| 国际化 | Flutter `flutter_localizations` + `intl` 0.20.3 + ARB/gen_l10n | 本机 Flutter SDK 的 `flutter_localizations` 约束 `intl: ^0.20.3` |
| 应用信息 / 外链 | `package_info_plus` 10.2.2 / `url_launcher` 6.3.3 | 均支持 Android/iOS；插件原生行为在 Phase 1/5 分别验证 |
| 静态检查 | `flutter_lints` 6.0.0 | 当前工程已使用此版本 |

上表记录的是依赖审查候选，不提前修改 `pubspec.yaml` 或锁文件。Phase 1 在锁文件中精确锁定实际解出的传递依赖，并记录许可证、维护状态、最低平台要求及构建结果；如候选引入平台冲突，先更新本记录和设计约束，再继续实现。候选包版本核对日期为 2026-11-01，依据 pub.dev 当前稳定版页面。

## 验证环境与 Phase 1 任务清单

### 当前环境探测与 CI 证据（2026-11-01）

- `flutter doctor -v`：Flutter 3.47.9 / Dart 3.13.7、Android SDK 36.1.0、JDK 25.0.4、Android licenses 均通过；当前连接 Linux 桌面与 Chrome。
- iOS：当前主机为 Linux，无 `xcodebuild` 或 iOS Simulator；iOS 验证路径为 GitHub Actions `macos-26` runner 并选定 Xcode 26.6，首次 Simulator 构建已由 CI 通过。
- Git：公开仓库 `latentpath/flutter_template` 已配置为 `origin`；本地 `main` 与 `origin/main` 同步至验证提交 `722ccdd11e6a99f6a1ceb8e36f906016e5520055`。
- CI 证据：[运行 #1](https://github.com/latentpath/flutter_template/actions/runs/41286294315) 于提交 `722ccdd` 完成且结论为 success。Android 与 iOS Simulator jobs 中 Flutter 安装、`pub get`、分析/测试（Android）和 debug / Simulator 构建均通过。
- `flutter doctor` 的 Linux desktop 类别因缺少 clang++、CMake、Ninja、pkg-config 未通过；Linux desktop 不属于本模板首版验收平台，不因此阻塞 Android/iOS。

### Phase 1 可执行清单

1. 在本地 Linux 环境安装 FVM 并运行 `fvm flutter --version`、`fvm flutter doctor -v`；CI 已由 Flutter Action 从 `.fvmrc` 解析并使用 3.47.9。
2. 对候选依赖进行维护状态、许可证、平台支持、最低 OS/JDK/Gradle/AGP 要求审查；在 `pubspec.yaml` 加入获准候选并生成提交 `pubspec.lock`。
3. 从干净检出运行 `fvm flutter pub get`、`fvm flutter analyze`、`fvm flutter test`，记录命令和结果。
4. 在 Android 环境运行 `fvm flutter build apk --debug`；记录 Runner OS、JDK、Android SDK、Gradle/AGP/Kotlin、minSdk 和产物结果。
5. 在 `macos-26` / Xcode 26.6 环境运行 `fvm flutter build ios --simulator --no-codesign`；记录 macOS、Xcode、iOS Simulator SDK、deployment target 和结果。
6. 更新本 SPEC 和 Phase Plan 跟踪表，逐项列出证据路径和未解决项；双平台构建通过后，将候选值更新为已验证基线，再由人决定阶段门状态。

## 验收状态与未解决项

| 检查项 | 当前结果 |
| --- | --- |
| 工程位置、名称与包名 | 已确认并记录 |
| Android/iOS 标识 | 已记录；示例标识只供模板基线使用，实例化需替换 |
| Flutter/Dart 候选版本 | CI 使用 `.fvmrc` 指定的 Flutter 3.47.9；Dart 3.13.7；本机 FVM 重放仍待执行 |
| 核心依赖候选版本与审查方向 | 已记录；插件尚未加入 pubspec，未验证兼容性 |
| Android 执行环境 | 本机 doctor 通过；GitHub Actions Android debug 构建通过 |
| iOS 执行环境 | GitHub Actions `macos-26` / Xcode 26.6 Simulator 构建通过 |
| 阶段状态 | Phase 0 已由用户确认完成（2026-11-01）；Phase 1 仅 CI 与首次构建通过，整体退出条件未验收 |

## 参考来源

- [Flutter stable changelog](https://github.com/flutter/flutter/blob/stable/CHANGELOG.md)
- [Flutter SDK archive](https://docs.flutter.dev/install/archive)
- [FVM 配置查找顺序](https://fvm.app/documentation/getting-started/faq)
- [GitHub Actions runner images](https://github.com/actions/runner-images)
- [flutter_riverpod 3.4.3](https://pub.dev/packages/flutter_riverpod/versions)
- [go_router 18.1.2](https://pub.dev/packages/go_router/versions)
- [shared_preferences 2.5.6](https://pub.dev/packages/shared_preferences)
- [Dio 5.11.1](https://pub.dev/packages/dio)
- [intl 0.20.3](https://pub.dev/packages/intl/versions)
- [package_info_plus 10.2.2](https://pub.dev/packages/package_info_plus)
- [url_launcher 6.3.3](https://pub.dev/packages/url_launcher/versions)
- [flutter_lints 6.0.0](https://pub.dev/packages/flutter_lints/versions)
