import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndk/ndk.dart';

import '../../../services/reaction_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';

/// State for reactions.
@immutable
class ReactionState {
  const ReactionState({
    this.reactionsByEvent = const {},
    this.userLikedEvents = const {},
    this.isLoading = false,
    this.pendingLikes = const {},
    this.error,
  });

  /// Map of event ID to list of reaction events
  final Map<String, List<Nip01Event>> reactionsByEvent;

  /// Set of event IDs that the current user has liked
  final Set<String> userLikedEvents;

  /// Whether reactions are currently being fetched
  final bool isLoading;

  /// Set of event IDs with pending like operations (optimistic UI)
  final Set<String> pendingLikes;

  /// Error message if something went wrong
  final String? error;

  ReactionState copyWith({
    Map<String, List<Nip01Event>>? reactionsByEvent,
    Set<String>? userLikedEvents,
    bool? isLoading,
    Set<String>? pendingLikes,
    String? error,
  }) {
    return ReactionState(
      reactionsByEvent: reactionsByEvent ?? this.reactionsByEvent,
      userLikedEvents: userLikedEvents ?? this.userLikedEvents,
      isLoading: isLoading ?? this.isLoading,
      pendingLikes: pendingLikes ?? this.pendingLikes,
      error: error,
    );
  }

  /// Get reaction count for an event
  int getReactionCount(String eventId) {
    return reactionsByEvent[eventId]?.length ?? 0;
  }

  /// Check if user has liked an event (includes pending likes for optimistic UI)
  bool hasUserLiked(String eventId) {
    return userLikedEvents.contains(eventId) || pendingLikes.contains(eventId);
  }
}

/// Provider for the ReactionNotifier.
///
/// Manages reaction state including:
/// - Fetching reactions for posts
/// - Tracking which posts the current user has liked
/// - Publishing new reactions with optimistic UI updates
///
/// Example:
/// ```dart
/// // In a widget
/// final reactionState = ref.watch(reactionProvider);
/// final count = reactionState.getReactionCount(post.id);
/// final hasLiked = reactionState.hasUserLiked(post.id);
///
/// // Toggle like
/// ref.read(reactionProvider.notifier).toggleLike(
///   eventId: post.id,
///   authorPubkey: post.author.pubkey,
/// );
/// ```
final reactionProvider =
    StateNotifierProvider<ReactionNotifier, ReactionState>((ref) {
  return ReactionNotifier(ref);
});

/// Notifier for managing reaction state.
class ReactionNotifier extends StateNotifier<ReactionState> {
  ReactionNotifier(this.ref) : super(const ReactionState());

  final Ref ref;
  final _reactionService = ReactionService.instance;

  /// Fetch reactions for a list of event IDs.
  ///
  /// Updates state with reaction counts and tracks which events
  /// the current user has liked.
  Future<void> fetchReactions(List<String> eventIds) async {
    if (eventIds.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final reactions = await _reactionService.fetchReactions(
        eventIds: eventIds,
      );

      // Merge with existing reactions
      final mergedReactions = Map<String, List<Nip01Event>>.from(
        state.reactionsByEvent,
      );
      mergedReactions.addAll(reactions);

      // Track which events the current user has liked
      final userLiked = Set<String>.from(state.userLikedEvents);
      final currentPubkey = _getCurrentUserPubkey();

      if (currentPubkey != null) {
        for (final entry in reactions.entries) {
          final eventId = entry.key;
          final eventReactions = entry.value;

          // Check if user has a reaction to this event
          final hasLiked = eventReactions.any(
            (r) => r.pubKey == currentPubkey && r.content == '+',
          );

          if (hasLiked) {
            userLiked.add(eventId);
          }
        }
      }

      state = state.copyWith(
        reactionsByEvent: mergedReactions,
        userLikedEvents: userLiked,
        isLoading: false,
      );

      debugPrint('Reactions fetched for ${eventIds.length} events');
    } catch (e) {
      debugPrint('Error fetching reactions: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch reactions: $e',
      );
    }
  }

  /// Toggle like for an event.
  ///
  /// Uses optimistic UI: immediately shows the like, reverts on error.
  /// Note: Nostr doesn't have "unlike" - we just don't publish a new reaction.
  Future<void> toggleLike({
    required String eventId,
    required String authorPubkey,
  }) async {
    // Get user's private key
    final privateKey = _getCurrentUserPrivateKey();
    if (privateKey == null) {
      debugPrint('Cannot like: user not authenticated');
      return;
    }

    // Check if already liked
    if (state.userLikedEvents.contains(eventId)) {
      // Already liked - Nostr doesn't support unlike, so just return
      debugPrint('Already liked event: $eventId');
      return;
    }

    // Optimistic UI: add to pending likes
    state = state.copyWith(
      pendingLikes: {...state.pendingLikes, eventId},
    );

    try {
      // Publish the reaction
      final reaction = await _reactionService.publishReaction(
        eventId: eventId,
        authorPubkey: authorPubkey,
        privateKey: privateKey,
      );

      if (reaction != null) {
        // Success: move from pending to confirmed
        final newUserLiked = {...state.userLikedEvents, eventId};
        final newPending = Set<String>.from(state.pendingLikes)
          ..remove(eventId);

        // Add reaction to local cache
        final newReactions = Map<String, List<Nip01Event>>.from(
          state.reactionsByEvent,
        );
        newReactions.putIfAbsent(eventId, () => []);
        newReactions[eventId]!.add(reaction);

        state = state.copyWith(
          userLikedEvents: newUserLiked,
          pendingLikes: newPending,
          reactionsByEvent: newReactions,
        );

        debugPrint('Like published for event: $eventId');
      } else {
        // Failed: remove from pending
        _revertPendingLike(eventId);
      }
    } catch (e) {
      debugPrint('Error publishing like: $e');
      _revertPendingLike(eventId);
    }
  }

  /// Revert a pending like on error.
  void _revertPendingLike(String eventId) {
    final newPending = Set<String>.from(state.pendingLikes)..remove(eventId);
    state = state.copyWith(
      pendingLikes: newPending,
      error: 'Failed to publish like',
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

  /// Clear all reaction state.
  void clear() {
    state = const ReactionState();
  }

  /// Clear error state.
  void clearError() {
    state = state.copyWith(error: null);
  }
}
