# Phase 3 SPEC：设置持久化

## 治理与基线

- 治理阶段：[开发说明 §17.1 阶段 C](../flutter-template-development-revised.md#171-分阶段实施与阶段门)；范围与阶段顺序：[Phase Plan §3](../flutter-template-phase-plan.md#3-阶段计划)。行为契约见开发说明 §5.4、§7.3、§7.4、§11.2。
- Phase 2 已由用户确认完成；其未验证项仍按原记录保留。实施起点 `753392ce9e4c6efb99c1c2c9450d8b5a30c08487`，已有未提交改动：阶段计划、Phase 2 SPEC、启动及 Widget 测试，均须保留。
- 范围为偏好读取与写入、应用资源所有者 FIFO 和重建屏障；网络、业务、历史数据迁移不在本阶段。若必须改变契约或跨越阶段门，报告 `NEEDS_REVISION` 或 `BLOCKED`。
- 退出条件：§7.3 并发矩阵通过，Android 真机或模拟器跨进程重启恢复有记录；由用户明确决定阶段完成。

## 实施和验证记录

用户于 2026-11-03 表示同意 Phase 3 完成；但现行阶段 C 的退出证据尚不完整，按章程状态为 `BLOCKED`，尚不能标记阶段门通过。实施代码已提交为 `23ce1fa`；实施起点为 `753392ce9e4c6efb99c1c2c9450d8b5a30c08487`。

| 检查 | 环境与结果 |
| --- | --- |
| `flutter pub get --enforce-lockfile`、`flutter gen-l10n`、`python3 tool/check_translations.py` | Ubuntu 26.04.1、Flutter 3.47.9、Dart 3.13.7；通过，英文和中文各 17 条文案检查通过 |
| `flutter analyze` | 同上，通过 |
| `flutter test` | 同上，最终代码共 38 项通过（包括 Notifier 销毁测试） |
| `flutter build apk --debug` | 本地构建通过；[GitHub Actions run #5](https://github.com/latentpath/flutter_template/actions/runs/41584294312) 的 Android job 也通过，对应提交 `23ce1fa`。构建不能替代设备运行。 |
| iOS Simulator 构建 | [GitHub Actions run #5](https://github.com/latentpath/flutter_template/actions/runs/41584294312) 的 iOS Simulator job 通过；对应提交 `23ce1fa`，使用 CI 中固定的 Flutter 3.47.9 和 Xcode 26.6。该结果仅验证编译，不代表运行或重启恢复通过。 |
| Android 跨进程重启 | 用户于 2026-11-03 报告按手工验证步骤通过；Pixel 7 模拟器（`emulator-5554`）、Android 15（API 35），Flutter 3.47.9 / Dart 3.13.7；测试代码为基线 `753392c` 加未提交的 Phase 3 工作区改动。验证步骤使用 `adb shell am force-stop` 结束应用并重新打开；结果依据用户反馈，未另采集截图或日志。 |
| iOS 跨进程重启 | 未验证：当前没有 macOS/Xcode 或 iOS 设备；不作为阶段门；若以后需要 iOS 运行证据，可按 README 的设备步骤验证。 |

已覆盖 FIFO 跨键及失败后继续、坏值逐键回退、旧代在途写入与排队取消、排空后重读、超时不绕过屏障、Notifier 销毁后的结果与异常后队列继续。2026-11-04 在当前工作区新增同键快速写入、跨键成功合并、主动排空、意外销毁后的在途失败以及恢复视图自动化测试；本地 `flutter test` 共 43 项通过，`flutter analyze` 通过。新增测试尚无 CI 运行记录。完整 §7.3/§7.4 矩阵仍需逐项核对，真实插件失败注入尚无证据；不能仅据新增用例声称阶段门通过。

设置只保证单一资源所有者和 isolate 内顺序，插件异常可能代表写入结果不确定。当前不实现历史键迁移；未来更改格式时须设计版本化、幂等迁移。阶段完成与推进由用户明确决定。

## 2026-11-04 阶段门核对

> 以下是修复前的逐项核对快照；后续处理及当前状态见文末“边界与类型契约修复”。

核对对象为提交 `462a0e2676e3b25240547a80200891982fe02011` 的代码及测试；本次工作区还有 Phase 4 计划文档改动，不影响被核对的应用代码或测试。Flutter 3.47.9、Dart 3.13.7 下本地 `flutter test` 43 项通过，`flutter analyze` 通过。以下将已有测试与未直接证明的部分分开记录，测试名称见 `test/app/settings_test.dart`、`test/app/settings_persistence_test.dart` 和 `test/widget_test.dart`。

| §7.3/§7.4 设置契约 | 现有证据与限制 |
| --- | --- |
| 跨键 FIFO、前项成功后合并、同键不合并 | `serializes cross-key writes...`、`successful cross-key writes...`、`same-key writes...`：受控写入验证调用顺序、提交前旧状态和最终状态；本地通过。 |
| A 成功、B 失败保留 A；失败后继续 | `serializes cross-key writes...` 覆盖；Widget 测试 `failed setting write...` 覆盖失败提示和确认值保留。测试通过，不等于真实插件故障已注入。 |
| 主动关闭入口、排空既有命令 | `active drain finishes accepted commands...` 覆盖入口关闭后拒绝新命令及既有任务按序结束；尚未在应用资源所有者销毁仓库的完整链路上直接断言释放发生在排空之后。 |
| 意外销毁、待执行取消、在途成功或失败、排空后同仓库重读 | `abandoned generation...`、`disposed notifier...` 和 `failed in-flight write...` 覆盖主要顺序和结果；`recovery view remains...` 覆盖恢复视图及重读后的首页。尚未直接测试恢复读取尚未结束期间，新命令被拒绝以及读取结束后才开放入口。 |
| 超时不绕过旧写入 | `recovery timeout does not bypass...` 在超时后断言队列关闭、未读取；未直接断言超时后重复恢复时仍不能绕过屏障，也未覆盖实际 5 秒后的失败界面。 |
| 已销毁状态及 Widget 上下文 | `disposed notifier...` 覆盖销毁后的成功结果和新快照；实现中 `ref.mounted` 及 Widget 的 `mounted` 检查可见。尚缺 Widget 在保存等待时卸载后完成或失败的直接测试。 |
| 意外编程错误与 Future 归属 | `unexpected task error does not poison FIFO` 验证队列任务异常归属调用方及后续任务执行；尚缺从实际设置 UI 触发非预期错误并确认交给错误边界的测试。 |
| 读取失败、坏值和不重试 | 启动测试覆盖仓库读取失败/超时回退且不回写；偏好测试覆盖单键类型错误回退且保留另一键。写入失败测试验证后续可继续；尚未通过计数明确断言实际插件适配器读写异常转换及写失败无自动重试。 |

**类型契约偏差：**开发说明 §7.3/§10.4 描述带 `AppFailure` 的 `AppException` 和 `SettingsWriteFailure`；当前设置模块使用不携带类别的 `SettingsStorageException`，以及独立的 `SettingsFailureKind`。调用方仍可区分写失败和取消，但底层读写异常并不携带规范所述失败类别，不能称为完全符合类型契约。需在适用范围内修复并验证，或先按章程修订契约并完成审批；不能只凭测试通过将该偏差标为已解决。

**Android 重启证据：**上表已有用户报告的跨进程重启记录；没有截图或日志，验证对象为 `753392c` 加当时未提交改动，记录不足以证明与最终提交 `23ce1fa` 完全一致。`23ce1fa` 到 `462a0e2` 无 `lib/`、Android/iOS 工程、依赖清单或锁文件差异；这不能反向证明当时未提交快照与 `23ce1fa` 一致。应核对当时验证代码；无法确认时针对明确提交重新执行 README 的 Android 重启步骤并记录结果。iOS 重启不阻塞。

**CI：**[run #6](https://github.com/latentpath/flutter_template/actions/runs/41791684031) 对应 `462a0e2`，Android job 全部通过，包含新增测试和 debug APK 构建；iOS Simulator job 通过编译，不代表设备运行。真实插件故障注入尚无证据；阶段 C 的明文退出条件并未将其单列为必做项，应作为验证限制记录，不能以 Fake 结果宣称真实插件失败已验证。

**当前结论：**并发矩阵大部分核心场景已有本地和 CI 证据，但上述直接测试缺口和类型契约偏差尚未解决；Android 验收对象对应关系仍需确认。保持 `BLOCKED`，不因本次核对改变用户 2026-11-03 已表达的完成意愿，也不推断已批准推进下一阶段。

## 2026-11-04 边界与类型契约修复

- 在 `lib/core/errors/app_failure.dart` 定义 `AppFailureKind`、`AppFailure` 和携带安全失败类别及受控原始诊断的 `AppException`；偏好读取/写入失败分别转换为 `storageRead`/`storageWrite`，已转换的应用异常不再重复包装。设置命令结果使用 `AppFailure`，不向 UI 传递插件类型或原始异常。`invalidValue` 用于现有设置输入校验。
- 新增测试覆盖：资源释放等待已接受写入；恢复重读未完成时拒绝命令；超时后重复恢复仍不能绕过旧写入；5 秒后显示恢复失败与重启提示；保存期间页面退出后写入成功/失败；非预期错误交给 Flutter 错误边界；插件平台接口替身的读取和写入异常转换、失败写入仅调用一次。原有并发和设置测试继续执行。平台接口替身不等于真实设备插件故障注入。
- 验证对象：`462a0e2676e3b25240547a80200891982fe02011` 加本次未提交工作区改动；Flutter 3.47.9 / Dart 3.13.7，`flutter analyze` 通过，`flutter test` 50 项通过。此前 [CI run #6](https://github.com/latentpath/flutter_template/actions/runs/41791684031) 仅覆盖基线提交，不包含这次修复；最终代码仍需新的 Android CI 证据。
- `flutter build apk --debug` 本地通过；`build/app/outputs/flutter-apk/app-debug.apk` 的 SHA-256 为 `c4a77cc54953cc998118bbb0e57597486a41d67758b6ca801cbff1a435b49f89`。构建不证明设备运行；核对时 `adb devices` 无已连接设备。
- Android 跨进程重启：用户于 2026-11-04 报告在 Pixel 7、Android 15.0（API 35）按此前提供的 APK 安装及 `adb shell am force-stop` 步骤验证，两轮均通过：深色主题与手动语言重启恢复、主题与语言均跟随系统重启恢复。验收对象为上条记录的工作区构建 APK；该 APK 在记录时重新计算 SHA-256，结果一致。证据为用户反馈，未另采集截图或日志。
- 当前修复代码的 Android 手工重启已通过；最终代码对应的 GitHub Android CI 已通过，见下方记录。iOS 运行和重启未验证且不阻塞。

### 修复代码 CI 跟踪

- 修复与测试已提交为 `fc389f9cd17007e0a414c0fcfb6cf122fc0a62af`；[GitHub Actions run #7](https://github.com/latentpath/flutter_template/actions/runs/41794307850) 对应该提交。2026-11-04 核对：Android job 完成并通过，包括严格锁文件解析、本地化生成与翻译检查、静态分析、测试和 debug APK 构建。iOS Simulator job 也通过构建；编译不代表设备运行或重启验证。
- Phase 3 原记录的并发证据、类型偏差及 Android 重启验收对象缺口已按上述记录处理；结合用户于 2026-11-03 已明确表达的完成决定，Phase 3 标记为已完成。真实插件故障注入未验证，作为限制保留；不因此声称已验证真实插件失败行为。阶段完成不自动推断已获准推进 Phase 4。
