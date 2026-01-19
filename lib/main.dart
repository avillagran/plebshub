import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Isar database before running the app
  await DatabaseService.instance.initialize();

  runApp(
    const ProviderScope(
      child: PlebsHubApp(),
    ),
  );
}
