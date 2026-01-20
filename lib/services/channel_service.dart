import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';

import '../core/constants/cache_config.dart';
import '../core/constants/relay_constants.dart';
import '../features/channels/models/channel.dart';
import '../features/channels/models/channel_message.dart';
import 'cache/cache_service.dart';
import 'ndk_service.dart';

/// Service for managing Nostr public chat channels (NIP-28).
///
/// Provides functionality for:
/// - Creating channels (kind:40)
/// - Fetching channels from relays with caching
/// - Sending messages to channels (kind:42)
/// - Subscribing to real-time channel messages
/// - Stale-while-revalidate pattern for instant loading
///
/// NIP-28 Event Kinds:
/// - kind:40 = channel creation
/// - kind:41 = channel metadata update
/// - kind:42 = channel message
/// - kind:43 = hide message (moderation)
/// - kind:44 = mute user (moderation)
///
/// Example:
/// ```dart
/// final service = ChannelService.instance;
///
/// // Fetch channels (returns cached immediately, refreshes in background)
/// final channels = await service.fetchChannels();
///
/// // Create a channel
/// final channel = await service.createChannel(
///   name: 'my-channel',
///   about: 'A discussion channel',
///   privateKey: userPrivateKey,
/// );
///
/// // Send a message
/// await service.sendMessage(
///   channelId: channel.id,
///   content: 'Hello everyone!',
///   privateKey: userPrivateKey,
/// );
/// ```
class ChannelService {
  ChannelService._();

  static final ChannelService _instance = ChannelService._();

  /// Singleton instance of ChannelService.
  static ChannelService get instance => _instance;

  final _ndkService = NdkService.instance;
  final _cacheService = CacheService.instance;

  /// Active subscriptions for channel messages.
  final Map<String, StreamSubscription<Nip01Event>> _subscriptions = {};

  /// Stream controllers for channel messages.
  final Map<String, StreamController<ChannelMessage>> _messageControllers = {};

  /// In-memory cache for channels.
  final Map<String, Channel> _channelCache = {};

  /// NIP-28 event kinds.
  static const int kindChannelCreation = 40;
  static const int kindChannelMetadata = 41;
  static const int kindChannelMessage = 42;
  static const int kindHideMessage = 43;
  static const int kindMuteUser = 44;

  /// Get cache key for a channel.
  String _channelCacheKey(String channelId) =>
      '${CacheConfig.channelKeyPrefix}$channelId';

  /// Get a cached channel by ID, or null if not cached.
  Channel? getCachedChannel(String channelId) {
    return _channelCache[channelId];
  }

  /// Fetch channels from relays with stale-while-revalidate pattern.
  ///
  /// Discovers public chat channels by querying for kind:40 events.
  /// Returns cached channels immediately if available, then refreshes
  /// in background if stale.
  ///
  /// [limit] - Maximum number of channels to fetch.
  /// [since] - Only fetch channels created after this timestamp.
  /// [forceRefresh] - Bypass cache and fetch fresh data.
  Future<List<Channel>> fetchChannels({
    int limit = 50,
    int? since,
    bool forceRefresh = false,
  }) async {
    // Try cache first (unless force refresh)
    if (!forceRefresh && _cacheService.isInitialized) {
      final cached = await _loadChannelListFromCache();
      if (cached != null && cached.isNotEmpty) {
        // Start background refresh if stale
        _refreshChannelListInBackground(limit: limit, since: since);
        return cached;
      }
    }

    return _fetchChannelsFromNetwork(limit: limit, since: since);
  }

  /// Load channel list from cache.
  Future<List<Channel>?> _loadChannelListFromCache() async {
    try {
      final cached = await _cacheService.get<List<dynamic>>(
        CacheConfig.channelListKey,
        allowStale: true,
      );
      if (cached != null) {
        // debugPrint('Loaded ${cached.length} channels from cache');
        final channels = cached.map((json) {
          final map = json as Map<String, dynamic>;
          return Channel(
            id: map['id'] as String,
            name: map['name'] as String,
            about: map['about'] as String?,
            picture: map['picture'] as String?,
            creatorPubkey: map['creatorPubkey'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              (map['createdAt'] as int) * 1000,
            ),
            relayUrl: map['relayUrl'] as String?,
          );
        }).toList();

        // Update in-memory cache
        for (final channel in channels) {
          _channelCache[channel.id] = channel;
        }

        return channels;
      }
    } catch (e) {
      // debugPrint('Error loading channels from cache: $e');
    }
    return null;
  }

