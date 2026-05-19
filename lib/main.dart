import 'package:flutter/material.dart';

import 'di/service_locator.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const OrganoteApp());
}
