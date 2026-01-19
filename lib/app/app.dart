import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import 'router.dart';
import '../core/constants/app_constants.dart';

/// The root widget of the PlebsHub application.
class PlebsHubApp extends ConsumerWidget {
  const PlebsHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

/// Provider for the current theme mode.
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  // Default to dark mode
  return ThemeMode.dark;
});
