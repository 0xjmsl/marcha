import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'core/core.dart';
import 'theme/app_theme.dart';
import 'widgets/app_sidebar.dart';
import 'widgets/exit_confirmation_dialog.dart';
import 'screens/process_manager_screen.dart';
import 'screens/resources_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/api_screen.dart';

enum AppView { processManager, resources, api, settings }

class MarchaApp extends StatefulWidget {
  const MarchaApp({super.key});

  @override
  State<MarchaApp> createState() => _MarchaAppState();
}

class _MarchaAppState extends State<MarchaApp> with WindowListener {
  AppView _currentView = AppView.processManager;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  static const _sidebarItems = [
    SidebarItem(id: 'process', title: 'Process Manager', icon: Icons.terminal),
    SidebarItem(id: 'resources', title: 'Resources', icon: Icons.monitor_heart),
    SidebarItem(id: 'api', title: 'API', icon: Icons.api),
    SidebarItem(id: 'settings', title: 'Settings', icon: Icons.settings),
  ];

  @override
  void initState() {
    super.initState();
    // Listen to core changes (including theme changes)
    core.addListener(_onCoreChanged);
    // Listen to window close events
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    core.removeListener(_onCoreChanged);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) {
      // No context available, just close
      await windowManager.destroy();
      return;
    }

    final shouldExit = await ExitConfirmationDialog.show(navigatorContext);
    if (shouldExit) {
      // Stop API server before exiting
      await core.api.stop();
      // Kill all running tasks before exiting
      for (final task in core.tasks.running) {
        task.kill();
      }
      await windowManager.destroy();
    }
  }

  void _onCoreChanged() {
    // Rebuild when settings change (including theme)
    if (mounted) {
      setState(() {});
    }
  }

  void _onNavigate(String id) {
    setState(() {
      switch (id) {
        case 'process':
          _currentView = AppView.processManager;
          break;
        case 'resources':
          _currentView = AppView.resources;
          break;
        case 'api':
          _currentView = AppView.api;
          break;
        case 'settings':
          _currentView = AppView.settings;
          break;
      }
    });
  }

  String get _selectedId {
    switch (_currentView) {
      case AppView.processManager:
        return 'process';
      case AppView.resources:
        return 'resources';
      case AppView.api:
        return 'api';
      case AppView.settings:
        return 'settings';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = core.settings.current.isDarkMode;

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Marcha',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: Row(
          children: [
            AppSidebar(
              items: _sidebarItems,
              selectedId: _selectedId,
              onItemSelected: _onNavigate,
            ),
            Expanded(
              child: _buildCurrentView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case AppView.processManager:
        return const ProcessManagerScreen();
      case AppView.resources:
        return const ResourcesScreen();
      case AppView.api:
        return const ApiScreen();
      case AppView.settings:
        return const SettingsScreen();
    }
  }
}
