import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/reply_count_service.dart';

/// State for reply counts.
@immutable
class ReplyCountState {
  const ReplyCountState({
    this.countsByEvent = const {},
    this.isLoading = false,
    this.error,
  });

  /// Map of event ID to reply count.
  final Map<String, int> countsByEvent;

  /// Whether reply counts are currently being fetched.
  final bool isLoading;

  /// Error message if something went wrong.
  final String? error;

  ReplyCountState copyWith({
    Map<String, int>? countsByEvent,
    bool? isLoading,
    String? error,
  }) {
    return ReplyCountState(
      countsByEvent: countsByEvent ?? this.countsByEvent,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Get reply count for an event.
  int getReplyCount(String eventId) {
    return countsByEvent[eventId] ?? 0;
  }
}

/// Provider for the ReplyCountNotifier.
///
/// Manages reply count state including:
/// - Fetching reply counts for posts in batch
/// - Caching counts by event ID
///
/// Example:
/// ```dart
/// // In a widget
/// final replyCountState = ref.watch(replyCountProvider);
/// final count = replyCountState.getReplyCount(post.id);
///
/// // Fetch counts for a batch of posts
/// ref.read(replyCountProvider.notifier).fetchReplyCounts(
///   eventIds: posts.map((p) => p.id).toList(),
/// );
/// ```
final replyCountProvider =
    StateNotifierProvider<ReplyCountNotifier, ReplyCountState>((ref) {
  return ReplyCountNotifier();
});

/// Notifier for managing reply count state.
class ReplyCountNotifier extends StateNotifier<ReplyCountState> {
  ReplyCountNotifier() : super(const ReplyCountState());

  final _replyCountService = ReplyCountService.instance;

  /// Fetch reply counts for a list of event IDs.
  ///
  /// Updates state with reply counts. Merges with existing counts.
  Future<void> fetchReplyCounts(List<String> eventIds) async {
    if (eventIds.isEmpty) return;

    // Filter out already-fetched event IDs to avoid redundant queries
    final unfetchedIds = eventIds
        .where((id) => !state.countsByEvent.containsKey(id))
        .toList();

    if (unfetchedIds.isEmpty) {
      // debugPrint('All ${eventIds.length} reply counts already cached');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final counts = await _replyCountService.fetchReplyCounts(
        eventIds: unfetchedIds,
      );

      // Merge with existing counts
      final mergedCounts = Map<String, int>.from(state.countsByEvent);
      mergedCounts.addAll(counts);

      state = state.copyWith(
        countsByEvent: mergedCounts,
        isLoading: false,
      );

      // debugPrint('Reply counts fetched for ${unfetchedIds.length} events');
    } catch (e) {
      // debugPrint('Error fetching reply counts: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch reply counts: $e',
      );
    }
  }

  /// Clear all reply count state.
  void clear() {
    state = const ReplyCountState();
  }

  /// Clear error state.
  void clearError() {
    state = state.copyWith(error: null);
  }
}
