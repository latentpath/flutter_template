# Phase 5 SPEC：质量与 Android 平台验收

> 状态：实施中。用户于 2026-11-06 确认 Phase 4 完成并要求执行 Phase 5。

## 治理依据与范围

- 阶段定义：[开发说明 §17.1 阶段 E](../flutter-template-development-revised.md#171-分阶段实施与阶段门)；任务范围：[Phase Plan §3 Phase 5](../flutter-template-phase-plan.md#3-阶段计划)；质量与平台契约：开发说明 §14 及项目章程的 Android 验证范围。
- Phase 5 完成模板自身质量检查、失败路径测试和 Android 验收；阶段 E 的实例化与独立应用构建依 Phase Plan 留在 Phase 6，不能据此宣称阶段 E 已全部退出。
- 基线提交 `adf371e`；开始时 Phase Plan 和 Phase 4 SPEC 有未提交修改，应保留。Flutter 3.47.9 / Dart 3.13.7；无已连接 Android 设备。Phase 4 用户确认完成，iOS 运行及插件原生日志仍有既有验证限制。
- 不增加业务能力或默认依赖，不升级工具链；默认测试不依赖网络、真实账户或签名材料。

## 实施与验收

1. 依据 §14.1 对现有单元、Widget 和设备证据建立覆盖矩阵，补齐关键缺口。
2. 完善本地化报告和翻译一致性检查，增加正反例；在 Android CI 加入格式和锁文件检查，验证各检查失败时能产生失败状态。分支保护另行核实。
3. 在 Android 模拟器或设备检查离线启动、导航与系统返回、系统主题/语言、大字体与基本无障碍、外链失败、跨进程设置恢复；记录操作、设备、版本和结果，恢复设备设置。
4. 在最终代码上运行锁文件解析、本地化生成、翻译检查、格式检查、分析、测试和 Android debug 构建；记录最终提交对应的 GitHub Android CI。iOS 非阻塞且未运行时如实记录。
5. 阶段结果由人审阅和明确决定完成；不自动推进 Phase 6。

## 实施记录

待补充实际命令、结果、设备、CI、覆盖矩阵和未解决项。

### 2026-11-06 本地结果及覆盖矩阵

代码基线 `adf371e`，本阶段为未提交工作区；Flutter 3.47.9 / Dart 3.13.7，Linux，JDK 21.0.12.1（本地 Gradle 使用 Android Studio JBR）。本阶段没有变更 Dart 应用代码或依赖锁文件。

| 契约 | 已有可复核证据或本次结果 | 待补/限制 |
| --- | --- | --- |
| 启动和配置 | `test/app/startup_test.dart`、`test/app/config/app_config_test.dart`、`test/widget_test.dart` 覆盖失败、重试、迟到清理及环境配置；本次 `flutter test` 通过 | 不以测试替代设备行为 |
| 设置和持久化 | `test/app/settings_test.dart`、`settings_persistence_test.dart` 覆盖连续写、失败、FIFO 与恢复屏障；本次设备强制结束进程后深色和简体中文选中状态恢复 | 实际插件故障注入未执行 |
| 数据、失败和日志 | `test/features/example_test.dart`、`example_page_test.dart`、`logging_paths_test.dart`、`error_handlers_test.dart` 等覆盖 Fake、错误映射、取消、重试和受控脱敏路径 | 插件原生日志不受模板控制 |
| 路由与界面 | `test/widget_test.dart` 覆盖导航、未知路由、主题、语言和短视口大字体；本次设备验证示例页系统返回及设置页可达 | 设备系统语言切换和完整无障碍人工检查待执行 |
| 翻译与工具 | `flutter gen-l10n`、`python3 tool/check_translations.py` 通过；`python3 -m unittest discover -s tool/tests` 6 项通过，含缺失/多余键、孤立元数据、占位符差异、未翻译和缺失报告反例 | CI 最终版本尚未运行 |
| 回归和构建 | `flutter pub get --enforce-lockfile`、`git diff --exit-code -- pubspec.lock`、`dart format --output=none --set-exit-if-changed lib test`、`flutter analyze`、`flutter test`（79 项）、`flutter build apk --debug` 均通过；`git diff --check` 通过 | 最终提交及其 GitHub Android CI 待验证；分支保护无法通过本机 `gh` 核验，`gh` 未安装 |

CI 已增加格式、锁文件和翻译检查自测；工作流状态失败与仓库实际启用必需状态检查是两件事。翻译反例已验证；格式、分析、测试和 Android 编译的 CI 故障注入及分支保护仍待验证，不宣称已经阻止合并。

### Android 本次观察

- `Pixel_7` 模拟器，`sdk_gphone64_x86_64`，Android 15 / API 35；本阶段工作区构建的 debug APK。通过 `adb install -r` 安装，打开飞行模式，结束进程并启动；首页可见，数据示例显示 `Flutter`、`Riverpod`。系统返回后进入设置页。
- 选择深色和简体中文，`adb shell am force-stop com.example.flutter_template` 后重启；设置页的两个对应单选项均为选中。之后将两项改回跟随系统。
- 跟随系统主题时，以 `adb shell cmd uimode night no/yes` 切换，等待 UI 层级刷新后屏幕同一点像素分别为 `(251,248,255)` / `(18,19,24)`。`font_scale=2.0` 时设置页语义树包含可聚焦的选项和外链按钮；这不证明所有页面无溢出或 TalkBack 体验通过。
- 临时禁用 Chrome 后点击外链，语义树出现 `Could not open the link.`；完成后将 Chrome 恢复默认、关闭飞行模式、恢复字体缩放 1.0 和系统浅色。模拟器首次启动曾出现 System UI 无响应对话框，选择等待后继续，不能据此推断应用失败。
- 本轮没有完成系统语言切换、TalkBack 全流程或重启后跟随系统的第二轮；上述项目仍为阶段验收待办。

### 剩余设备验收步骤

1. 在 Android 系统语言设置中将中文移至首位；应用语言选择“跟随系统”，确认首页及设置文案变为中文，再恢复原语言顺序并确认英文。记录系统版本、操作和结果。
2. 字体缩放设为 2.0，逐页滚动检查首页、设置和数据示例，确认文字不被裁切、操作可达；使用 TalkBack 检查可聚焦控件名称、选中状态和返回操作。检查结束恢复原字体设置。
3. 将主题和语言均设为跟随系统，强制结束应用进程后重新启动，确认选项及实际系统表现仍正确。勿清除数据或卸载。
4. 在最终提交运行 GitHub Android CI，记录 run 与 commit；检查分支保护的必需状态检查设置，并以隔离分支/受控夹具验证失败门禁。不可用项记录权限与后续负责人。

当前状态：实施中，Phase 5 尚未通过阶段门；阶段 E 模板实例化和独立应用 Android 构建留待 Phase 6。

### 2026-11-06 后续验收

- 同一 Android 15 / API 35 模拟器，将系统首选语言从 English (United States) 改为简体中文（中国）；应用主题和语言保持“跟随系统”，强制结束进程并重启，首页显示“首页”“数据示例”“设置”，设置页两项“跟随系统”均为选中。将系统语言切回英文后，设置页恢复英文；已移除为测试临时添加的中文语言，确认系统语言为英语。
- 系统字体缩放设为 2.0，在 1080×2400 模拟器逐页查看首页、数据示例、设置页的截图和语义树；可见内容没有裁切，导航、设置单选项和外链按钮可见。检查后恢复字体缩放 1.0。此结果仅适用于本设备尺寸、英语及当前页面状态，TalkBack 语音播报与操作体验仍需人工检查。
- 在 `/tmp` 的隔离副本上分别注入未格式化 Dart、未定义符号、必然失败的测试和无效 Android Gradle Kotlin 语法；执行与 CI 对应的 `dart format --output=none --set-exit-if-changed`、`flutter analyze`、`flutter test` 和 `flutter build apk --debug`，四项均返回退出码 1，错误输出分别指向注入的格式、分析、断言和 Gradle 编译错误。未修改工作区。翻译检查反例见前述 6 项测试；这些是本地命令失败证据，不是 GitHub 工作流或合并保护证据。
- `git ls-remote --heads origin main` 成功并确认远端仍为 `adf371e`；`GIT_TERMINAL_PROMPT=0 git push --dry-run origin HEAD:refs/heads/codex/phase5-quality` 因无法读取 GitHub 用户名而失败。GitHub 连接器不可用、浏览器访问宿主不可用，无法检查仓库权限及分支保护，也无法推送触发 CI。待配置 GitHub Git 凭据后重新验证；不要在聊天或仓库中提供 Token。

剩余阶段门：TalkBack 的语音播报和实际操作需人工检查；最终代码需推送并运行 GitHub Android CI，核实必需状态检查及分支保护。阶段仍为实施中。
