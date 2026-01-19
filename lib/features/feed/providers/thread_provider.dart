import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndk/ndk.dart';

import '../../../services/ndk_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/thread_service.dart';
import '../models/post.dart';

/// Provider for fetching a thread by event ID.
///
/// Usage:
/// ```dart
/// final threadState = ref.watch(threadProvider(eventId));
/// ```
final threadProvider = StateNotifierProvider.family<ThreadNotifier, ThreadState, String>(
  (ref, eventId) => ThreadNotifier(eventId),
);

/// State for thread fetching.
@immutable
sealed class ThreadState {
  const ThreadState();
}

/// Initial state - no data loaded yet.
class ThreadStateInitial extends ThreadState {
  const ThreadStateInitial();
}

/// Loading state - fetching thread from relays.
class ThreadStateLoading extends ThreadState {
  const ThreadStateLoading();
}

/// Loaded state - thread data available.
class ThreadStateLoaded extends ThreadState {
  const ThreadStateLoaded({
    required this.rootPost,
    required this.replies,
    required this.targetEventId,
    this.parentChain = const [],
    this.flattenedReplies = const [],
  });

  /// The root post of the thread.
  final Post rootPost;

  /// Replies organized as a tree (list of top-level replies, each with children).
  final List<ThreadReplyNode> replies;

  /// The event ID that was originally requested.
  final String targetEventId;

  /// Chain of parent posts between root and target (for context).
  final List<Post> parentChain;

  /// All replies flattened for easy display with indentation levels.
  final List<FlattenedReply> flattenedReplies;
}

/// Error state - something went wrong.
class ThreadStateError extends ThreadState {
  const ThreadStateError({required this.message});

  final String message;
}

/// A node in the reply tree with depth information.
class ThreadReplyNode {
  ThreadReplyNode({
    required this.post,
    required this.depth,
    List<ThreadReplyNode>? children,
  }) : children = children ?? [];

  final Post post;
  final int depth;
  final List<ThreadReplyNode> children;
}

/// A flattened reply with depth for display.
class FlattenedReply {
  const FlattenedReply({
    required this.post,
    required this.depth,
    this.hasMoreReplies = false,
  });

  final Post post;
  final int depth;
  final bool hasMoreReplies;
}

/// Notifier for managing thread state.
class ThreadNotifier extends StateNotifier<ThreadState> {
  ThreadNotifier(this._eventId) : super(const ThreadStateInitial()) {
    loadThread();
  }

  final String _eventId;
  final _threadService = ThreadService.instance;
  final _profileService = ProfileService.instance;
  final _ndkService = NdkService.instance;

  /// Load the thread for the event ID.
  Future<void> loadThread() async {
    state = const ThreadStateLoading();

    try {
      debugPrint('Loading thread for: ${_eventId.substring(0, 8)}...');

      final result = await _threadService.fetchThread(_eventId);

      if (result == null) {
        state = const ThreadStateError(message: 'Thread not found');
        return;
      }

      // Collect all pubkeys for profile fetching
      final pubkeys = <String>{result.root.event.pubKey};
      _collectPubkeys(result.root, pubkeys);
      for (final parent in result.parentChain) {
        pubkeys.add(parent.pubKey);
      }

      // Fetch profiles in batch
      await _profileService.fetchProfiles(pubkeys.toList());

      // Convert root event to Post
      final rootPost = _convertEventToPost(result.root.event);

      // Convert parent chain
      final parentChain = result.parentChain
          .map((e) => _convertEventToPost(e))
          .toList();

      // Convert replies to tree structure
      final replies = _convertReplies(result.root.children, 1);

      // Flatten replies for easy display
      final flattenedReplies = _flattenReplies(replies, maxDepth: 3);

      state = ThreadStateLoaded(
        rootPost: rootPost,
        replies: replies,
        targetEventId: _eventId,
        parentChain: parentChain,
        flattenedReplies: flattenedReplies,
      );

      debugPrint('Thread loaded: ${flattenedReplies.length} replies');
    } catch (e, stackTrace) {
      debugPrint('Error loading thread: $e\n$stackTrace');
      state = ThreadStateError(message: 'Failed to load thread: $e');
    }
  }

  /// Collect all pubkeys from the thread tree.
  void _collectPubkeys(ThreadNode node, Set<String> pubkeys) {
    for (final child in node.children) {
      pubkeys.add(child.event.pubKey);
      _collectPubkeys(child, pubkeys);
    }
  }

  /// Convert replies from ThreadNode to ThreadReplyNode.
  List<ThreadReplyNode> _convertReplies(List<ThreadNode> nodes, int depth) {
    return nodes.map((node) {
      return ThreadReplyNode(
        post: _convertEventToPost(node.event),
        depth: depth,
        children: _convertReplies(node.children, depth + 1),
      );
    }).toList();
  }

  /// Flatten the reply tree for display with max depth.
  List<FlattenedReply> _flattenReplies(
    List<ThreadReplyNode> nodes, {
    int maxDepth = 3,
  }) {
    final result = <FlattenedReply>[];
    _flattenRecursive(nodes, result, maxDepth);
    return result;
  }

  void _flattenRecursive(
    List<ThreadReplyNode> nodes,
    List<FlattenedReply> result,
    int maxDepth,
  ) {
    for (final node in nodes) {
      final displayDepth = node.depth > maxDepth ? maxDepth : node.depth;
      result.add(FlattenedReply(
        post: node.post,
        depth: displayDepth,
        hasMoreReplies: node.children.isNotEmpty,
      ));

      if (node.children.isNotEmpty) {
        _flattenRecursive(node.children, result, maxDepth);
      }
    }
  }

  /// Convert a Nip01Event to a Post model.
  Post _convertEventToPost(Nip01Event event) {
    // Parse NIP-10 tags
    final replyInfo = _threadService.parseNip10Tags(event.tags);

    // Get cached profile
    final profile = _profileService.getCachedProfile(event.pubKey);

    final author = PostAuthor(
      pubkey: event.pubKey,
      displayName: profile?.nameForDisplay ?? _truncatePubkey(event.pubKey),
      nip05: profile?.nip05,
      picture: profile?.picture,
      about: profile?.about,
    );

    return Post(
      id: event.id,
      author: author,
      content: event.content,
      createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      replyToId: replyInfo.replyToId,
      rootEventId: replyInfo.rootId,
    );
  }

  String _truncatePubkey(String pubkey) {
    if (pubkey.length <= 12) return pubkey;
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
  }

  /// Refresh the thread.
  Future<void> refresh() => loadThread();

  /// Publish a reply to the thread.
  Future<bool> publishReply({
    required String content,
    required String privateKey,
    required String replyToId,
    required String replyToAuthorPubkey,
  }) async {
    try {
      // Get the current state to find root info
      final currentState = state;
      if (currentState is! ThreadStateLoaded) {
        return false;
      }

      // Create NIP-10 compliant tags
      final tags = _threadService.createReplyTags(
        rootId: currentState.rootPost.id,
        rootAuthorPubkey: currentState.rootPost.author.pubkey,
        replyToId: replyToId,
        replyToAuthorPubkey: replyToAuthorPubkey,
      );

      // Publish the reply
      final publishedEvent = await _ndkService.publishTextNote(
        content: content,
        privateKey: privateKey,
        tags: tags,
      );

      if (publishedEvent != null) {
        // Refresh thread to show new reply
        await loadThread();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error publishing reply: $e');
      return false;
    }
  }
}
