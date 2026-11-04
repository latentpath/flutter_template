# Flutter Template

Android/iOS Flutter 模板。当前提供启动恢复、首页/设置/未知路由、主题和中英文界面。Phase 3 正在接入本地偏好持久化；Android 跨进程重启验收状态见 Phase 3 SPEC；iOS 验证不阻塞阶段门。默认无需后端、账号或签名材料。

## 准备与运行

在包含 `pubspec.yaml` 的仓库根目录执行。安装 Flutter stable 3.47.9（Dart 3.13.7）；仓库 `.fvmrc` 记录该版本。若使用 FVM，将下面的 `flutter` 替换为 `fvm flutter`。准备 Android SDK，iOS 构建另需 macOS 和 Xcode。

```sh
flutter --version
flutter pub get --enforce-lockfile
flutter run -d <device-id>
```

## 逻辑环境

通过 `--dart-define=APP_ENV=development`、`staging` 或 `production` 选择逻辑环境，默认 `development`。`DATA_SOURCE_MODE` 为 `fake`（默认）或 `api`；`API_BASE_URI` 默认空。三种环境的默认配置均离线运行。Fake 模式不接受非空地址；API 模式要求非占位 HTTPS 地址，且不能包含用户凭据、查询或片段。未知环境、模式及无效地址会进入独立启动失败页，可由用户重试。

```sh
flutter run --dart-define=APP_ENV=staging
flutter run --dart-define=APP_ENV=production
```

这些值只选择 Dart 层配置，不创建原生 flavor、scheme 或独立应用标识。API 模式目前仅校验配置，不实现网络数据源。编译变量可从客户端产物中提取，不能存放密钥、Token 或其他秘密。

## 检查与构建

```sh
flutter pub get --enforce-lockfile
flutter gen-l10n
python3 tool/check_translations.py
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

iOS 构建为可选验证，命令需在 macOS/Xcode 执行。`flutter gen-l10n` 从 `lib/l10n/app_en.arb` 和 `app_zh.arb` 生成本地化代码；生成目录不提交。CI 配置使用 `.fvmrc` 并在构建前生成/检查翻译。Phase 2 的实际验证记录见 [Phase 2 SPEC](docs/specs/phase-2-startup-core-ui.md)。Simulator 构建不能代替设备或发布验证。示例应用标识 `com.example.*` 必须由派生应用替换。

## 设置持久化验证

主题和语言分别使用非敏感偏好键 `settings.theme_mode` 和 `settings.locale`。写入成功后界面才更新；失败时保留已确认状态。插件写入异常可能导致磁盘结果不确定，应用不会自动重试。

在 Android 真机或模拟器上运行应用，选择深色主题和非系统语言，完全结束应用进程后重新启动，检查两项设置是否恢复；再选择跟随系统并重复。记录设备、系统、Flutter 版本、代码版本和结果。不要清除应用数据或卸载应用来模拟普通重启。

设置格式变更需设计版本化、幂等迁移：先确认新值写入成功，再考虑移除旧值。首版不假设存在历史设置。详见 [Phase 3 SPEC](docs/specs/phase-3-settings-persistence.md)。
