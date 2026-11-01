# Flutter Template

Android/iOS Flutter 模板的 Phase 1 骨架。当前页面是离线占位界面；路由、设置、国际化界面和数据访问示例尚未实现。默认无需后端、账号或签名材料。

## 准备与运行

在包含 `pubspec.yaml` 的仓库根目录执行。安装 Flutter stable 3.47.9（Dart 3.13.7）；仓库 `.fvmrc` 记录该版本。若使用 FVM，将下面的 `flutter` 替换为 `fvm flutter`。准备 Android SDK，iOS 构建另需 macOS 和 Xcode。

```sh
flutter --version
flutter pub get --enforce-lockfile
flutter run -d <device-id>
```

## 逻辑环境

通过 `--dart-define=APP_ENV=development`、`staging` 或 `production` 选择逻辑环境，默认 `development`。`DATA_SOURCE_MODE` 为 `fake`（默认）或 `api`；`API_BASE_URI` 默认空。三种环境的默认配置均离线运行。Fake 模式不接受非空地址；API 模式要求非占位 HTTPS 地址，且不能包含用户凭据、查询或片段。未知环境、模式及无效地址会在启动时抛出配置错误；恢复界面在 Phase 2 实现。

```sh
flutter run --dart-define=APP_ENV=staging
flutter run --dart-define=APP_ENV=production
```

这些值只选择 Dart 层配置，不创建原生 flavor、scheme 或独立应用标识。API 模式目前仅校验配置，不实现网络数据源。编译变量可从客户端产物中提取，不能存放密钥、Token 或其他秘密。

## 检查与构建

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

iOS 命令需在 macOS/Xcode 执行。CI 使用 `.fvmrc`、Android 与 macOS jobs；具体验收状态和证据见 [Phase 1 SPEC](docs/specs/phase-1-minimal-skeleton.md)。Simulator 构建不能代替设备或发布验证。示例应用标识 `com.example.*` 必须由派生应用替换。
