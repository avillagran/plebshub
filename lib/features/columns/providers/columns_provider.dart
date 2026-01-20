import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/column_config.dart';

part 'columns_provider.freezed.dart';

/// SharedPreferences key for persisting column layout.
const String _columnsLayoutKey = 'columns_layout';

/// Default column width in logical pixels.
const double _defaultColumnWidth = 350;

/// Minimum column width in logical pixels.
const double _minColumnWidth = 280;

/// Maximum column width in logical pixels.
const double _maxColumnWidth = 600;

/// State for the multi-column layout.
///
/// Manages the list of columns displayed in the app and whether
/// edit mode is active (for reordering/removing columns).
@freezed
class ColumnsState with _$ColumnsState {
  const factory ColumnsState({
    /// List of column configurations in display order.
    @Default([]) List<ColumnConfig> columns,

    /// Whether edit mode is active (for reordering/removing columns).
    @Default(false) bool isEditMode,
  }) = _ColumnsState;
}

/// Provider for managing multi-column layout state.
///
/// This provider handles:
/// - Adding, removing, and reordering columns
/// - Resizing columns
/// - Persisting layout to SharedPreferences
/// - Loading layout from SharedPreferences
///
/// Example:
/// ```dart
/// // In a widget
/// final columnsState = ref.watch(columnsProvider);
/// final columnsNotifier = ref.read(columnsProvider.notifier);
///
/// // Add a new column
/// columnsNotifier.addColumn(ColumnType.hashtag, hashtag: 'bitcoin');
///
/// // Reorder columns
/// columnsNotifier.reorderColumn(0, 2);
///
/// // Toggle edit mode
/// columnsNotifier.toggleEditMode();
/// ```
final columnsProvider =
    StateNotifierProvider<ColumnsNotifier, ColumnsState>((ref) => ColumnsNotifier());

/// Notifier for managing multi-column layout state.
class ColumnsNotifier extends StateNotifier<ColumnsState> {
  ColumnsNotifier() : super(const ColumnsState()) {
    // Load persisted layout on initialization
    _loadLayout();
  }

  /// Add a new column to the layout.
  ///
  /// Creates a column with the specified [type] and optional parameters.
  /// The column is added to the end of the list.
  ///
  /// Parameters:
  /// - [type]: The type of column to add
  /// - [hashtag]: Hashtag for hashtag columns (without # prefix)
  /// - [userPubkey]: User's public key for user columns
  /// - [channelId]: Channel ID for channel columns
  /// - [title]: Optional custom title for the column
  void addColumn(
    ColumnType type, {
    String? hashtag,
    String? userPubkey,
    String? channelId,
    String? title,
  }) {
    // Generate unique ID based on type and timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final id = '${type.name}-$timestamp';

    // Determine position (last in list)
    final position = state.columns.length;

    final column = ColumnConfig(
      id: id,
      type: type,
      title: title,
      hashtag: hashtag,
      userPubkey: userPubkey,
      channelId: channelId,
      width: _defaultColumnWidth,
      position: position,
    );

    final updatedColumns = [...state.columns, column];
    state = state.copyWith(columns: updatedColumns);

    // Persist changes
    _saveLayout();
  }

  /// Remove a column by its ID.
  ///
  /// Returns true if the column was found and removed, false otherwise.
  bool removeColumn(String columnId) {
    final index = state.columns.indexWhere((c) => c.id == columnId);
    if (index == -1) return false;

    final updatedColumns = [...state.columns];
    updatedColumns.removeAt(index);

    // Update positions for remaining columns
    final repositionedColumns = _updatePositions(updatedColumns);

    state = state.copyWith(columns: repositionedColumns);

    // Persist changes
    _saveLayout();
    return true;
  }

  /// Reorder a column from [oldIndex] to [newIndex].
  ///
  /// This is typically called during drag-and-drop reordering.
  void reorderColumn(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.columns.length) return;
    if (newIndex < 0 || newIndex > state.columns.length) return;
    if (oldIndex == newIndex) return;

    final updatedColumns = [...state.columns];
    final column = updatedColumns.removeAt(oldIndex);

    // Adjust newIndex if removing from before it
    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    updatedColumns.insert(adjustedNewIndex, column);

    // Update positions
    final repositionedColumns = _updatePositions(updatedColumns);

    state = state.copyWith(columns: repositionedColumns);