  /// Refresh channel list in background if stale.
  Future<void> _refreshChannelListInBackground({
    required int limit,
    int? since,
  }) async {
    if (!_cacheService.isInitialized) return;

    final isStale = await _cacheService.isStale(CacheConfig.channelListKey);
    if (isStale) {
      // debugPrint('Channel list stale, refreshing in background...');
      unawaited(_fetchChannelsFromNetwork(limit: limit, since: since).catchError((Object e) {
        // debugPrint('Background channel refresh failed: $e');
        return <Channel>[]; // Return empty list to satisfy type
      }));
    }
  }

  /// Fetch channels from network and cache.
  Future<List<Channel>> _fetchChannelsFromNetwork({
    required int limit,
    int? since,
  }) async {
    try {
      // debugPrint('Fetching channels (limit: $limit)...');

      // Ensure relays are connected
      await _ndkService.connectToRelays();

      // Query for kind:40 (channel creation) events
      final filter = Filter(
        kinds: [kindChannelCreation],
        limit: limit,
        since: since,
      );

      final events = await _ndkService.fetchEvents(filter: filter);

      if (events.isEmpty) {
        // debugPrint('No channels found');
        return [];
      }

      // Convert events to Channel models
      final channels = events.map((event) {
        return Channel.fromEvent(
          eventId: event.id,
          content: event.content,
          pubkey: event.pubKey,
          createdAt: event.createdAt,
        );
      }).toList();

      // Sort by creation date (newest first)
      channels.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Update caches
      for (final channel in channels) {
        _channelCache[channel.id] = channel;
      }

      // Cache to persistent storage
      await _cacheChannelList(channels);

      // debugPrint('Fetched ${channels.length} channels');
      return channels;
    } catch (e, stackTrace) {
      // debugPrint('Error fetching channels: $e\n$stackTrace');
      return [];
    }
  }

  /// Cache channel list to persistent storage.
  Future<void> _cacheChannelList(List<Channel> channels) async {
    if (!_cacheService.isInitialized) return;

    try {
      final jsonList = channels.map((channel) => {
        'id': channel.id,
        'name': channel.name,
        'about': channel.about,
        'picture': channel.picture,
        'creatorPubkey': channel.creatorPubkey,
        'createdAt': channel.createdAt.millisecondsSinceEpoch ~/ 1000,
        'relayUrl': channel.relayUrl,
      }).toList();

      await _cacheService.set(
        CacheConfig.channelListKey,
        jsonList,
        CacheConfig.channelsTtl,
      );

      // debugPrint('Cached ${channels.length} channels');
    } catch (e) {
      // debugPrint('Error caching channels: $e');
    }
  }

  /// Fetch a single channel by ID with caching.
  Future<Channel?> fetchChannel(String channelId, {bool forceRefresh = false}) async {
    // Check in-memory cache
    if (!forceRefresh && _channelCache.containsKey(channelId)) {
      _refreshChannelInBackground(channelId);
      return _channelCache[channelId];
    }

    // Check persistent cache
    if (!forceRefresh && _cacheService.isInitialized) {
      final cached = await _loadChannelFromCache(channelId);
      if (cached != null) {
        _channelCache[channelId] = cached;
        _refreshChannelInBackground(channelId);
        return cached;
      }
    }

    return _fetchChannelFromNetwork(channelId);
  }

  /// Load channel from persistent cache.
  Future<Channel?> _loadChannelFromCache(String channelId) async {
    try {
      final cached = await _cacheService.get<Map<String, dynamic>>(
        _channelCacheKey(channelId),
        allowStale: true,
      );
      if (cached != null) {
        return Channel(
          id: cached['id'] as String,
          name: cached['name'] as String,
          about: cached['about'] as String?,
          picture: cached['picture'] as String?,
          creatorPubkey: cached['creatorPubkey'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            (cached['createdAt'] as int) * 1000,
          ),
          relayUrl: cached['relayUrl'] as String?,
        );
      }
    } catch (e) {
      // debugPrint('Error loading channel from cache: $e');
    }
    return null;
  }

  /// Refresh channel in background if stale.
  Future<void> _refreshChannelInBackground(String channelId) async {
    if (!_cacheService.isInitialized) return;

    final isStale = await _cacheService.isStale(_channelCacheKey(channelId));
    if (isStale) {
      unawaited(_fetchChannelFromNetwork(channelId).catchError((Object e) {
        // debugPrint('Background channel refresh failed: $e');
        return null; // Return null to satisfy type
      }));
    }
  }

  /// Fetch channel from network.
  Future<Channel?> _fetchChannelFromNetwork(String channelId) async {
    try {
      await _ndkService.connectToRelays();

      final filter = Filter(
        kinds: [kindChannelCreation],
        ids: [channelId],
        limit: 1,
      );

      final events = await _ndkService.fetchEvents(filter: filter);
      if (events.isEmpty) return null;

      final channel = Channel.fromEvent(
        eventId: events.first.id,
        content: events.first.content,
        pubkey: events.first.pubKey,
        createdAt: events.first.createdAt,
      );

      // Cache the channel
      _channelCache[channelId] = channel;
      await _cacheChannel(channel);

      return channel;
    } catch (e) {
      // debugPrint('Error fetching channel: $e');
      return null;
    }
  }

