import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../features/feed/models/nostr_event.dart';

/// Singleton service for managing Isar database instance.
///
/// Provides centralized database access across the application with
/// platform-appropriate directory resolution.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Isar? _isar;

  /// Get the current Isar instance.
  ///
  /// Throws [StateError] if database has not been initialized.
  Isar get isar {
    if (_isar == null) {
      throw StateError(
        'DatabaseService not initialized. Call initialize() first.',
      );
    }
    return _isar!;
  }

  /// Check if database is initialized.
  bool get isInitialized => _isar != null;

  /// Initialize the Isar database.
  ///
  /// Resolves platform-appropriate directory and opens Isar instance
  /// with all registered schemas.
  ///
  /// Safe to call multiple times - will return existing instance if
  /// already initialized.
  Future<void> initialize() async {
    if (_isar != null) {
      return; // Already initialized
    }

    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      [NostrEventSchema],
      directory: dir.path,
      name: 'plebshub',
    );
  }

  /// Close the database and release resources.
  ///
  /// Should be called when the app is shutting down.
  Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }

  /// Dispose of the database instance.
  ///
  /// Alias for [close] to support different cleanup patterns.
  Future<void> dispose() => close();
}
