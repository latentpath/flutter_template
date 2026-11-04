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
