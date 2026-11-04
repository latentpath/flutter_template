# Phase 2 SPEC：启动与核心界面执行计划

> 2026-11-04 治理修订：本文的阶段要求和验证计划为历史记录；现行验证范围以 [开发说明 §1.3–1.4](../flutter-template-development-revised.md) 和 [阶段计划](../flutter-template-phase-plan.md) 为准，iOS 验证不再是阶段门。

> 日期：2026-11-02
> 状态：已完成（用户确认，2026-11-03）；核心实现及双平台 CI 已验证，本地补充行为测试已通过。未验证项与范围限制保留在记录中，不代表 Android/iOS 真机、设备级网络隔离或 Phase 3 能力已验收。
> 目标工程：`/home/chunmli/Development/apps/Flutter/flutter_template`

## 治理依据与前置条件

- 治理阶段定义路径：[开发说明 §17.1](../flutter-template-development-revised.md#171-分阶段实施与阶段门) 的 B（启动与核心 UI）；任务范围及顺序：[Phase Plan §3](../flutter-template-phase-plan.md#3-阶段计划) 的 Phase 2。
- 实施契约：[开发说明 §5–9](../flutter-template-development-revised.md#5-启动流程与环境配置)，尤其是 §5.4 启动状态机、§6 路由、§7 设置与生命周期，以及 §8–9 主题和国际化；验证和证据遵循 §14、§17。
- [Phase 0](phase-0-implementation-baseline.md) 和 [Phase 1](phase-1-minimal-skeleton.md) 已由用户确认完成。Phase 1 记录提交 `bed7df4` 的双平台 CI 证据；实际实施前仍须检查当前工作区、锁文件、工具链及 CI 配置，不把历史结果当作 Phase 2 的结果。
- 本文仅规划 B 阶段和 Phase 2。阶段完成与推进均由人明确决定；若发现必须修改阶段契约、跨入后续阶段或前置阶段门不成立，按 Harness 工作流报告 `NEEDS_REVISION` 或 `BLOCKED`，先解决再继续。

## 目标、范围与边界

交付默认离线运行的应用外壳：可恢复的启动流程、稳定的 Riverpod 容器和路由、首页/设置/未知路由页面、三种主题模式及中英文和跟随系统的语言选择。设置通过可注入的内存 Fake 仓库读取和写入，重启恢复不属于本阶段承诺。

- 保留 Phase 1 已实现的 `AppConfig` 解析及其测试，将其接入启动协调；非法配置进入安全失败页，不回退生产环境。
- 本阶段不接入真实偏好插件、不实现跨进程恢复、迁移或 §7.3 完整写入排空与重建屏障；这些属于 Phase 3 / 阶段 C。Fake 不得被描述为真实持久化证据，也不得作为绕过后续协议的理由。
- 不实现 Dio/API 示例、应用信息、外链、通用网络状态组件、认证或业务功能；这些属于后续阶段或按需模块。已锁定依赖不因存在而被视为已使用或验证。
- 以已锁 Flutter、Riverpod、go_router 和 intl 为基线；若确需变更依赖或工具链，先按章程说明必要性、替代方案、平台影响和验证，不能静默升级。

## 执行步骤

### 1. 建立实施基线

1. 检查 `git status --short`、`.fvmrc`、`pubspec.lock`、现有入口、配置解析、测试和 CI；保留已有工作区改动，记录实施起点。
2. 核对固定 SDK 的实际版本及锁定依赖 API，尤其是 Riverpod 3 的全局重试配置、go_router 导航与释放、gen_l10n 参数。记录与 Phase 1 基线的差异和环境限制。
3. 拆分以下增量并随实现补测试；不提前标记完成。文件布局服从现有结构和职责，避免为空层创建目录。

### 2. 启动协调与资源所有权

1. 入口初始化 Flutter 绑定，安装一次安全的框架和主 isolate 异常处理入口，仅调用一次 `runApp`。遵循 §5.1 和 §13.2 的脱敏规则，不先输出原始异常或堆栈；不引入默认自定义 Zone。
2. 以可注入 Bootstrap、时钟/计时机制和资源工厂实现 `initializing → ready | failed`，失败后仅由用户触发重试；加载、失败界面不依赖尚未建立的 ProviderScope 或路由。失败页提供安全类别、本地基础文案和重试，双击只触发一次在途初始化。
3. 每次尝试解析配置、创建 Fake 仓库、读取规范化快照并创建必要依赖；Fake 读取失败或偏好读取预算超时按默认跟随系统快照继续，不回写默认值。配置错误及关键依赖创建失败显示失败页。启动等待预算分别为偏好初始化/读取合计 2 秒、完整尝试 5 秒。
4. 每次尝试独立身份与资源栈；失败按创建逆序幂等清理，成功后转交应用资源所有者。超时不等于取消：隔离迟到成功、接收迟到异常并清理旧资源；不可隔离且仍在运行的初始化不得并发重试，提供等待或重启提示。同步初始化不得长时间阻塞主 isolate。
5. ready 后注入同一配置、Fake 仓库和初始快照；使用稳定 ProviderScope 并全局关闭默认自动重试。主题或语言变化不重建协调器、容器或路由器；由明确的拥有者释放路由和其余资源。

### 3. 设置状态与 Fake 边界

1. 定义不可变且可比较的 `SettingsState`：`ThemeMode` 和 `Locale?`；`null` 表示跟随系统，手动语言只接受 `zh`、`en`。设置仓库提供读取及按键写入接口，由组合层注入；UI 不访问具体实现。
2. 应用级 Settings Notifier 是唯一展示状态源，从启动快照初始化。选择操作先经 Fake 仓库写入，成功后才发布状态；预期失败返回明确结果，保留最近确认状态，UI 显示本地化失败提示和适当的保存中反馈。不自动重试副作用。
3. 即使 Fake 写入通常立即完成，也须串行处理已提交的设置命令，使跨键更新基于最近确认状态，失败不阻断后续命令；测试可控延迟和失败。此阶段的内存实现不宣称完成 §7.3 所有代次、排空与重建协议；不提供可绕过在途写入而主动重建 Notifier/容器的入口。Phase 3 在接入真实存储前实现并验证完整资源所有者 FIFO 与重建屏障。
4. Fake 仅存在于当前应用生命周期，不创建插件实例或访问网络；覆盖可替换接口，供启动和 Widget 测试注入故障与受控结果。

### 4. 路由、页面、主题与国际化

1. 建立单个生命周期稳定的 `GoRouter` 和集中路径：`/` 首页、`/settings` 设置、其他路径的本地化未找到页。首页用 push 打开设置；设置返回时有栈则 pop，否则回首页；未知路径提供回首页操作。测试主题/语言变化不重建路由或丢失当前页面和返回栈。
2. 提供 Material 3 明暗主题、`system` / `light` / `dark` 三种选项；根组件绑定 `theme`、`darkTheme`、`themeMode`。系统模式响应平台亮暗变化，手动模式不被系统变化覆盖。
3. 配置 `flutter.generate`、`l10n.yaml`、英文模板 ARB、完整简体中文 ARB 和项目内生成路径 `lib/l10n/generated`；生成物不提交。根组件使用生成的 delegates 和 supported locales，明确英文回退；所有页面可见文案和无障碍标签进入 ARB，启动失败页使用独立基础文案以免依赖未初始化的应用容器。
4. 语言选项为跟随系统、简体中文、English；系统变化只影响跟随系统模式，未知系统语言回退英文。验证长文案、大字号、窄屏和滚动可访问；不宣称完成后续平台全面无障碍验收。

### 5. 测试、CI 与文档

- 单元测试：配置到启动的成功/失败路径；2 秒与 5 秒预算；逐步骤失败、逆序及幂等清理、双击重试、连续重试、迟到成功/异常与不可隔离任务；Fake 读取降级；设置校验、保存成功/失败、跨键和同键顺序及失败后继续。采用可控时间、Completer 和计数 Fake，确保所有异步结果有归属。
- Widget 测试：无 ProviderScope 的启动失败页及重试；成功只创建一个容器和路由；首页到设置再返回、直接进入设置的退路、未知路径恢复；主题与语言的系统/手动变化、英文回退、切换时路由栈稳定；保存失败提示及状态不变；窄屏与大字号关键操作可见或可滚动。
- 离线验证：默认三种环境均为 Fake 配置；检查启动依赖图不创建网络客户端或后台请求，并以可观测请求的测试或隔离网络运行记录佐证。配置解析测试覆盖非法值；不以静态分析单独证明无外部请求。
- 更新 README 的生成、运行与测试步骤；CI 在分析和构建前显式执行 `flutter gen-l10n`，并检查翻译缺失和生成错误。检查干净检出可重新生成文件，不依赖本地生成缓存。
- 运行适用检查：`flutter pub get --enforce-lockfile`、`flutter gen-l10n`、`flutter analyze`、`flutter test`、`flutter build apk --debug`；在 macOS/Xcode 执行 `flutter build ios --simulator --no-codesign`，或通过现有固定版本 CI 取得证据。记录实际工具链、代码版本和结果；无对应环境则标记未验证。

## 验收与阶段门

| 条件 | 所需证据 | 状态 |
| --- | --- | --- |
| 启动失败可恢复，超时、迟到结果和资源清理符合 §5.4 | 本地 Widget/单测覆盖配置失败重试、完整启动超时、迟到成功资源清理、迟到异常接收、偏好读取失败/超时降级不回写、逆序幂等释放、双重触发防重及旧任务结束前禁用重试；逐初始化步骤失败矩阵仍未覆盖 | 部分验证 |
| 首页、设置、未知路由及返回行为正确；切换设置后导航栈稳定 | Widget 测试覆盖首页进设置再返回、直接进入设置的回退、未知路由恢复、主题和语言变化留在当前页；320×220 窄视口及 2 倍文字缩放下首页设置入口可访问 | 已验证（Widget） |
| 三种主题、中英文及跟随系统行为正确；失败不显示成功 | Widget 覆盖系统亮暗变化、手动亮色锁定、系统中文变化及未知语言英文回退；手动主题/语言切换、设置队列失败和写失败提示及状态保留均有测试 | 已验证（Widget） |
| 默认离线启动，无外部请求 | 默认 Bootstrap 启动 Widget 时通过 `HttpOverrides` 计数并禁止创建 `HttpClient`，观察到创建数为 0；未做设备级抓包或系统层网络隔离运行 | 已验证（测试范围内） |
| 干净检出生成、分析、测试及 Android debug / iOS Simulator 构建 | 提交 `753392c` 的 GitHub Actions run #4 中 Android 与 iOS Simulator job 均通过；本地严格锁文件解析、生成、翻译检查、分析、33 项测试及 Android debug 构建通过。新增测试尚未进入 CI；当前工作区有未提交测试改动 | 已验证（CI/本地；新增测试仅本地） |
| 阶段审阅与完成决定 | 用户于 2026-11-03 明确确认 Phase 2 完成 | 已确认完成 |

本阶段完成可为 M1 可运行外壳提供证据；不证明真实存储、跨重启恢复、平台插件运行、真机或发布验收。设置队列完整并发矩阵与 Android 重启验证是修订后的 Phase 3 退出条件；iOS 重启验证不阻塞。

## 实施记录与未解决项

| 项目 | 记录 |
| --- | --- |
| 实施起点 / 最终代码版本 | 实施起点 `3980aa2`；核心实现提交 `753392c`；本次测试补充仍在工作区，未提交 |
| 执行环境、设备和工具链 | Linux；Flutter 3.47.9 stable，Dart 3.13.7；本机无 Xcode。Android/iOS Simulator 在 GitHub Actions 固定 `.fvmrc` 工具链 job 验证 |
| 命令、实际结果及日志/CI 链接 | 见下方 2026-11-03 补充记录；CI [run #4](https://github.com/latentpath/flutter_template/actions/runs/41375495825) |
| 偏离、未验证项及补验方式 | 逐初始化步骤故障矩阵尚不完整；无设备手动验收和设备级网络隔离记录。详见 2026-11-03 补证记录 |
| 阶段审阅与用户确认 | 用户于 2026-11-03 确认 Phase 2 完成；未确认推进 Phase 3 |

### 2026-11-02 执行记录

- 实施起点：`3980aa2`；初始工作区仅有本 SPEC 未跟踪文件。工具链 `.fvmrc` / `pubspec.lock` 与本机 Flutter 3.47.9、Dart 3.13.7 一致；未升级依赖。
- 已实现入口异常边界、可注入启动协调器和预算、资源回收、Fake 设置仓库、Provider 注入、唯一设置状态、FIFO 设置写入、稳定路由器、首页/设置/未知路由、Material 3 主题及英文/简体中文 ARB。
- 本地命令：`flutter pub get --enforce-lockfile`、`flutter gen-l10n`、`python3 tool/check_translations.py`、`flutter analyze`、`flutter test`、`flutter build apk --debug`。锁文件未变；生成/翻译检查通过（17 条消息）；分析无问题；24 项测试通过；Android debug 构建通过。
- Android：`flutter build apk --debug` 通过，产物 `build/app/outputs/flutter-apk/app-debug.apk`。iOS Simulator：本机为 Linux，无 Xcode，未验证；补验命令为 `flutter build ios --simulator --no-codesign`，或在固定版本 macOS CI 执行。
- 用户先要求暂时跳过 CI，之后通知 CI 已恢复。当前修改工作区没有 CI 运行证据；本地环境没有 `gh` CLI，GitHub 连接器没有 workflow-dispatch 操作，且没有推送工作区改动。工作流已更新为先生成本地化并检查翻译。没有进行设备手动点击/系统主题语言验收。
- 离线边界：`DefaultBootstrap` 只创建内存 Fake；`rg -n 'Dio|package:http|HttpClient|https?\\.get' lib` 无匹配。尚未进行隔离网络抓包/运行观察，故无外部请求证据仍需补充。
- 未解决：启动逐步骤失败及双击重试边界尚未完整测试；没有运行中启动到设置的真机/模拟器验收；Phase 3 的持久化、重建排空屏障明确未实现。iOS 原生语言声明已加入，但本机为 Linux 且无 Xcode，尚未执行 iOS 构建或系统语言运行验证。

### 2026-11-02 缺陷修复记录

- iOS `knownRegions` 和 `CFBundleLocalizations` 增加 `zh-Hans`；Python `plistlib` 成功解析 `Info.plist` 并确认本地化列表为 `en`、`zh-Hans`。iOS Simulator 构建及设备语言切换仍待 macOS 验证。
- 超时启动的迟到资源现在在 `dispose()` 完成前持续占用启动屏障；Widget 测试用 Completer 延迟清理，确认清理期间重试按钮禁用，释放完成后才允许新尝试。
- 首页增加受视口约束的滚动容器；Widget 测试以 320×220 视口和 2 倍文字缩放验证无溢出且可打开设置。
- 本地 `flutter analyze` 无问题、24 项 `flutter test` 通过；`flutter build apk --debug` 通过。CI 尚无本次修改的运行结果。

### 2026-11-03 阶段门补证

- 补充 Widget/单元覆盖：必需依赖创建失败显示安全错误并可重试；启动重试双触发只启动一次；迟到启动异常被接收且未完成任务结束前禁用重试；偏好读取超时降级且不回写；系统亮暗变化与手动主题；系统语言切换和未知语言英文回退；设置写入失败显示本地化提示且保留已确认值；直接进入设置时返回首页；默认 Bootstrap 启动期间 `HttpOverrides` 观察到 `HttpClient` 创建次数为 0。
- 本地验证：`flutter pub get --enforce-lockfile`、`flutter gen-l10n`、`python3 tool/check_translations.py`、`flutter analyze`、`flutter test`、`flutter build apk --debug` 全部通过；最终测试 33 项。工具链 Flutter 3.47.9 / Dart 3.13.7；锁文件未发生有意修改。Android 产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- GitHub Actions [run #4](https://github.com/latentpath/flutter_template/actions/runs/41375495825)，对应提交 `753392c`，Android 与 iOS Simulator jobs 均成功。该运行验证已提交核心实现；本次工作区新增的测试用例尚未在 CI 运行。当前 Linux 无 `xcodebuild`，未在本机重跑 iOS。
- 离线证据目前是 Widget 测试中对 Dart `HttpClient` 创建的可观测拦截，支持“默认启动不创建 HTTP 客户端”的范围；没有系统级隔离网络或 Android/iOS 设备抓包记录。
- 用户补充的 Flutter Web 浏览器截图显示应用可进入设置页，简体中文已生效且主题选项为“跟随系统”；这是当前 Web 会话的人工视觉观察，不验证重启恢复、系统设置变化或 Android/iOS 设备行为。
- 保留限制：启动每个初始化步骤失败的完整矩阵仍未覆盖；没有 Android/iOS 设备手动点击验收或系统设置主题/语言操作记录，也没有设备级网络隔离证据。迟到异常、迟到资源清理以及旧任务结束前重试锁已有 Widget 覆盖。上述限制不改变用户对 Phase 2 的明确完成决定；真实存储和设置重建屏障仍属于 Phase 3。
