# 应用发布与签名

所有配置和构建都在当前应用副本中完成。开始前按 [使用指南](USER_GUIDE.md#修改标识和品牌) 配置自己的名称、标识与品牌。

本模板不包含真实发布密钥或生产服务配置。以下为维护者配置指南，不代表签名、商店发布或 iOS 设备已验证。发布前替换 `com.example.*`、应用名称、占位图标，检查包标识、渠道、权限、服务地址及版本；`pubspec.yaml` 中 `version: 名称+构建号` 可由 `--build-name`、`--build-number` 覆盖。编译变量可被提取，不能放秘密。

## Android

当前 `android/app/build.gradle.kts` 的 `release` 显式使用 `signingConfigs.getByName("debug")`；默认 release APK 只供验证，**不可分发**。由应用维护者在安全环境创建并备份自己的 keystore，保管其密码、别名和签名身份，并按 [Flutter Android 发布指南](https://docs.flutter.dev/deployment/android) 配置独立的 release signing config。`android/key.properties`、`*.jks`、`*.keystore` 已在 Android 的 `.gitignore` 中忽略；启用 Git 后仍需检查 `git status`，不要将材料放在未忽略的位置或提交到源码。CI 应使用受限制的密钥存储，普通 PR 不提供发布密钥。

例如在当前工程的 `android/key.properties` 中配置 `storePassword`、`keyPassword`、`keyAlias`、`storeFile`（文件位置相对 `android/app` 或使用安全的绝对路径），然后在 `android/app/build.gradle.kts` 顶部 `plugins` 块之后加载配置：

```kotlin
val signingProperties = java.util.Properties()
val signingFile = rootProject.file("key.properties")
if (signingFile.exists()) signingFile.inputStream().use { signingProperties.load(it) }
```

在已有 `android { ... }` 中、`buildTypes` 之前添加，并将 `release` 的 debug 签名替换为 `signingConfigs.getByName("release")`：

```kotlin
signingConfigs {
    create("release") {
        keyAlias = signingProperties["keyAlias"] as String?
        keyPassword = signingProperties["keyPassword"] as String?
        storeFile = (signingProperties["storeFile"] as String?)?.let { file(it) }
        storePassword = signingProperties["storePassword"] as String?
    }
}
```

在受控环境提供签名配置后构建（命令中的环境必须符合应用的实际发布配置）：

```sh
flutter build appbundle --release --dart-define=APP_ENV=production
flutter build apk --release --dart-define=APP_ENV=production
```

分别检查 `build/app/outputs/bundle/release/` 与 `build/app/outputs/flutter-apk/` 中的产物；使用 Android SDK Build Tools 的 `apksigner verify --print-certs <apk路径>` 核验 APK 签名，并将证书指纹与预期身份比对。AAB 签名另用 JDK `jarsigner -verify -verbose -certs <aab路径>` 核验，核对上传密钥与渠道的应用签名机制。检查版本与 application ID，在目标设备上验证 release 的首屏、导航、主题、语言、网络配置和平台能力，再按目标渠道要求上传。

## iOS

在 macOS 上用 Xcode 为应用设置唯一 Bundle ID、Team、签名证书与 provisioning profile；校验版本、权限和目标渠道。在授权且配置完成的环境按 [Flutter iOS 发布指南](https://docs.flutter.dev/deployment/ios) 执行 `flutter build ipa --release` 并核验归档、签名和设备行为。模板当前未验证 iOS 设备运行、签名和发布，不能仅凭模拟器编译推断其通过。

生产与测试环境如需并行安装，需在自己的项目中配置原生 flavors/schemes；`APP_ENV` 本身不会创建它们。

返回 [使用指南](USER_GUIDE.md) · [维护与升级](UPGRADING.md)
