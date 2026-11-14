# Flutter 应用模板使用指南

复制模板到自己的项目目录后，所有开发直接在副本中进行。先运行默认应用，再按需修改标识、页面和数据源。

模板提供首页、设置页、数据示例、主题和中英文、本地偏好、网络与错误边界、日志及工程检查。默认数据来自 Fake，无需业务后端、账号或发布密钥。认证、数据库、后台同步、支付和推送按业务需求接入。

Android 是当前主要验证平台；iOS 是兼容目标，设备运行与签名需在自己的项目中单独验证。Android release 当前使用 debug 签名，正式分发前必须替换。

## 阅读和工作路径

| 你的任务 | 从哪里开始 |
| --- | --- |
| 第一次拿到源码 | [环境准备与运行](#环境准备与运行) → [代码结构与阅读顺序](#代码结构与阅读顺序) |
| 开始自己的应用 | [直接使用模板副本](#直接使用模板副本) → [修改标识和品牌](#修改标识和品牌) |
| 新增业务功能 | [新增页面和本地化](#新增页面和本地化) → [替换数据源](#替换数据源) → [设置与状态管理](#设置与状态管理) |
| 日常提交 | [日常检查与协作](#日常检查与协作) → [常见问题](#常见问题) |
| 准备分发或采用模板更新 | [发布与签名](#发布与签名) → [版本和升级](#版本和升级) |

## 环境准备与运行

### 工具链

所有命令从包含 `pubspec.yaml` 的工程根目录执行。使用 Flutter stable 3.47.9 及其随附的 Dart 3.13.7。Python 3 用于翻译检查，Git 按需用于版本管理。`.fvmrc` 固定 Flutter 版本；使用 FVM 时，将下文的 `flutter` 替换为 `fvm flutter`，`dart` 替换为 `fvm dart`。

Android 开发需要 Android Studio、Android SDK、可用模拟器或设备及兼容 JDK。原生 Gradle 配置位于 `android/`。GitHub Actions 会在 PR 和主分支 push 上运行 Linux 验证与 Android debug 构建；iOS 构建另需 macOS、Xcode 和对应工具链。

```sh
flutter --version
flutter doctor -v
java -version
python3 --version
flutter devices
```

先处理 Android toolchain 的错误。暂不开发桌面平台时，桌面工具链缺失不影响 Android 工作。Flutter 安装和首次依赖解析可能需要网络；默认 Fake 应用运行不依赖公网业务服务。

### 首次启动

```sh
flutter pub get --enforce-lockfile
flutter gen-l10n
flutter run -d <device-id>
```

`flutter gen-l10n` 只生成当前工程使用的本地化类，修改 ARB 文案后也需要执行。

将 `<device-id>` 换成 `flutter devices` 返回的 Android 设备标识。依赖解析使用随模板提供的锁文件；首次接手时不要先执行 `pub upgrade`。

启动后应能从首页进入设置和数据示例。设置提供浅色、深色、跟随系统及中英文选择；数据示例默认显示内置条目。主题和语言先保存、后显示新状态。结束进程再启动可以检查偏好恢复；卸载或清除数据会删除偏好，不等同于普通重启。

## 代码结构与阅读顺序

```text
lib/
  main.dart                         绑定初始化、错误入口、启动协调器
  app/
    app.dart                        依赖组合、路由、主题、首页和设置界面
    config/app_config.dart          构建环境和数据源模式校验
    startup/startup.dart            启动状态、失败页和重试
    startup/bootstrap_resources.dart 应用资源、恢复和清理
    settings/settings.dart          设置状态、Notifier、仓库与 FIFO 队列
  features/example/
    example_page.dart               查询 Provider 和示例界面
    example_repository.dart         数据模型、接口、Fake、API Service 和仓库
    example_client.dart             按需创建与关闭 Dio
  core/
    errors/                         应用失败类型
    logging/                        安全日志和全局错误入口
    platform/                       应用信息、外链适配器
    widgets/                        加载、空、错误和重试组件
  l10n/
    app_en.arb / app_zh.arb          用户文案
    generated/                      由 gen-l10n 生成，不手动修改
tool/                                翻译检查等开发辅助脚本
```

推荐先看 `main.dart`，然后依次看 `startup.dart`、`bootstrap_resources.dart`、`app.dart`，最后沿 `example_page.dart` → Repository → Service 阅读数据链路。当前首页、设置和路由集中在 `app.dart`；功能增多后可按 feature 拆分，无需为匹配某种目录形式预先添加空层。

应用的主要依赖方向是：

```text
Widget → Provider 或 Notifier → Repository → API Service 或存储适配器
```

Widget 展示状态和收集操作；Provider 表达依赖，Notifier 协调可变状态；Repository 和数据源负责外部访问及失败边界。Widget 不直接持有 Dio、偏好插件或平台插件单例。业务实现放入对应 feature；只有职责稳定、跨功能复用的能力放入 `core`。

### 启动和资源归属

`main` 安装错误入口并调用一次 `runApp`。启动协调器校验配置、读取设置，然后交付 `BootstrapResources`。偏好读取失败或超时会使用默认设置继续，不回写默认值；配置错误或关键初始化失败进入独立失败页。默认偏好读取预算为 2 秒，完整启动预算为 5 秒。

`TemplateApp` 在组合层注入仓库、设置初始状态、队列和日志。`GoRouter` 在应用生命周期内保持稳定，主题或语言变化不会重建它。应用资源持有共享客户端和设置队列；页面查询只取消自身请求，不关闭共享客户端。异步完成后检查 `ref.mounted` 或 `context.mounted`，不能使用已经销毁的上下文。

## 直接使用模板副本

将模板源码复制到自己的项目目录，并保留隐藏配置文件和 `pubspec.lock`。复制时跳过 `.git/`、`.dart_tool/`、`build/`、`.flutter-plugins-dependencies`、`android/local.properties` 和签名材料，避免带入原工程历史、本机路径或缓存。副本准备好后，后续命令都在副本根目录执行。

可以先保留默认包名和原生标识运行、修改业务代码；它们不妨碍本地开发。需要独立安装或准备分发时，再按下一节修改。

### 版本管理（可选）

如果副本尚未启用 Git，可在副本根目录执行 `git init`，检查 `.gitignore` 后提交需要管理的源码、配置和锁文件。已有 Git 仓库则继续使用。记录模板来源地址、版本、commit（如有）或复制日期，便于以后比较修复。

### 修改标识和品牌

以下修改全部在当前副本中完成，无需重新创建 Flutter 工程。包名、原生标识和桌面显示名称是不同配置，要分别修改。

| 内容 | 修改位置与要点 |
| --- | --- |
| Dart 包名、描述、版本 | `pubspec.yaml`：将 `name: flutter_template` 改为自己的小写下划线名称，如 `sample_client`；避免与依赖同名 |
| Dart 包导入 | 如果存在 `package:flutter_template/`，同步改成新包名；以后新增的测试也使用新包名 |
| Android 标识 | `android/app/build.gradle.kts`：将 `namespace` 和 `applicationId` 从 `com.example.flutter_template` 改为自己的标识，如 `org.demo.sampleclient` |
| Android Kotlin 入口 | 修改 `android/app/src/main/kotlin/com/example/flutter_template/MainActivity.kt` 的 `package`，并把文件移动到匹配新包名的目录，例如 `kotlin/org/demo/sampleclient/` |
| Android 显示名称 | `android/app/src/main/AndroidManifest.xml` 的 `android:label` |
| iOS 标识 | 在 Xcode 打开 `ios/Runner.xcworkspace`，修改 Runner 的 Bundle Identifier；RunnerTests（如保留）也使用对应标识，核对 Debug/Profile/Release 配置 |
| iOS 显示名称 | `ios/Runner/Info.plist` 的 `CFBundleDisplayName` 与 `CFBundleName` |
| 界面标题和演示文案 | `lib/l10n/app_en.arb`、`app_zh.arb`，包括 `appTitle`、首页提示与外链按钮文案；修改后执行 `flutter gen-l10n` |
| 浅色和深色品牌色 | `lib/app/app.dart` 中两处 `ColorScheme.fromSeed` 的 `seedColor` |
| Android/iOS 图标 | `android/app/src/main/res/mipmap-*/` 与 `ios/Runner/Assets.xcassets/AppIcon.appiconset/`，替换各尺寸并在设备上检查 |
| 帮助或项目链接 | `lib/app/app.dart` 中 `SettingsPage` 的 URI 与 `lib/core/platform/platform_services.dart` 中外链允许域名 |

修改网站时，同时修改按钮 URI、按钮文案和允许域名；只修改 URI 会被适配器拒绝。完成后重新执行依赖解析、本地化生成和分析，运行应用核对名称、图标、主题及外链。原生标识变更会被设备视为不同应用，原安装的偏好不会自动迁移。

应用自己的 README、授权、隐私说明、Team、签名和业务服务按实际需求维护。正式发布步骤见 [发布与签名](RELEASING.md)。

## 环境和数据源配置

| 构建变量 | 默认值 | 允许值及作用 |
| --- | --- | --- |
| `APP_ENV` | `development` | `development`、`staging`、`production` |
| `DATA_SOURCE_MODE` | `fake` | `fake` 或 `api` |
| `API_BASE_URI` | 空 | API 模式要求合法的非占位 HTTPS 基础地址 |

三种环境默认都使用 Fake。环境名称不改变原生应用标识、签名、flavor 或 scheme，也不会自动连接生产服务。构建变量是公开配置，不能保存秘密。

```sh
flutter run -d <device-id> --dart-define=APP_ENV=staging
```

使用真实数据源时，将以下变量设置为你控制的实际 HTTPS 服务地址，再执行命令：

```sh
read -r -p '实际 API 基础地址: ' api_base_uri
flutter run -d <device-id> \
  --dart-define=APP_ENV=development \
  --dart-define=DATA_SOURCE_MODE=api \
  --dart-define=API_BASE_URI="$api_base_uri"
```

Fake 模式不接受非空地址。API 模式拒绝缺失地址、占位域名、HTTP、用户凭据、查询、片段和末尾点号域名；非法值进入启动配置失败页。开发环境也不默认放宽 HTTP；本机明文调试需在自己的项目中单独设计平台例外。

当前 API 示例向基础路径下的 `items` 发起 GET，期望 JSON 数组，例如 `[{"title":"示例"}]`。客户端会补齐基础路径末尾 `/`，关闭自动重定向；默认连接超时 10 秒、接收和发送超时各 30 秒。超时参数位于 `ExampleClientOwner` 构造函数，不是现有编译变量。Fake 模式不创建 Dio；API 客户端按需创建。

## 新增页面和本地化

### 添加文案

在 `lib/l10n/app_en.arb` 和 `app_zh.arb` 的现有 JSON 对象内分别加入对应键；不要覆盖整个文件，注意相邻字段的逗号。

英文：

```json
"helpTitle": "Help",
"helpMessage": "Contact your application team for help."
```

中文：

```json
"helpTitle": "帮助",
"helpMessage": "如需帮助，请联系应用维护团队。"
```

```sh
flutter gen-l10n
python3 tool/check_translations.py
```

不要手改 `lib/l10n/generated`。新增带参数的文案时，同步维护两种语言的占位符元数据；新增语言还需要修改当前只处理中英文的设置选项、校验、存储解析和翻译检查，不能只添加一个 ARB 文件。

### 创建页面

创建 `lib/features/help/help_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../../l10n/generated/app_localizations.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.helpTitle),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(l.helpMessage),
      ),
    );
  }
}
```

在 `lib/app/app.dart` 导入 `../features/help/help_page.dart`，为 `AppRoutes` 增加 `static const help = '/help';`，并在现有 `_router` 的 `routes` 中增加：

```dart
GoRoute(
  path: AppRoutes.help,
  builder: (context, state) => const HelpPage(),
),
```

在 `HomePage` 的现有 `children` 中增加入口；该方法已经声明了 `l`：

```dart
FilledButton(
  onPressed: () => context.push(AppRoutes.help),
  child: Text(l.helpTitle),
),
```

`push` 保留上一级，`pop` 返回，`go` 切换当前位置。页面直接进入而没有返回栈时，应提供回首页的退路。需要恢复的业务标识使用经过校验的 path/query 参数；不要把仅放在 `extra` 的对象当作跨重启状态。

补充对应 Widget 测试，并检查中文、英文、大字体、返回和未知路由行为。主题或语言变化不应重新创建 `GoRouter`。

## 替换数据源

### 先用自己的离线实现

创建 `lib/features/example/demo_example_repository.dart`：

```dart
import '../../core/errors/app_failure.dart';
import 'example_repository.dart';

final class DemoExampleRepository implements ExampleRepository {
  @override
  Future<List<ExampleItem>> fetch(ExampleCancellation cancellation) async {
    if (cancellation.isCancelled) {
      throw const AppException(AppFailure(AppFailureKind.cancelled));
    }
    return const [ExampleItem('Demo item')];
  }
}
```

在 `lib/app/app.dart` 导入新实现，然后将已有的 `exampleRepositoryProvider.overrideWith` 替换为：

```dart
exampleRepositoryProvider.overrideWith(
  (ref) => DemoExampleRepository(),
),
```

这是对原有绑定的替换，不要为同一个 Provider 追加第二个竞争的 override。运行应用，数据示例应显示新条目。示例中的标题是数据内容；真正的界面提示仍放入 ARB。完成这个步骤后，再把自己的网络协议接入相同边界，可以分别定位界面与网络问题。

### 接入真实服务

协议接入主要修改 `ExampleApiService` 和模型解析。若沿用模板的 Fake/API 切换，保留组合层原有绑定，由 `ExampleClientOwner` 选择仓库；上面的固定 Demo 绑定会绕过该选择，接入 API 前需恢复原绑定或实现自己的工厂。

新功能可仿照示例在自己的 feature 中建立 Repository、Service 和 Provider。Service 处理 Dio 请求和协议解析，在边界把预期外部失败转换为 `AppException(AppFailure(...))`；Widget 根据稳定的失败类别选择本地化提示，不显示原始异常或服务端内容。

页面查询使用 `FutureProvider.autoDispose`，注册自身取消能力，示例在 `exampleItemsProvider`。当前根 `ProviderScope` 关闭默认自动重试；用户通过失效查询 Provider 主动重试。不得对写操作启用自动重试；断连或超时不证明服务端没有执行操作。

测试中覆盖 `exampleRepositoryProvider` 并注入可控 Fake；按需在 `test/` 新建测试，覆盖加载、空结果、失败、重试、取消和迟到结果。常规测试保持离线，不依赖真实账号或服务。

## 设置与状态管理

简单输入和动画状态可以放在 Widget；跨组件或需要协调的状态交给 Riverpod。现有应用级主题和语言由唯一的 `SettingsState` 和 `SettingsNotifier` 管理，页面通过 `settingsProvider` 读取并调用 Notifier。

设置使用 `settings.theme_mode` 和 `settings.locale` 两个非敏感偏好键。`Locale?` 为 `null` 表示跟随系统。所有写入进入应用资源持有的同一个 FIFO 队列，成功后才发布新状态；失败保留最近确认状态。页面消费 `SettingsWriteSuccess` / `SettingsWriteFailure`，取消通常静默处理。非预期编程错误交给统一错误边界，不伪装为写入成功。

新增需要持久化的设置时，同时修改状态、仓库接口、适配器、Notifier、界面与测试；在已有队列中完成候选状态计算、写入和发布。不要从 Widget 直接写偏好，也不要为每个设置键另建队列或内存状态源。

应用容器需要恢复时，先关闭入口、等待旧写入结束、经同一仓库重读，再建立新代次。不要通过直接 invalidate 设置 Provider、创建新队列或换仓库绕过在途写入。读取或写入超时不表示底层调用已经结束。恢复视图失败时提示重启，不展示旧启动快照。

普通偏好只存少量非敏感值；认证凭据和业务数据库应另行设计。修改键或格式时，先成功写入新格式再考虑删除旧数据，迁移应版本化、幂等，失败保留旧值。

## 日志与平台能力

`AppLogger` 接收固定 `DiagnosticEvent`、等级和可选堆栈，输出允许列表环境与随机诊断 ID。Debug 级别默认由构建模式控制，production 默认抑制 info。当前堆栈摘要仅保留匹配帧的序号、行号；无法匹配时输出固定标记，不能用它还原完整源码位置。

新增日志事件时，先在允许列表枚举中定义事件。不要通过事件名、异常文本或日志 sink 输出 Token、Header、URL 查询、请求体、响应体及账号资料。框架和 isolate 错误由 `installErrorHandlers` 接收，错误组件显示安全本地化提示。随机 ID 标识每次日志调用；普通启动失败记录一次，启动超时与随后迟到的底层异常分别记录，不应把日志条数直接当作独立故障数。插件原生日志和外部应用日志需另行核查。

应用信息由 `appInfoProvider` 与 `AppInfoReader` 提供，读取失败显示占位提示。外链由 `ExternalLinkOpener` 返回 opened、unavailable、failed 或 rejected，当前仅允许无凭据、查询、片段和显式端口的 HTTPS `flutter.dev` 地址。新平台插件通过适配器暴露稳定结果，UI 不直接依赖插件类型。

## 日常检查与协作

### 提交前检查

当前副本可以运行以下检查：

```sh
flutter pub get --enforce-lockfile
flutter gen-l10n
python3 tool/check_translations.py
dart format --output=none --set-exit-if-changed lib
dart format --output=none --set-exit-if-changed test
dart format --output=none --set-exit-if-changed integration_test
flutter test
flutter analyze
flutter build apk --debug
git diff --exit-code -- pubspec.lock
```

翻译检查脚本由 `python3 tool/check_translations.py` 执行；当前没有独立 Python 单元测试目录。`lib/l10n/generated/` 由 `flutter gen-l10n` 生成并通过 `.gitignore` 排除，不要手动修改或提交。CI 采用相同检查顺序，并使用 `.fvmrc` 指定的 Flutter stable 3.47.9、JDK 17 和 Android SDK。

集成冒烟测试调用真实 `main()`，默认 Fake 数据离线可用。先启动 Android 模拟器或连接设备并用 `flutter devices` 找到 `<device-id>`，再执行：

```sh
flutter pub get --enforce-lockfile
flutter test integration_test/app_smoke_test.dart -d <device-id>
```

测试开始时仅将应用自己的主题和语言偏好键设为浅色与英文，作为可重复的初始状态；不清空其他 SharedPreferences 数据，也不依赖设备上已有的这两项设置或用例顺序。该集成测试目前只在本地设备运行，模拟器 CI 尚未接入，需结合 runner 成本、运行时长和稳定性另行决定是否设为合并门槛。Android TalkBack 需在真实设备或模拟器人工检查首页导航、设置选择、数据示例状态和返回焦点顺序；Widget 测试通过不能替代该检查。

依赖有意变更时，同时维护约束和锁文件。普通开发不要通过删除锁文件或升级全部依赖来消除检查失败。不要提交缓存、构建产物、本机路径配置或签名材料；本地化输出由命令重新生成，版本管理策略由自己的项目决定。

设备检查关注启动、系统返回、主题语言切换、大字体、外链失败以及结束进程后的设置恢复。深链、多环境原生 flavor/scheme 和平板专用布局是可选扩展；`APP_ENV` 仅供应用配置读取，不会创建原生隔离。复制模板后由维护者按目标平台与设备验证所选择的扩展。编译成功不能代替设备运行验证。

## 发布与签名

应用准备分发前，完成自己的标识、名称、图标、应用版本、环境和服务配置。当前模板的 release 签名仍绑定 debug 配置；`APP_ENV=production` 不会改变签名，也不会把 Fake 自动换成 API。

本地 release 模式编译入口为：

```sh
flutter build apk --release --dart-define=APP_ENV=production
```

当前默认产物使用 debug 密钥，只适合验证。正式分发应按 [发布与签名指南](RELEASING.md) 配置应用自己的 keystore 与 release signing config，构建 APK/AAB 并核对证书指纹、版本和 application ID，然后在目标设备验证。iOS 由应用维护者在 macOS 配置 Team、证书、provisioning 和分发渠道。

密钥保存在受控环境，普通 PR 不获取发布密钥。构建完成、签名正确、设备运行和渠道接受是不同环节。应用发布前需单独验证 release 构建和设备行为。

## 版本和升级

`pubspec.yaml` 的版本是自己应用的版本。模板来源可记录为版本、commit（如有）或复制日期，后续按需选择适用的修复，无需重新生成工程。

采用模板更新时，保存当前工作（使用 Git 时可创建独立分支），比较并选择适用的补丁，保留自己的业务、标识、品牌、服务及签名。涉及设置迁移时先评估数据兼容性；代码回退不等于数据自动回退。详细升级、维护和回退步骤见 [升级指南](UPGRADING.md)。

## 常见问题

| 现象 | 优先检查 |
| --- | --- |
| 找不到生成的本地化类 | 先运行 `flutter pub get` 和 `flutter gen-l10n`，检查 ARB 语法 |
| 翻译检查失败 | 两种语言的键、元数据、占位符与新生成的未翻译报告是否一致 |
| 启动提示配置无效，重试仍失败 | 核对构建变量，修改后重新运行应用；重试不会改变编译变量 |
| 选择 production 后仍显示示例数据 | 数据源默认仍是 Fake，检查是否显式配置 API 模式 |
| API 不工作但页面 Fake 正常 | 检查合法 HTTPS 地址、基础路径与 `items` 协议、错误类别和平台权限 |
| 替换网站后无法打开 | 同时修改调用 URI 和适配器允许域名，检查返回结果 |
| 设置没有立即变化 | 先保存后更新是约定；检查写入是否完成及失败提示 |
| 重启后设置丢失 | 确认没有卸载或清数据，确认仍为同一应用标识，并记录实际设备行为 |
| Gradle 下载长时间等待 | 检查网络、仓库访问和构建日志；中止后应记录无结果，不当作构建通过 |
| release 构建成功但不能正式发布 | 核对是否仍用 debug 签名，并完成渠道和设备检查 |

## 文档分工

| 文档 | 用途 |
| --- | --- |
| 本指南 | 新同事入门和日常开发统一入口 |
| [README](../README.md) | 工程首页，按自己的应用需求维护 |
| [发布与签名指南](RELEASING.md) | 原生签名配置、产物核验和分发前操作 |
| [升级指南](UPGRADING.md) | 选择性采用模板修复、维护基线、迁移与回退 |