  /// Cache a single channel.
  Future<void> _cacheChannel(Channel channel) async {
    if (!_cacheService.isInitialized) return;

    try {
      await _cacheService.set(
        _channelCacheKey(channel.id),
        {
          'id': channel.id,
          'name': channel.name,
          'about': channel.about,
          'picture': channel.picture,
          'creatorPubkey': channel.creatorPubkey,
          'createdAt': channel.createdAt.millisecondsSinceEpoch ~/ 1000,
          'relayUrl': channel.relayUrl,
        },
        CacheConfig.channelsTtl,
      );
    } catch (e) {
      // debugPrint('Error caching channel: $e');
    }
  }

  /// Fetch messages for a specific channel.
  ///
  /// [channelId] - The channel ID (event ID of kind:40 event).
  /// [limit] - Maximum number of messages to fetch.
  /// [until] - Only fetch messages created before this timestamp.
  Future<List<ChannelMessage>> fetchChannelMessages({
    required String channelId,
    int limit = 50,
    int? until,
  }) async {
    try {
      // debugPrint('Fetching messages for channel: ${channelId.substring(0, 8)}...');

      // Ensure relays are connected
      await _ndkService.connectToRelays();

      // Query for kind:42 (channel message) events referencing this channel
      final filter = Filter(
        kinds: [kindChannelMessage],
        eTags: [channelId],
        limit: limit,
        until: until,
      );

      final events = await _ndkService.fetchEvents(filter: filter);

      if (events.isEmpty) {
        // debugPrint('No messages found for channel');
        return [];
      }

      // Convert events to ChannelMessage models
      final messages = events.map((event) {
        return ChannelMessage.fromEvent(
          eventId: event.id,
          content: event.content,
          pubkey: event.pubKey,
          createdAt: event.createdAt,
          tags: event.tags,
        );
      }).toList();

      // Sort by creation date (oldest first for chat display)
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // debugPrint('Fetched ${messages.length} messages');
      return messages;
    } catch (e, stackTrace) {
      // debugPrint('Error fetching channel messages: $e\n$stackTrace');
      return [];
    }
  }

