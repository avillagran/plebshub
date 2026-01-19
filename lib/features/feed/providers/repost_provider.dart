import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndk/ndk.dart';

import '../../../services/repost_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';

/// State for reposts.
@immutable
class RepostState {
  const RepostState({
    this.repostsByEvent = const {},
    this.userRepostedEvents = const {},
    this.isLoading = false,
    this.pendingReposts = const {},
    this.error,
  });

  /// Map of event ID to list of repost events
  final Map<String, List<Nip01Event>> repostsByEvent;

  /// Set of event IDs that the current user has reposted
  final Set<String> userRepostedEvents;

  /// Whether reposts are currently being fetched
  final bool isLoading;

  /// Set of event IDs with pending repost operations (optimistic UI)
  final Set<String> pendingReposts;

  /// Error message if something went wrong
  final String? error;

  RepostState copyWith({
    Map<String, List<Nip01Event>>? repostsByEvent,
    Set<String>? userRepostedEvents,
    bool? isLoading,
    Set<String>? pendingReposts,
    String? error,
  }) {
    return RepostState(
      repostsByEvent: repostsByEvent ?? this.repostsByEvent,
      userRepostedEvents: userRepostedEvents ?? this.userRepostedEvents,
      isLoading: isLoading ?? this.isLoading,
      pendingReposts: pendingReposts ?? this.pendingReposts,
      error: error,
    );
  }

  /// Get repost count for an event
  int getRepostCount(String eventId) {
    return repostsByEvent[eventId]?.length ?? 0;
  }

  /// Check if user has reposted an event (includes pending for optimistic UI)
  bool hasUserReposted(String eventId) {
    return userRepostedEvents.contains(eventId) ||
        pendingReposts.contains(eventId);
  }
}

/// Provider for the RepostNotifier.
///
/// Manages repost state including:
/// - Fetching reposts for posts
/// - Tracking which posts the current user has reposted
/// - Publishing new reposts with optimistic UI updates
///
/// Example:
/// ```dart
/// // In a widget
/// final repostState = ref.watch(repostProvider);
/// final count = repostState.getRepostCount(post.id);
/// final hasReposted = repostState.hasUserReposted(post.id);
///
/// // Toggle repost
/// ref.read(repostProvider.notifier).toggleRepost(
///   originalEvent: originalNostrEvent,
/// );
/// ```
final repostProvider =
    StateNotifierProvider<RepostNotifier, RepostState>((ref) {
  return RepostNotifier(ref);
});

/// Notifier for managing repost state.
class RepostNotifier extends StateNotifier<RepostState> {
  RepostNotifier(this.ref) : super(const RepostState());

  final Ref ref;
  final _repostService = RepostService.instance;

  /// Fetch reposts for a list of event IDs.
  ///
  /// Updates state with repost counts and tracks which events
  /// the current user has reposted.
  Future<void> fetchReposts(List<String> eventIds) async {
    if (eventIds.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final reposts = await _repostService.fetchReposts(
        eventIds: eventIds,
      );

      // Merge with existing reposts
      final mergedReposts = Map<String, List<Nip01Event>>.from(
        state.repostsByEvent,
      );
      mergedReposts.addAll(reposts);

      // Track which events the current user has reposted
      final userReposted = Set<String>.from(state.userRepostedEvents);
      final currentPubkey = _getCurrentUserPubkey();

      if (currentPubkey != null) {
        for (final entry in reposts.entries) {
          final eventId = entry.key;
          final eventReposts = entry.value;

          // Check if user has reposted this event
          final hasReposted = eventReposts.any(
            (r) => r.pubKey == currentPubkey,
          );

          if (hasReposted) {
            userReposted.add(eventId);
          }
        }
      }

      state = state.copyWith(
        repostsByEvent: mergedReposts,
        userRepostedEvents: userReposted,
        isLoading: false,
      );

      debugPrint('Reposts fetched for ${eventIds.length} events');
    } catch (e) {
      debugPrint('Error fetching reposts: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch reposts: $e',
      );
    }
  }

  /// Toggle repost for an event.
  ///
  /// Uses optimistic UI: immediately shows the repost, reverts on error.
  /// Note: Nostr doesn't have "un-repost" - we just don't publish a new repost.
  ///
  /// Parameters:
  /// - [eventId]: The ID of the event to repost
  /// - [authorPubkey]: The public key of the original event author
  Future<void> toggleRepost({
    required String eventId,
    required String authorPubkey,
  }) async {
    // Get user's private key
    final privateKey = _getCurrentUserPrivateKey();
    if (privateKey == null) {
      debugPrint('Cannot repost: user not authenticated');
      return;
    }

    // Check if already reposted
    if (state.userRepostedEvents.contains(eventId)) {
      // Already reposted - Nostr doesn't support un-repost, so just return
      debugPrint('Already reposted event: $eventId');
      return;
    }

    // Optimistic UI: add to pending reposts
    state = state.copyWith(
      pendingReposts: {...state.pendingReposts, eventId},
    );

    try {
      // Publish the repost using simple repost (doesn't need full event)
      final repost = await _repostService.publishSimpleRepost(
        eventId: eventId,
        authorPubkey: authorPubkey,
        privateKey: privateKey,
      );

      if (repost != null) {
        // Success: move from pending to confirmed
        final newUserReposted = {...state.userRepostedEvents, eventId};
        final newPending = Set<String>.from(state.pendingReposts)
          ..remove(eventId);

        // Add repost to local cache
        final newReposts = Map<String, List<Nip01Event>>.from(
          state.repostsByEvent,
        );
        newReposts.putIfAbsent(eventId, () => []);
        newReposts[eventId]!.add(repost);

        state = state.copyWith(
          userRepostedEvents: newUserReposted,
          pendingReposts: newPending,
          repostsByEvent: newReposts,
        );

        debugPrint('Repost published for event: $eventId');
      } else {
        // Failed: remove from pending
        _revertPendingRepost(eventId);
      }
    } catch (e) {
      debugPrint('Error publishing repost: $e');
      _revertPendingRepost(eventId);
    }
  }

  /// Revert a pending repost on error.
  void _revertPendingRepost(String eventId) {
    final newPending = Set<String>.from(state.pendingReposts)..remove(eventId);
    state = state.copyWith(
      pendingReposts: newPending,
      error: 'Failed to publish repost',
    );
  }

  /// Get the current user's public key.
  String? _getCurrentUserPubkey() {
    final authState = ref.read(authProvider);
    if (authState is AuthStateAuthenticated) {
      return authState.keypair.publicKey;
    }
    return null;
  }

  /// Get the current user's private key.
  String? _getCurrentUserPrivateKey() {
    final authState = ref.read(authProvider);
    if (authState is AuthStateAuthenticated) {
      return authState.keypair.privateKey;
    }
    return null;
  }

  /// Clear all repost state.
  void clear() {
    state = const RepostState();
  }

  /// Clear error state.
  void clearError() {
    state = state.copyWith(error: null);
  }
}
