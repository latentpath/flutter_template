# Phase 4 SPEC：网络与通用组件计划

> 日期：2026-11-04  
> 状态：实施中；用户于 2026-11-04 要求执行本 SPEC，Phase 4 尚未验收完成。

## 治理依据与前置条件

- 治理阶段定义路径：[开发说明 §17.1 阶段 D](../flutter-template-development-revised.md#171-分阶段实施与阶段门)；工作范围与顺序：[Phase Plan §2–3](../flutter-template-phase-plan.md#3-阶段计划) 的 Phase 4。行为契约为开发说明 §10、§12.1、§13、§14；平台验证范围以 §1.3–1.4 及项目章程为准。
- 阶段 D 规定网络示例与错误边界。Phase Plan 的 Phase 4 还安排应用信息、外链和安全日志；它们支持网络示例及模板通用能力，但 §17.1 未将其单列在 D。这里仅提出在 Phase 4 实施的范围供审阅；阶段计划已将其明确安排在 Phase 4；用户要求执行本 SPEC，按阶段 D 示例的配套能力实施，不据此推断阶段 E/F 已完成。
- [Phase 3](phase-3-settings-persistence.md) 已按用户此前的完成决定及补齐的阶段门证据标记完成；真实插件失败注入与 iOS 重启未验证，限制见其记录。用户于 2026-11-04 要求执行本 SPEC，作为推进 Phase 4 的决定。
- 实施前重新核对工作区、锁文件、工具链、CI 和前序证据；保护已有改动。当前 `AppConfig` 已提供 Fake/API 模式及严格 HTTPS 校验；`AppException` 和 `AppFailure` 已移至公共错误类型，设置使用其中的存储失败类别，扩展网络错误边界时须兼容已有设置失败与队列契约。Dio、`package_info_plus`、`url_launcher` 已列入依赖和锁文件，不等于其运行行为已验证。

## 目标与边界

提供可离线运行、可替换的最小数据访问示例：默认 Fake 展示数据；显式 API 模式通过注入的客户端展示相同数据契约。页面通过 Provider/Notifier 和 Repository 获取数据，展示加载、内容、空、错误和用户主动重试；预期取消通常静默处理。应用信息读取失败不阻塞启动，外链失败给出本地化反馈，日志只输出安全诊断。

不接入真实业务服务、认证、后台同步、缓存、自动重试、上传下载、数据库、权限功能或第三方日志服务。不假设统一业务响应外壳。Phase 5 的整体平台验收与 Phase 6 的模板实例化仍单独进行。新增或升级依赖、改变配置契约或阶段范围时，先说明必要性、替代方案、平台影响及验证，按治理流程处理。

## 实施步骤

1. **基线和契约**：记录代码版本、Flutter/Dart、依赖锁定版本与工作区状态；检查现有错误类型、启动资源所有权和 Provider 生命周期。梳理 `AppFailureKind`、`AppFailure`、`AppException` 的公共归属，迁移设置边界时保持原有存储异常处理、FIFO 和失败结果行为，运行设置回归测试。
2. **配置与网络生命周期**：沿用单一 `AppConfig`；Fake 模式不解析占位地址、不创建 Dio 或 API Service。API 模式校验 HTTPS、host、凭据、查询和片段等，非法配置走现有安全启动失败路径；定义可配置连接、接收、发送超时（起点分别为 10、30、30 秒）。相对路径不得意外覆盖基础地址，绝对地址须经受控校验。已有配置严格拒绝 HTTP；如需本机 HTTP 例外，先提出明确的开发环境限制及平台影响，不能自行放宽。客户端由明确所有者按需创建并关闭。
3. **数据边界与示例**：定义小而稳定的示例数据和 Repository 接口、内置 Fake 与 API 实现；API Service 负责协议解析并在外部边界映射 Dio 和解析异常，Repository 不重复包装 `AppException`。不内置生产地址或凭据；通过可注入 adapter 和固定测试响应验证 API 路径，不访问公网。覆盖取消、各类超时、连接、401/403/404/429、5xx、无效响应和未知失败；UI 仅使用失败类别映射本地化文案。
4. **请求协调与页面**：页面或 Provider 持有并释放自己的取消权；共享请求若存在须明确所有权。旧查询迟到不能覆盖较新的结果；取消不显示网络错误。建立可复用但不过度抽象的加载、空、错误及主动重试组件，在示例页面展示并补齐中英文和无障碍文案；保留 ProviderScope 全局禁用自动重试，写操作不自动重试。
5. **平台适配与安全日志（以阶段范围确认结果为前提）**：通过可替换接口封装应用名称、版本和构建号读取，失败展示占位文案；外链使用预设 URI，显式限制 scheme/host，将成功、不可处理和异常转换为可处理结果，不将 `canLaunchUrl == false` 泛化为全部打开方式不可用。审查目标平台配置和插件权限/隐私影响。以注入式 `AppLogger` 和字段允许列表记录安全类别；检查启动、Flutter 框架、主 isolate、网络与错误界面，不输出原始异常、堆栈、请求/响应体、Header、完整查询或模拟敏感值，过滤器故障时仅输出固定类别；不引入日志 SDK。
6. **文档与持续验证**：随增量补充单元和 Widget 测试，更新 README 的 Fake 默认运行、显式 API 配置、替换数据源和验证方式；检查 CI 覆盖新增测试。若需要新的原生权限或配置，记录用途、替代方案和平台影响。每个增量保留命令、实际结果和限制。

## 验证计划与退出条件

所有条目初始为**待验证**；测试使用 Fake、受控 adapter 或插件替身，不依赖公网和真实账户。不能用静态检查或构建成功代替运行证据。

| 验收项 | 可复核证据 |
| --- | --- |
| 默认 Fake 离线启动并展示数据 | 测试三种环境的默认依赖图，断言未创建客户端/服务及未发出请求；Android 模拟器或设备在断网状态启动并展示数据，记录设备、系统和操作。测试及断网结果各自注明观察范围。 |
| 配置和客户端生命周期 | 单测覆盖空值、非法 scheme/host、凭据、查询、片段、占位地址、Fake 与 API 分支、超时配置、相对路径和资源释放；实际允许的地址规则以实现和批准契约为准。 |
| 失败映射与取消 | 受控 adapter 覆盖上述 HTTP/传输/解析类别、取消及不重复包装；校验展示层无 Dio 类型、原始服务端信息或堆栈。验证释放时取消及旧结果不覆盖新结果。 |
| 状态组件与无自动重试 | Widget 测试覆盖加载、内容、空、错误、本地化重试及静默取消；以调用计数验证失败后不自动重试、用户主动重试才发起新查询；写操作保持无自动重试。 |
| 应用信息和外链 | 可注入替身测试读取成功/失败以及外链成功、不可处理、异常和拒绝不允许的 URI；Android 上记录版本信息和外链失败反馈的可重复操作与结果。 |
| 安全日志 | 在异常消息、上下文、附加诊断和堆栈注入模拟 Token，捕获并检查 AppLogger、Flutter 默认输出、主 isolate 兜底和错误界面，验证模板控制的输出无原文；单独记录无法控制的插件原生日志及平台限制。 |
| 回归与 CI | 在工程根目录执行 `flutter pub get --enforce-lockfile`、`flutter gen-l10n`、`python3 tool/check_translations.py`、`flutter analyze`、`flutter test`、`flutter build apk --debug`；保留设置、启动、路由和国际化回归。最终代码对应的 GitHub CI Android 检查需通过并记录链接。 |
| 阶段审阅 | 记录最终代码版本、工具链、命令、结果、Android 设备及系统、证据位置、偏离和未解决项；由人明确决定阶段完成及是否推进。 |

iOS 构建和运行是可选补充；未执行时标记未验证，不阻塞阶段门，也不声称通过。Phase 4 的局部设备检查不代替 Phase 5 的整体平台验收。

## 实施记录

| 项目 | 状态 |
| --- | --- |
| 计划和阶段范围审阅 | 用户要求执行 SPEC；配套能力依 Phase Plan 纳入本次范围 |
| Phase 3 阶段门与 Phase 4 推进决定 | Phase 3 证据已补齐；用户要求执行 Phase 4 |
| 实施起点 / 最终代码版本 | 起点 `fc389f9cd17007e0a414c0fcfb6cf122fc0a62af`；最终版本尚未提交 |
| 命令、设备、实际结果及 CI 链接 | Flutter 3.47.9 / Dart 3.13.7：锁文件解析、翻译检查、`flutter analyze`、`flutter test` 79 项通过；应用信息已在 Android 模拟器检查；最终代码 CI 待验证 |
| 偏离、未解决项与补验方式 | 最终代码 CI 尚待验证；日志注入已覆盖受控模板路径，但插件原生日志不受模板控制；iOS 未验证。Android 主 manifest 新增 INTERNET 普通权限供显式 API 模式使用，Fake 不发请求；不使用权限则无法访问远程 API。 |
| 阶段完成和推进决定 | 待人明确决定 |

实施时工作区已有本 SPEC、Phase 3 SPEC 和阶段计划的未提交修改，保留原有内容。`package_info_plus`、`url_launcher` 和 `dio` 使用现有锁定版本，未增加依赖或升级工具链。

### 2026-11-04 本地增量验证

- 未提交工作区代码；Flutter 3.47.9 / Dart 3.13.7。`flutter pub get --enforce-lockfile`、`flutter gen-l10n`、翻译检查、`flutter analyze`、`flutter test`（70 项）、`flutter build apk --debug` 成功。构建含 Android 主 manifest 的 INTERNET 权限。
- Android 模拟器 `sdk gphone64 x86 64`、Android 15 / API 35：安装 debug APK；启用飞行模式、结束进程并启动，UI 层级显示首页；在飞行模式下点击“Data example”，UI 层级显示 `Flutter` 和 `Riverpod`。之后关闭飞行模式恢复原状态。这只记录该次离线启动与展示，不证明 API、外链或插件失败行为。
- 配置及错误映射测试通过受控 Dio 拦截器，不访问公网；尚未验证完整 SPEC 矩阵。GitHub CI 尚无对应工作区代码的运行记录，iOS 未验证。阶段完成须另由人审阅决定。

### 2026-11-04 后续代码与测试

- 提取加载、空与错误重试组件，按失败类别提供中英文文案；API Service 负责协议解析和外部异常分类，Repository 保持已有失败对象。启动、网络、框架、主 isolate 和错误界面记录固定日志类别。
- 新增受控适配器取消和关闭、错误透传、应用信息替身、外链失败界面、日志路径及模拟敏感值测试；使用固定响应和替身，不请求公网。
- Android 15 / API 35 模拟器安装本次 debug APK，打开设置页，UI 层级显示 `flutter_template 1.0.0 (1)`。外链失败当时仅有 Widget 替身证据；后续设备补证见下。CI 尚无最终代码记录；iOS 和插件原生日志未验证。

- 后续修改后重新执行 `flutter analyze` 和 `flutter test`：分析无问题，79 项通过；`git diff --check` 通过。此前对相同应用代码的锁文件、本地化检查和 Android debug 构建通过。

### Android 外链失败补证

- `sdk gphone64 x86 64` 模拟器，Android 15 / API 35，使用本阶段未提交工作区的 debug APK。确认 Chrome 为唯一 HTTPS 处理程序且初始状态为系统默认；临时执行 `adb -s emulator-5554 shell pm disable-user --user 0 com.android.chrome`，确认 HTTPS 无可处理 Activity；在设置页点击“Open Flutter website”，UI 层级出现 `Could not open the link.`。
- 操作结束执行 `adb -s emulator-5554 shell pm default-state --user 0 com.android.chrome`；再次确认 Chrome 状态为默认且能够解析 HTTPS。该结果只证明此模拟器无可处理程序时的反馈，不代表所有 Android 设备或其他失败原因均已验证。

提交准备审查时将示例专用客户端所有者从 `core` 移至 `features/example`，未改变请求行为；移动后 `flutter analyze`、`flutter test`（79 项）及 Android debug APK 构建通过。上面的模拟器操作使用移动前的等效应用代码。
