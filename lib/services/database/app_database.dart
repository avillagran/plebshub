import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Table for storing Nostr events
@DataClassName('NostrEventEntry')
class NostrEvents extends Table {
  /// Event ID (32-byte hex string)
  TextColumn get id => text()();

  /// Public key of the event author
  TextColumn get pubkey => text()();

  /// Unix timestamp when the event was created
  IntColumn get createdAt => integer()();

  /// Event kind (e.g., 0=metadata, 1=text note, 3=contacts, etc.)
  IntColumn get kind => integer()();

  /// Event content
  TextColumn get content => text()();

  /// JSON-encoded tags array
  TextColumn get tags => text()();

  /// Event signature
  TextColumn get sig => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Table for storing cache entries
@DataClassName('CacheEntryRow')
class CacheEntries extends Table {
  /// Cache key (unique identifier)
  TextColumn get key => text()();

  /// Serialized JSON data
  TextColumn get data => text()();

  /// When the entry was cached (Unix milliseconds)
  IntColumn get cachedAt => integer()();

  /// When the entry expires (Unix milliseconds)
  IntColumn get expiresAt => integer()();

  /// Optional type identifier for the cached data
  TextColumn get dataType => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [NostrEvents, CacheEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing with custom executor
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// Opens a cross-platform database connection
  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'plebshub',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  // ===================
  // NostrEvents queries
  // ===================

  /// Insert or replace a Nostr event
  Future<void> upsertNostrEvent(NostrEventEntry event) async {
    await into(nostrEvents).insertOnConflictUpdate(event);
  }

  /// Get a Nostr event by ID
  Future<NostrEventEntry?> getNostrEventById(String eventId) async {
    return (select(nostrEvents)..where((e) => e.id.equals(eventId)))
        .getSingleOrNull();
  }

  /// Get Nostr events by public key
  Future<List<NostrEventEntry>> getNostrEventsByPubkey(String pubkey) async {
    return (select(nostrEvents)
          ..where((e) => e.pubkey.equals(pubkey))
          ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
        .get();
  }

  /// Get Nostr events by kind
  Future<List<NostrEventEntry>> getNostrEventsByKind(int kind) async {
    return (select(nostrEvents)
          ..where((e) => e.kind.equals(kind))
          ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
        .get();
  }

  /// Get Nostr events by kind and pubkey
  Future<List<NostrEventEntry>> getNostrEventsByKindAndPubkey(
    int kind,
    String pubkey,
  ) async {
    return (select(nostrEvents)
          ..where((e) => e.kind.equals(kind) & e.pubkey.equals(pubkey))
          ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
        .get();
  }

  /// Get Nostr events created after a given timestamp
  Future<List<NostrEventEntry>> getNostrEventsAfter(int timestamp) async {
    return (select(nostrEvents)
          ..where((e) => e.createdAt.isBiggerThanValue(timestamp))
          ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
        .get();
  }

  /// Delete a Nostr event by ID
  Future<int> deleteNostrEvent(String eventId) async {
    return (delete(nostrEvents)..where((e) => e.id.equals(eventId))).go();
  }

  /// Delete all Nostr events older than the given timestamp
  Future<int> deleteNostrEventsOlderThan(int timestamp) async {
    return (delete(nostrEvents)
          ..where((e) => e.createdAt.isSmallerThanValue(timestamp)))
        .go();
  }

  // ====================
  // CacheEntries queries
  // ====================

  /// Insert or replace a cache entry
  Future<void> upsertCacheEntry(CacheEntryRow entry) async {
    await into(cacheEntries).insertOnConflictUpdate(entry);
  }

  /// Get a cache entry by key
  Future<CacheEntryRow?> getCacheEntry(String key) async {
    return (select(cacheEntries)..where((e) => e.key.equals(key)))
        .getSingleOrNull();
  }

  /// Get all non-expired cache entries
  Future<List<CacheEntryRow>> getValidCacheEntries() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (select(cacheEntries)
          ..where((e) => e.expiresAt.isBiggerThanValue(now)))
        .get();
  }

  /// Get cache entries by data type
  Future<List<CacheEntryRow>> getCacheEntriesByType(String dataType) async {
    return (select(cacheEntries)..where((e) => e.dataType.equals(dataType)))
        .get();
  }

  /// Delete a cache entry by key
  Future<int> deleteCacheEntry(String key) async {
    return (delete(cacheEntries)..where((e) => e.key.equals(key))).go();
  }

  /// Delete all expired cache entries
  Future<int> deleteExpiredCacheEntries() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (delete(cacheEntries)
          ..where((e) => e.expiresAt.isSmallerThanValue(now)))
        .go();
  }

  /// Delete all cache entries
  Future<int> clearCache() async {
    return delete(cacheEntries).go();
  }

  /// Check if a cache entry exists and is valid
  Future<bool> isCacheValid(String key) async {
    final entry = await getCacheEntry(key);
    if (entry == null) return false;
    return entry.expiresAt > DateTime.now().millisecondsSinceEpoch;
  }

  /// Get cache entries with keys matching a prefix
  Future<List<CacheEntryRow>> getCacheEntriesByPrefix(String prefix) async {
    return (select(cacheEntries)
          ..where((e) => e.key.like('$prefix%')))
        .get();
  }

  /// Delete cache entries with keys matching a prefix
  Future<int> deleteCacheEntriesByPrefix(String prefix) async {
    return (delete(cacheEntries)..where((e) => e.key.like('$prefix%'))).go();
  }

  /// Delete cache entries older than the given timestamp (by cachedAt)
  Future<int> deleteCacheEntriesOlderThan(int timestamp) async {
    return (delete(cacheEntries)
          ..where((e) => e.cachedAt.isSmallerThanValue(timestamp)))
        .go();
  }

  /// Get all cache entries (for statistics)
  Future<List<CacheEntryRow>> getAllCacheEntries() async {
    return select(cacheEntries).get();
  }
}
