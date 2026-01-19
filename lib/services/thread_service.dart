import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart';

import '../core/constants/relay_constants.dart';
import 'ndk_service.dart';

/// A node in a thread tree, representing a post and its replies.
class ThreadNode {
  ThreadNode({
    required this.event,
    List<ThreadNode>? children,
  }) : children = children ?? [];

  /// The Nostr event for this node.
  final Nip01Event event;

  /// Child replies to this post.
  final List<ThreadNode> children;

  /// Add a child reply to this node.
  void addChild(ThreadNode child) {
    children.add(child);
  }

  /// Sort children by timestamp (oldest first for chronological reading).
  void sortChildren() {
    children.sort((a, b) => a.event.createdAt.compareTo(b.event.createdAt));
    for (final child in children) {
      child.sortChildren();
    }
  }
}

/// Parsed NIP-10 reply information from event tags.
class Nip10ReplyInfo {
  const Nip10ReplyInfo({
    this.rootId,
    this.replyToId,
    this.mentionedEventIds = const [],
    this.mentionedPubkeys = const [],
  });

  /// The root event ID of the thread (if present).
  final String? rootId;

  /// The event ID this is a direct reply to (if present).
  final String? replyToId;

  /// Event IDs mentioned in the post (not root or reply).
  final List<String> mentionedEventIds;

  /// Pubkeys mentioned/referenced in the post.
  final List<String> mentionedPubkeys;

  /// Returns true if this event is a reply to something.
  bool get isReply => rootId != null || replyToId != null;

  /// Returns the effective reply-to ID (replyToId if set, otherwise rootId).
  String? get effectiveReplyToId => replyToId ?? rootId;
}

/// Service for fetching and managing thread structures (NIP-10).
///
/// This service provides methods to:
/// - Fetch a complete thread by event ID
/// - Parse NIP-10 reply tags
/// - Build tree structures from flat reply lists
///
/// Example:
/// ```dart
/// final threadService = ThreadService.instance;
///
/// // Fetch a thread
/// final thread = await threadService.fetchThread(eventId);
///
/// // Parse NIP-10 tags from an event
/// final replyInfo = threadService.parseNip10Tags(event.tags);
/// ```
class ThreadService {
  ThreadService._();

  static final ThreadService _instance = ThreadService._();

  /// Singleton instance of ThreadService.
  static ThreadService get instance => _instance;

  final _ndkService = NdkService.instance;

  /// Parse NIP-10 tags from an event to extract reply information.
  ///
  /// NIP-10 defines two formats:
  /// 1. Recommended: ["e", <id>, <relay>, "root"|"reply"|"mention"]
  /// 2. Deprecated positional: first "e" is root, last "e" is reply-to
  ///
  /// Returns [Nip10ReplyInfo] with parsed reply structure.
  Nip10ReplyInfo parseNip10Tags(List<List<String>> tags) {
    String? rootId;
    String? replyToId;
    final mentionedEventIds = <String>[];
    final mentionedPubkeys = <String>[];

    // First pass: look for marked tags (NIP-10 recommended format)
    final eTags = <List<String>>[];

    for (final tag in tags) {
      if (tag.isEmpty) continue;

      if (tag[0] == 'e' && tag.length >= 2) {
        final eventId = tag[1];

        // Check for marker (4th element)
        if (tag.length >= 4) {
          final marker = tag[3].toLowerCase();
          if (marker == 'root') {
            rootId = eventId;
          } else if (marker == 'reply') {
            replyToId = eventId;
          } else if (marker == 'mention') {
            mentionedEventIds.add(eventId);
          }
        } else {
          // No marker - collect for positional parsing
          eTags.add(tag);
        }
      } else if (tag[0] == 'p' && tag.length >= 2) {
        mentionedPubkeys.add(tag[1]);
      }
    }

    // If we didn't find marked tags, use positional parsing (deprecated format)
    if (rootId == null && replyToId == null && eTags.isNotEmpty) {
      if (eTags.length == 1) {
        // Single e tag: it's both root and reply-to
        rootId = eTags.first[1];
        replyToId = eTags.first[1];
      } else {
        // Multiple e tags: first is root, last is reply-to
        rootId = eTags.first[1];
        replyToId = eTags.last[1];

        // Middle ones are mentions
        for (var i = 1; i < eTags.length - 1; i++) {
          mentionedEventIds.add(eTags[i][1]);
        }
      }
    }

    return Nip10ReplyInfo(
      rootId: rootId,
      replyToId: replyToId,
      mentionedEventIds: mentionedEventIds,
      mentionedPubkeys: mentionedPubkeys,
    );
  }

