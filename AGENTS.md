# Project Constitution

> 项目章程依据 [docs/flutter-template-development-revised.md](docs/flutter-template-development-revised.md) 填写。该开发说明目前是设计草案，声明尚未据此完成实现和 Android/iOS 双平台验证；本章程记录目标约束，不代表功能已交付。实现状态以仓库代码、配置、锁文件和可复核的验证证据为准。开发说明与本章程冲突时，SPEC 和仓库可验证事实仍按 Harness 工作流裁决；需改变规范时先修订设计/阶段规范并完成相应审批。

## Role

- 作为 Flutter 模板的资深工程协作者，优先采用简单、可替换、可测试的实现，并保持平台行为透明。
- 按批准的任务范围增量交付；新增通用能力须有跨项目复用依据。单个派生应用的品牌、业务模型、流程和服务留在派生项目。
- 依赖新增、架构偏离和工具链升级应说明理由、替代方案、平台影响及验证结果。

## Project Objective

- 建设可复用的 Flutter 空壳应用模板，作为团队创建 Android/iOS 应用的统一起点。模板提供可独立运行的首页和设置页，以及路由、状态管理、主题与国际化、非敏感偏好、可替换网络数据源、错误处理、日志、测试和构建约定；默认启动不依赖真实业务后端、第三方账号或发布密钥。以可运行增量实现并验证各项能力，其他平台按后续需求扩展。派生应用替换品牌和标识，并在自身实现业务。

## Non-Negotiable Architecture Rules

### Layering

- Presentation / UI: Widget 负责展示、布局和收集操作；通过 Riverpod Provider/Notifier 读取状态、调用动作。用户文案使用本地化资源。页面不直接访问 Dio、插件单例或具体存储实现。
- Application / state coordination: Riverpod Provider 表达依赖，Notifier 管理跨组件或需协调的可变状态；应用组合层负责绑定接口与实现。简单、纯局部的输入和动画状态可留在 Widget。避免引入第二套 Provider 状态系统。
- Data access / repositories: Repository 提供稳定的数据和失败边界；API Service、存储适配器等数据源封装外部访问。预期外部失败在边界转换为应用失败类型；展示层不依赖 Dio 或平台插件类型。网络演示默认使用 Fake，不请求公网。
- Core / infrastructure: `app` 负责组合根组件、路由、主题和环境；`core` 仅容纳跨功能复用且职责稳定的基础设施。功能专属实现放在对应 feature。Domain/use case 按实际共享模型或业务复杂度引入，不为形式完整而增加空层。
- 依赖大体遵循 `Widget → Provider/Notifier → Repository → 数据源`；底层不依赖页面、路由或 `BuildContext`。抽象应服务于替换、隔离副作用或复用，避免无意义的转发层。

### Navigation And State

- Single source of truth: 每项应用级设置由一个不可变 `SettingsState` 和应用级 Settings Notifier 管理；持久化仓库是启动读取和写入的存储边界，不另造互相竞争的内存状态源。页面状态由对应 Provider/Notifier 管理；简单临时 UI 状态可本地持有。
- How UI reaches navigation (state-driven vs direct): 使用声明式 `go_router` 组织应用路由；页面通过路由 API 发起导航，不以导航副作用作为状态存储。无需路由的简单临时页面可用 Flutter Navigator。
- Derived-state rules: 可推导的展示值从 Provider/Notifier 状态派生，不重复保存。`Locale?` 的 `null` 表示跟随系统；用户选择只允许应用支持的语言。设置修改先持久化、成功后再发布新状态；失败保留最近确认状态并向 UI 返回明确失败。
- 设置写命令由唯一应用资源所有者持有的 FIFO 队列串行执行，按提交顺序合并跨键更新；写操作不自动重试。资源销毁/重建遵循开发说明第 7.3 节的排空和重读屏障，不能通过重建 Notifier 绕过在途写入。
- Riverpod 首版目标为 3.x，ProviderScope 全局关闭默认自动重试；仅纯查询可按明确策略选择性重试，任何副作用写操作不得自动重试。实际 API 以锁定依赖版本为准。

### Data / Offline-First Contract (if applicable)

