import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for close event handling
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);

  await core.initialize();
  runApp(const MarchaApp());
}