  /// Fetch a complete thread by event ID.
  ///
  /// Returns a [ThreadNode] containing the root event and all replies
  /// organized in a tree structure.
  ///
  /// The method:
  /// 1. Fetches the target event
  /// 2. If it's a reply, fetches the root and parent chain
  /// 3. Fetches all replies to the root
  /// 4. Builds a tree structure
  Future<ThreadResult?> fetchThread(String eventId) async {
    try {
      debugPrint('Fetching thread for event: ${eventId.substring(0, 8)}...');

      // Step 1: Fetch the target event
      final targetEvent = await _fetchEvent(eventId);
      if (targetEvent == null) {
        debugPrint('Target event not found');
        return null;
      }

      // Step 2: Parse NIP-10 tags to find root
      final replyInfo = parseNip10Tags(targetEvent.tags);
      final rootId = replyInfo.rootId ?? eventId;

      // Step 3: Fetch the root event (if different from target)
      Nip01Event? rootEvent;
      if (rootId == eventId) {
        rootEvent = targetEvent;
      } else {
        rootEvent = await _fetchEvent(rootId);
        rootEvent ??= targetEvent; // Fallback if root not found
      }

      // Step 4: Fetch the parent chain (events between root and target)
      final parentChain = <Nip01Event>[];
      if (replyInfo.replyToId != null &&
          replyInfo.replyToId != rootId &&
          replyInfo.replyToId != eventId) {
        final parent = await _fetchEvent(replyInfo.replyToId!);
        if (parent != null) {
          parentChain.add(parent);
        }
      }

      // Step 5: Fetch all replies to the root event
      final replies = await _fetchReplies(rootId);
      debugPrint('Fetched ${replies.length} replies');

      // Step 6: Build tree structure
      final rootNode = _buildTree(rootEvent, replies);

      return ThreadResult(
        root: rootNode,
        targetEventId: eventId,
        parentChain: parentChain,
        totalReplies: replies.length,
      );
    } catch (e, stackTrace) {
      debugPrint('Error fetching thread: $e\n$stackTrace');
      return null;
    }
  }

  /// Fetch a single event by ID.
  Future<Nip01Event?> _fetchEvent(String eventId) async {
    try {
      final filter = Filter(
        ids: [eventId],
        limit: 1,
      );

      final events = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 5),
      );

      return events.isNotEmpty ? events.first : null;
    } catch (e) {
      debugPrint('Error fetching event $eventId: $e');
      return null;
    }
  }

  /// Fetch all replies to an event (events with "e" tag referencing the eventId).
  Future<List<Nip01Event>> _fetchReplies(String eventId) async {
    try {
      final filter = Filter(
        kinds: [1],
        eTags: [eventId],
        limit: 500, // Reasonable limit for replies
      );

      final events = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 10),
      );

      return events;
    } catch (e) {
      debugPrint('Error fetching replies: $e');
      return [];
    }
  }

  /// Build a tree structure from a root event and flat list of replies.
  ThreadNode _buildTree(Nip01Event rootEvent, List<Nip01Event> replies) {
    final rootNode = ThreadNode(event: rootEvent);

    // Create a map of event ID to node for quick lookup
    final nodeMap = <String, ThreadNode>{
      rootEvent.id: rootNode,
    };

    // Create nodes for all replies
    for (final reply in replies) {
      nodeMap[reply.id] = ThreadNode(event: reply);
    }

    // Build tree by connecting children to parents
    for (final reply in replies) {
      final replyInfo = parseNip10Tags(reply.tags);
      final parentId = replyInfo.effectiveReplyToId;

      if (parentId != null && nodeMap.containsKey(parentId)) {
        nodeMap[parentId]!.addChild(nodeMap[reply.id]!);
      } else {
        // No parent found, attach directly to root
        rootNode.addChild(nodeMap[reply.id]!);
      }
    }

    // Sort all children by timestamp
    rootNode.sortChildren();

    return rootNode;
  }

  /// Fetch reply count for an event.
  ///
  /// Returns the number of direct and indirect replies.
  Future<int> fetchReplyCount(String eventId) async {
    try {
      final filter = Filter(
        kinds: [1],
        eTags: [eventId],
        limit: 1000,
      );

      final events = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 5),
      );

      return events.length;
    } catch (e) {
      debugPrint('Error fetching reply count: $e');
      return 0;
    }
  }

  /// Create NIP-10 compliant tags for a reply.
  ///
  /// Returns the tags to include when publishing a reply.
  List<List<String>> createReplyTags({
    required String rootId,
    required String rootAuthorPubkey,
    String? replyToId,
    String? replyToAuthorPubkey,
    String? preferredRelay,
  }) {
    final relay = preferredRelay ?? kDefaultRelays.first;
    final tags = <List<String>>[];

    // Root tag (always present for threaded replies)
    tags.add(['e', rootId, relay, 'root']);

    // Reply tag (if replying to a specific post, not the root)
    if (replyToId != null && replyToId != rootId) {
      tags.add(['e', replyToId, relay, 'reply']);
    }

    // Author p tags
    tags.add(['p', rootAuthorPubkey]);
    if (replyToAuthorPubkey != null && replyToAuthorPubkey != rootAuthorPubkey) {
      tags.add(['p', replyToAuthorPubkey]);
    }

    return tags;
  }
}

/// Result of fetching a thread.
class ThreadResult {
  const ThreadResult({
    required this.root,
    required this.targetEventId,
    this.parentChain = const [],
    this.totalReplies = 0,
  });

  /// The root of the thread tree.
  final ThreadNode root;

  /// The event ID that was originally requested.
  final String targetEventId;

  /// Chain of parent events between root and target (for context).
  final List<Nip01Event> parentChain;

  /// Total number of replies in the thread.
  final int totalReplies;
}