  /// Create a new channel.
  ///
  /// Creates a kind:40 event with channel metadata.
  ///
  /// [name] - Channel name (required).
  /// [about] - Channel description (optional).
  /// [picture] - Channel picture URL (optional).
  /// [privateKey] - User's private key for signing.
  ///
  /// Returns the created [Channel] on success, null on failure.
  Future<Channel?> createChannel({
    required String name,
    String? about,
    String? picture,
    required String privateKey,
  }) async {
    try {
      // debugPrint('Creating channel: $name');

      // Ensure relays are connected
      await _ndkService.connectToRelays();

      // Get public key from private key
      final publicKey = Bip340.getPublicKey(privateKey);

      // Create channel metadata
      final channel = Channel(
        id: '', // Will be set after event creation
        name: name,
        about: about,
        picture: picture,
        creatorPubkey: publicKey,
        createdAt: DateTime.now(),
      );

      // Create kind:40 event
      final event = Nip01Event(
        pubKey: publicKey,
        kind: kindChannelCreation,
        content: channel.toEventContent(),
        tags: [],
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Sign the event
      event.sign(privateKey);

      // Broadcast to relays
      final broadcastResponse = _ndkService.ndk.broadcast.broadcast(
        nostrEvent: event,
      );

      await broadcastResponse.broadcastDoneFuture;

      // debugPrint('Channel created: ${event.id}');

      // Create channel with the event ID
      final createdChannel = Channel(
        id: event.id,
        name: name,
        about: about,
        picture: picture,
        creatorPubkey: publicKey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
      );

      // Update caches
      _channelCache[event.id] = createdChannel;
      await _cacheChannel(createdChannel);

      // Invalidate channel list cache to include new channel
      if (_cacheService.isInitialized) {
        await _cacheService.remove(CacheConfig.channelListKey);
      }

      return createdChannel;
    } catch (e, stackTrace) {
      // debugPrint('Error creating channel: $e\n$stackTrace');
      return null;
    }
  }

  /// Send a message to a channel.
  ///
  /// Creates a kind:42 event referencing the channel.
  ///
  /// [channelId] - The channel ID to send the message to.
  /// [content] - Message content.
  /// [privateKey] - User's private key for signing.
  /// [replyToId] - Optional message ID being replied to.
  /// [replyToAuthorPubkey] - Optional author pubkey being replied to.
  ///
  /// Returns the created [ChannelMessage] on success, null on failure.
  Future<ChannelMessage?> sendMessage({
    required String channelId,
    required String content,
    required String privateKey,
    String? replyToId,
    String? replyToAuthorPubkey,
  }) async {
    try {
      // debugPrint('Sending message to channel: ${channelId.substring(0, 8)}...');

      // Ensure relays are connected
      await _ndkService.connectToRelays();

      // Get public key from private key
      final publicKey = Bip340.getPublicKey(privateKey);

      // Create NIP-28 tags
      final tags = ChannelMessage.createMessageTags(
        channelId: channelId,
        relayUrl: kDefaultRelays.isNotEmpty ? kDefaultRelays.first : null,
        replyToId: replyToId,
        replyToAuthorPubkey: replyToAuthorPubkey,
      );

      // Create kind:42 event
      final event = Nip01Event(
        pubKey: publicKey,
        kind: kindChannelMessage,
        content: content,
        tags: tags,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Sign the event
      event.sign(privateKey);

      // Broadcast to relays
      final broadcastResponse = _ndkService.ndk.broadcast.broadcast(
        nostrEvent: event,
      );

      await broadcastResponse.broadcastDoneFuture;

      // debugPrint('Message sent: ${event.id}');

      // Return the created message
      return ChannelMessage(
        id: event.id,
        channelId: channelId,
        content: content,
        authorPubkey: publicKey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
        replyToId: replyToId,
        replyToAuthorPubkey: replyToAuthorPubkey,
      );
    } catch (e, stackTrace) {
      // debugPrint('Error sending message: $e\n$stackTrace');
      return null;
    }
  }

  /// Subscribe to real-time messages for a channel.
  ///
  /// Returns a stream of [ChannelMessage] objects as they arrive.
  ///
  /// [channelId] - The channel ID to subscribe to.
  ///
  /// Remember to call [unsubscribeFromChannel] when done.
  Stream<ChannelMessage> subscribeToChannel(String channelId) {
    // Return existing stream if already subscribed
    if (_messageControllers.containsKey(channelId)) {
      return _messageControllers[channelId]!.stream;
    }

    // debugPrint('Subscribing to channel: ${channelId.substring(0, 8)}...');

    // Create a new stream controller
    final controller = StreamController<ChannelMessage>.broadcast();
    _messageControllers[channelId] = controller;

    // Start subscription
    _startSubscription(channelId);

    return controller.stream;
  }

  /// Start the underlying NDK subscription for a channel.
  Future<void> _startSubscription(String channelId) async {
    try {
      // Ensure relays are connected
      await _ndkService.connectToRelays();

      // Create filter for channel messages
      final filter = Filter(
        kinds: [kindChannelMessage],
        eTags: [channelId],
        since: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Stream events from relays
      final eventStream = _ndkService.streamEvents(filter: filter);

      // Subscribe and forward to controller
      final subscription = eventStream.listen(
        (event) {
          final message = ChannelMessage.fromEvent(
            eventId: event.id,
            content: event.content,
            pubkey: event.pubKey,
            createdAt: event.createdAt,
            tags: event.tags,
          );

          // Verify message is for this channel
          if (message.channelId == channelId) {
            _messageControllers[channelId]?.add(message);
          }
        },
        onError: (Object error) {
          // debugPrint('Subscription error for channel $channelId: $error');
        },
      );

      _subscriptions[channelId] = subscription;
      // debugPrint('Subscription started for channel: ${channelId.substring(0, 8)}...');
    } catch (e) {
      // debugPrint('Error starting subscription: $e');
    }
  }

  /// Unsubscribe from a channel's messages.
  ///
  /// [channelId] - The channel ID to unsubscribe from.
  void unsubscribeFromChannel(String channelId) {
    // debugPrint('Unsubscribing from channel: ${channelId.substring(0, 8)}...');

    // Cancel subscription
    _subscriptions[channelId]?.cancel();
    _subscriptions.remove(channelId);

    // Close stream controller
    _messageControllers[channelId]?.close();
    _messageControllers.remove(channelId);
  }

  /// Unsubscribe from all channels.
  void unsubscribeAll() {
    // debugPrint('Unsubscribing from all channels');

    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();

    for (final controller in _messageControllers.values) {
      controller.close();
    }
    _messageControllers.clear();
  }

  /// Clear all cached channel data.
  void clearCache() {
    _channelCache.clear();
    _cacheService.removeByPrefix(CacheConfig.channelKeyPrefix);
    _cacheService.remove(CacheConfig.channelListKey);
  }

  /// Dispose of all resources.
  void dispose() {
    unsubscribeAll();
  }
}
