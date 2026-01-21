import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'services/cache/cache_service.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize databases before running the app
  // CacheService depends on DatabaseService, so order matters
  await DatabaseService.instance.initialize();
  await CacheService.instance.initialize();

  runApp(
    const ProviderScope(
      child: PlebsHubApp(),
    ),
  );
}
