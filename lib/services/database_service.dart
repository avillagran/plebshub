import 'package:plebshub/services/database/app_database.dart';

/// Singleton service for managing Drift database instance.
///
/// Provides centralized database access across the application.
/// The underlying AppDatabase handles platform-appropriate initialization.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  AppDatabase? _db;
  bool _isInitialized = false;

  /// Get the current database instance.
  ///
  /// Throws [StateError] if database has not been initialized.
  AppDatabase get db {
    if (_db == null) {
      throw StateError(
        'DatabaseService not initialized. Call initialize() first.',
      );
    }
    return _db!;
  }

  /// Check if database is initialized.
  bool get isInitialized => _isInitialized;

  /// Initialize the Drift database.
  ///
  /// Creates the AppDatabase instance which handles platform-appropriate
  /// initialization internally.
  ///
  /// Safe to call multiple times - will return existing instance if
  /// already initialized.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _db = AppDatabase();
    _isInitialized = true;
  }

  /// Close the database and release resources.
  ///
  /// Should be called when the app is shutting down.
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _isInitialized = false;
  }

  /// Dispose of the database instance.
  ///
  /// Alias for [close] to support different cleanup patterns.
  Future<void> dispose() => close();
}