    // Persist changes
    _saveLayout();
  }

  /// Update the width of a column.
  ///
  /// The width is clamped to [_minColumnWidth] and [_maxColumnWidth].
  void updateColumnWidth(String columnId, double width) {
    final index = state.columns.indexWhere((c) => c.id == columnId);
    if (index == -1) return;

    // Clamp width to valid range
    final clampedWidth = width.clamp(_minColumnWidth, _maxColumnWidth);

    final updatedColumns = [...state.columns];
    updatedColumns[index] = updatedColumns[index].copyWith(width: clampedWidth);

    state = state.copyWith(columns: updatedColumns);

    // Persist changes (debounced in UI typically)
    _saveLayout();
  }

  /// Toggle edit mode for reordering/removing columns.
  void toggleEditMode() {
    state = state.copyWith(isEditMode: !state.isEditMode);
  }

  /// Exit edit mode.
  void exitEditMode() {
    state = state.copyWith(isEditMode: false);
  }

  /// Set the default column layout.
  ///
  /// Creates the default set of columns:
  /// 1. Home (following feed)
  /// 2. Explore (global feed)
  /// 3. Notifications
  ///
  /// This replaces any existing columns.
  void setDefaultColumns() {
    final defaultColumns = [
      const ColumnConfig(
        id: 'home-default',
        type: ColumnType.home,
        width: _defaultColumnWidth,
      ),
      const ColumnConfig(
        id: 'explore-default',
        type: ColumnType.explore,
        width: _defaultColumnWidth,
        position: 1,
      ),
      const ColumnConfig(
        id: 'notifications-default',
        type: ColumnType.notifications,
        width: _defaultColumnWidth,
        position: 2,
      ),
    ];

    state = state.copyWith(columns: defaultColumns);

    // Persist changes
    _saveLayout();
  }

  /// Save the current layout to SharedPreferences.
  Future<void> saveLayout() async {
    await _saveLayout();
  }

  /// Load the layout from SharedPreferences.
  ///
  /// If no layout is found or loading fails, sets default columns.
  Future<void> loadLayout() async {
    await _loadLayout();
  }

  /// Internal method to save layout to SharedPreferences.
  Future<void> _saveLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert columns to JSON
      final columnsJson = state.columns.map((c) => c.toJson()).toList();
      final layoutJson = jsonEncode(columnsJson);

      await prefs.setString(_columnsLayoutKey, layoutJson);
      debugPrint('Saved ${state.columns.length} columns to SharedPreferences');
    } catch (e, stackTrace) {
      debugPrint('Error saving columns layout: $e\n$stackTrace');
    }
  }

  /// Internal method to load layout from SharedPreferences.
  Future<void> _loadLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final layoutJson = prefs.getString(_columnsLayoutKey);

      if (layoutJson == null || layoutJson.isEmpty) {
        // No saved layout, use defaults
        debugPrint('No saved layout found, using defaults');
        setDefaultColumns();
        return;
      }

      final columnsJsonList = jsonDecode(layoutJson) as List<dynamic>;
      final columns = columnsJsonList
          .map((json) => ColumnConfig.fromJson(json as Map<String, dynamic>))
          .toList();

      if (columns.isEmpty) {
        // Empty layout, use defaults
        debugPrint('Empty layout found, using defaults');
        setDefaultColumns();
        return;
      }

      // Sort by position
      columns.sort((a, b) => a.position.compareTo(b.position));

      state = state.copyWith(columns: columns);
      debugPrint('Loaded ${columns.length} columns from SharedPreferences');
    } catch (e, stackTrace) {
      debugPrint('Error loading columns layout: $e\n$stackTrace');
      // Fall back to defaults on error
      setDefaultColumns();
    }
  }

  /// Update column positions to match their index in the list.
  List<ColumnConfig> _updatePositions(List<ColumnConfig> columns) =>
      columns.asMap().entries.map((entry) {
        return entry.value.copyWith(position: entry.key);
      }).toList();

  /// Get a column by its ID.
  ColumnConfig? getColumnById(String columnId) {
    try {
      return state.columns.firstWhere((c) => c.id == columnId);
    } catch (_) {
      return null;
    }
  }

  /// Check if a column with the given type exists.
  ///
  /// For columns that should be unique (home, explore, notifications),
  /// this can be used to prevent duplicates.
  bool hasColumnOfType(ColumnType type) =>
      state.columns.any((c) => c.type == type);

  /// Get the number of columns.
  int get columnCount => state.columns.length;
}

/// Provider for accessing the list of columns directly.
final columnsListProvider = Provider<List<ColumnConfig>>(
  (ref) => ref.watch(columnsProvider).columns,
);

/// Provider for checking if edit mode is active.
final isColumnsEditModeProvider = Provider<bool>(
  (ref) => ref.watch(columnsProvider).isEditMode,
);

/// Provider for getting a specific column by ID.
final columnByIdProvider = Provider.family<ColumnConfig?, String>(
  (ref, columnId) {
    final columns = ref.watch(columnsProvider).columns;
    try {
      return columns.firstWhere((c) => c.id == columnId);
    } catch (_) {
      return null;
    }
  },
);
