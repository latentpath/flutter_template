# Flutter Template

Android/iOS Flutter 应用模板，提供启动恢复、首页/设置/数据示例、主题和中英文、本地偏好、网络与错误处理。默认使用内置 Fake 数据，无需后端、账号或发布密钥。

## 复制后直接开发

1. 将模板源码复制到自己的项目目录；已经拿到副本时，直接使用当前目录。
2. 在包含 `pubspec.yaml` 的目录执行下列命令。
3. 运行成功后，直接修改副本中的代码，按需替换应用名称、标识和品牌。

复制后直接在副本中开发。复制时保留 `.fvmrc`、`.gitignore` 等隐藏配置；不带入原模板的 `.git`、`.dart_tool/`、`build/`、本机路径配置或签名材料。保留 `pubspec.lock`。

## 快速运行

Flutter 版本以 [.fvmrc](.fvmrc) 为准，当前为 stable 3.47.9。Android 开发需准备 Android SDK、JDK 和模拟器或设备；iOS 另需 macOS 与 Xcode。

```sh
flutter pub get --enforce-lockfile
flutter gen-l10n
flutter devices
flutter run -d <device-id>
```

将 `<device-id>` 替换为实际设备标识。本地化生成用于根据 ARB 文案构建应用，不会创建新工程。首次运行可保留默认名称和标识，正式分发前再完成自己的配置。

## 使用文档

- [使用指南](docs/USER_GUIDE.md)：环境准备、代码阅读、修改应用标识、扩展功能与日常检查。
- [发布与签名](docs/RELEASING.md)：Android/iOS 签名与发布准备；当前 Android release 使用 debug 签名。
- [维护与升级](docs/UPGRADING.md)：依赖升级及选择性采用模板修复。
