import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/config/app_config.dart';

void main() {
  // Fail fast for invalid build configuration; Phase 2 adds a recovery UI.
  AppConfig.fromEnvironment();
  runApp(const TemplateApp());
}
