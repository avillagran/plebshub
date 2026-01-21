import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/notifications_service.dart';
import '../models/notification_item.dart';

/// Provider for the NotificationsNotifier.
///
/// This provider manages the notifications state and provides methods for:
/// - Loading notifications for the current user
/// - Refreshing notifications
/// - Pagination with lazy loading
///
/// Example:
/// ```dart
/// // In a widget
/// final notificationsState = ref.watch(notificationsProvider);
///
/// // Load notifications
/// ref.read(notificationsProvider.notifier).loadNotifications(
///   userPubkey: 'user-pubkey',
/// );
///
/// // Load more notifications (pagination)
/// ref.read(notificationsProvider.notifier).loadMore();
///
/// // Refresh notifications
/// ref.read(notificationsProvider.notifier).refresh();
/// ```
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier();
});

/// Configuration constants for notifications pagination.
class NotificationsConfig {
  /// Initial number of notifications to load.
  static const int initialLoadLimit = 50;

  /// Number of notifications to load per pagination batch.
  static const int paginationBatchSize = 30;

  /// Maximum number of notifications to keep in memory.
  static const int maxNotificationsInMemory = 500;
}

/// State for notifications.
@immutable
sealed class NotificationsState {
  const NotificationsState();
}

/// Initial state - no data loaded yet
class NotificationsStateInitial extends NotificationsState {
  const NotificationsStateInitial();
}

/// Loading state - fetching data from relays
class NotificationsStateLoading extends NotificationsState {
  const NotificationsStateLoading();
}

/// Loaded state - notifications data available
class NotificationsStateLoaded extends NotificationsState {
  const NotificationsStateLoaded({
    required this.notifications,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.oldestTimestamp,
  });

  final List<NotificationItem> notifications;

  /// Whether more notifications are currently being loaded (pagination).
  final bool isLoadingMore;

  /// Whether there are more notifications available to load.
  final bool hasMore;

  /// Timestamp of the oldest notification for pagination cursor.
  final int? oldestTimestamp;

  /// Create a copy with updated fields.
  NotificationsStateLoaded copyWith({
    List<NotificationItem>? notifications,
    bool? isLoadingMore,
    bool? hasMore,
    int? oldestTimestamp,
  }) {
    return NotificationsStateLoaded(
      notifications: notifications ?? this.notifications,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      oldestTimestamp: oldestTimestamp ?? this.oldestTimestamp,
    );
  }
}

/// Error state - something went wrong
class NotificationsStateError extends NotificationsState {
  const NotificationsStateError({required this.message});

  final String message;
}

/// Notifier for managing notifications state.
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier() : super(const NotificationsStateInitial());

  final _notificationsService = NotificationsService.instance;

  /// The current user's public key.
  String? _currentUserPubkey;

  /// Load notifications for a user.
  ///
  /// Fetches the most recent notifications from relays.
  Future<void> loadNotifications({required String userPubkey}) async {
    _currentUserPubkey = userPubkey;
    state = const NotificationsStateLoading();

    try {
      final notifications = await _notificationsService.fetchNotifications(
        userPubkey: userPubkey,
        limit: NotificationsConfig.initialLoadLimit,
      );

      if (notifications.isEmpty) {
        state = const NotificationsStateLoaded(
          notifications: [],
          hasMore: false,
        );
        return;
      }

      // Calculate oldest timestamp for pagination
      final oldestTimestamp = notifications.isNotEmpty
          ? notifications.last.createdAt.millisecondsSinceEpoch ~/ 1000
          : null;

      state = NotificationsStateLoaded(
        notifications: notifications,
        hasMore: notifications.length >= NotificationsConfig.paginationBatchSize,
        oldestTimestamp: oldestTimestamp,
      );
    } catch (e, stackTrace) {
      debugPrint('Error loading notifications: $e\n$stackTrace');
      state = NotificationsStateError(
        message: 'Failed to load notifications: ${e.toString()}',
      );
    }
  }

  /// Load more notifications (pagination).
  ///
  /// Fetches older notifications before [oldestTimestamp] from the current state.
  Future<void> loadMore() async {
    final currentState = state;

    // Only load more if in loaded state and not already loading
    if (currentState is! NotificationsStateLoaded) return;
    if (currentState.isLoadingMore) return;
    if (!currentState.hasMore) return;
    if (_currentUserPubkey == null) return;

    final until = currentState.oldestTimestamp;
    if (until == null) return;

    // Set loading state
    state = currentState.copyWith(isLoadingMore: true);

    try {
      final newNotifications =
          await _notificationsService.fetchMoreNotifications(
        userPubkey: _currentUserPubkey!,
        untilTimestamp: until,
        limit: NotificationsConfig.paginationBatchSize,
      );

      if (newNotifications.isEmpty) {
        state = currentState.copyWith(
          isLoadingMore: false,
          hasMore: false,
        );
        return;
      }

      // Combine with existing notifications
      var combinedNotifications = [
        ...currentState.notifications,
        ...newNotifications,
      ];

      // Enforce memory limit - discard oldest notifications if exceeded
      if (combinedNotifications.length >
          NotificationsConfig.maxNotificationsInMemory) {
        combinedNotifications = combinedNotifications.sublist(
          0,
          NotificationsConfig.maxNotificationsInMemory,
        );
      }

      // Calculate new oldest timestamp
      final newOldestTimestamp = combinedNotifications.isNotEmpty
          ? combinedNotifications.last.createdAt.millisecondsSinceEpoch ~/ 1000
          : null;

      state = NotificationsStateLoaded(
        notifications: combinedNotifications,
        isLoadingMore: false,
        hasMore:
            newNotifications.length >= NotificationsConfig.paginationBatchSize,
        oldestTimestamp: newOldestTimestamp,
      );
    } catch (e) {
      debugPrint('Error loading more notifications: $e');
      // Revert to previous state without loading indicator
      state = currentState.copyWith(isLoadingMore: false);
    }
  }

  /// Refresh notifications.
  ///
  /// Resets to the latest notifications, clearing any pagination state.
  Future<void> refresh() async {
    if (_currentUserPubkey == null) return;
    await loadNotifications(userPubkey: _currentUserPubkey!);
  }

  /// Clear the current user pubkey (call when user logs out).
  void clearCurrentUser() {
    _currentUserPubkey = null;
    state = const NotificationsStateInitial();
  }
}