- Write path (local / pending / sync): 首版不是离线业务数据同步系统。主题和语言等非敏感偏好写入本地 `shared_preferences` 适配器；写成功后再更新 Notifier。失败不伪装成功、不擅自重试，且不承诺插件返回成功等于设备故障下绝对落盘。
- Sync strategy: 首版不实现后台同步、待同步队列或业务缓存。网络示例通过可注入的 Fake Repository 演示，默认配置不调用外部服务；派生应用按真实服务协议自行定义同步和缓存策略。
- Compatibility rule for later phases: 设置键和格式变更必须版本化、幂等迁移；先成功写入新格式，再考虑删除旧值，迁移失败保留旧数据。首版不假设存在历史设置键。结构化离线数据、认证凭据和安全存储均为按需模块，不用普通偏好保存秘密。

### Technology Stack (Frozen)

- Language / framework: Dart（sound null safety）与 Flutter；首版目标平台为 Android、iOS，Material 3。Flutter stable 补丁版、Dart 实际版本、Android/iOS 最低版本须在实施时复核、固定并记录；开发说明中的候选版本不等于通过验证的基线。不得在 CI 浮动使用 latest。
- State management: `flutter_riverpod` 3.x；首版手写 Provider，不默认采用 Riverpod 代码生成。
- Networking: `dio`，限制在 API Service/数据边界；Fake 默认实现不创建 API Service、不访问公网。
- Persistence: `shared_preferences`（优先评估 `SharedPreferencesAsync`）只保存非敏感小型偏好；不用作数据库或安全存储。
- Routing / localization: `go_router`；Flutter `flutter_localizations`、ARB/`gen_l10n` 和 `intl`。
- Other pinned choices: `package_info_plus` 读取应用信息、`url_launcher` 打开外链、`flutter_lints` 静态检查、Flutter `flutter_test` 测试。具体依赖版本以经双平台验证并提交的 `pubspec.lock` 为准。安全存储、数据库及其他平台插件按需评估后引入，不预先安装。
- 以上是设计目标栈而非当前已验证事实。增加、替换或升级依赖时，审查维护状态、许可证、SDK/平台约束、权限、隐私和失败行为，并更新锁文件及验证记录。

## Forbidden

- UI/Widget 直接发 HTTP 请求，直接持有 Dio 或访问具体偏好/平台插件实现。
- 数据源依赖 UI、路由或 `BuildContext`；底层插件类型和原始服务端异常泄漏到展示层或用户文案。
- 将密码、Token、私钥、Cookie 或敏感请求/响应内容写入普通偏好、URL、源码或日志；客户端产物和示例配置不得被当作秘密保险箱。
- 默认启动依赖公网、真实业务 API、生产配置、第三方账号或真实签名材料；示例环境不得误指向生产服务。
- 对写操作启用自动重试，或在设置 Notifier 重建时绕过旧写入排空与同一仓库重读屏障。
- 建立多个竞争的应用级设置状态源、无依据的通用框架/领域层，或把单个业务项目的需求塞入模板核心。
- 将未实现或未验证的设计要求描述成已经交付、构建通过或设备验收通过。

## Phase Governance

- 模板首版阶段定义位于 [docs/flutter-template-development-revised.md 第 17.1 节](docs/flutter-template-development-revised.md#171-分阶段实施与阶段门)，阶段 A–F 的边界和退出条件以该节为准。本文不记录当前活动阶段；阶段状态以项目实际审批和证据为准。
- 每个任务在 SPEC 开始时识别并记录其治理阶段定义路径，核对任务范围、契约和阶段门；SPEC 记录该路径并证明工作仍在允许范围内。
- 跨越阶段范围或尚未满足的阶段门时，不得静默扩展；按 Harness 工作流返回 `BLOCKED` 或 `NEEDS_REVISION`，并说明依赖的阶段条件。
- 每阶段应记录代码、可重复命令、验证结果和未解决项。阶段完成不自动推断下一阶段通过；阶段完成与推进均须由人明确决定。
- 模板首版阶段不等于派生应用发布就绪。派生应用签名、真机 release 和渠道验证按开发说明第 17.6 节单独验收。
