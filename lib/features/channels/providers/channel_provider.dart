import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/channel_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../models/channel.dart';
import '../models/channel_message.dart';

/// Provider for ChannelService singleton.
final channelServiceProvider = Provider<ChannelService>((ref) {
  return ChannelService.instance;
});

// ============================================================================
// Channels List Provider
// ============================================================================

/// State for the channels list screen.
@immutable
sealed class ChannelsListState {
  const ChannelsListState();
}

/// Initial state - nothing loaded yet.
class ChannelsListStateInitial extends ChannelsListState {
  const ChannelsListStateInitial();
}

/// Loading state - fetching channels from relays.
class ChannelsListStateLoading extends ChannelsListState {
  const ChannelsListStateLoading();
}

/// Loaded state - channels available.
class ChannelsListStateLoaded extends ChannelsListState {
  const ChannelsListStateLoaded({
    required this.channels,
    this.isRefreshing = false,
  });

  /// List of discovered channels.
  final List<Channel> channels;

  /// Whether the list is currently being refreshed.
  final bool isRefreshing;

  ChannelsListStateLoaded copyWith({
    List<Channel>? channels,
    bool? isRefreshing,
  }) {
    return ChannelsListStateLoaded(
      channels: channels ?? this.channels,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

/// Error state - something went wrong.
class ChannelsListStateError extends ChannelsListState {
  const ChannelsListStateError({required this.message});

  final String message;
}

/// Provider for the channels list.
final channelsListProvider =
    StateNotifierProvider<ChannelsListNotifier, ChannelsListState>((ref) {
  return ChannelsListNotifier(ref);
});

/// Notifier for managing channels list state.
class ChannelsListNotifier extends StateNotifier<ChannelsListState> {
  ChannelsListNotifier(this._ref) : super(const ChannelsListStateInitial());

  final Ref _ref;
  final _channelService = ChannelService.instance;

  /// Load channels from relays.
  Future<void> loadChannels() async {
    state = const ChannelsListStateLoading();

    try {
      // debugPrint('Loading channels...');

      final channels = await _channelService.fetchChannels(limit: 100);

      state = ChannelsListStateLoaded(channels: channels);
      // debugPrint('Loaded ${channels.length} channels');
    } catch (e, stackTrace) {
      // debugPrint('Error loading channels: $e\n$stackTrace');
      state = ChannelsListStateError(
        message: 'Failed to load channels: ${e.toString()}',
      );
    }
  }

  /// Refresh the channels list.
  Future<void> refresh() async {
    final currentState = state;
    if (currentState is ChannelsListStateLoaded) {
      state = currentState.copyWith(isRefreshing: true);
    }

    try {
      final channels = await _channelService.fetchChannels(limit: 100);

      state = ChannelsListStateLoaded(channels: channels);
    } catch (e) {
      // debugPrint('Error refreshing channels: $e');
      // Keep existing state on refresh error
      if (currentState is ChannelsListStateLoaded) {
        state = currentState.copyWith(isRefreshing: false);
      }
    }
  }

  /// Create a new channel.
  Future<Channel?> createChannel({
    required String name,
    String? about,
    String? picture,
  }) async {
    final authState = _ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) {
      // debugPrint('Cannot create channel: not authenticated');
      return null;
    }

    try {
      final channel = await _channelService.createChannel(
        name: name,
        about: about,
        picture: picture,
        privateKey: authState.keypair.privateKey!,
      );

      if (channel != null) {
        // Add to the list
        final currentState = state;
        if (currentState is ChannelsListStateLoaded) {
          state = currentState.copyWith(
            channels: [channel, ...currentState.channels],
          );
        }
      }

      return channel;
    } catch (e) {
      // debugPrint('Error creating channel: $e');
      return null;
    }
  }
}

// ============================================================================
// Channel Chat Provider (per channel)
// ============================================================================

/// State for a single channel's chat.
@immutable
sealed class ChannelChatState {
  const ChannelChatState();
}

/// Initial state - nothing loaded yet.
class ChannelChatStateInitial extends ChannelChatState {
  const ChannelChatStateInitial();
}

/// Loading state - fetching messages.
class ChannelChatStateLoading extends ChannelChatState {
  const ChannelChatStateLoading();
}

/// Loaded state - messages available.
class ChannelChatStateLoaded extends ChannelChatState {
  const ChannelChatStateLoaded({
    required this.channel,
    required this.messages,
    this.isLoadingMore = false,
    this.isSending = false,
    this.hasMore = true,
  });

  /// The channel being viewed.
  final Channel channel;

  /// List of messages in the channel.
  final List<ChannelMessage> messages;

  /// Whether older messages are being loaded.
  final bool isLoadingMore;

  /// Whether a message is being sent.
  final bool isSending;

  /// Whether there are more messages to load.
  final bool hasMore;

  ChannelChatStateLoaded copyWith({
    Channel? channel,
    List<ChannelMessage>? messages,
    bool? isLoadingMore,
    bool? isSending,
    bool? hasMore,
  }) {
    return ChannelChatStateLoaded(
      channel: channel ?? this.channel,
      messages: messages ?? this.messages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Error state - something went wrong.
class ChannelChatStateError extends ChannelChatState {
  const ChannelChatStateError({required this.message});

  final String message;
}

/// Provider for a channel's chat state.
///
/// Uses a family provider keyed by channel ID.
final channelChatProvider = StateNotifierProvider.family<
    ChannelChatNotifier, ChannelChatState, String>((ref, channelId) {
  return ChannelChatNotifier(ref, channelId);
});

/// Notifier for managing a single channel's chat state.
class ChannelChatNotifier extends StateNotifier<ChannelChatState> {
  ChannelChatNotifier(this._ref, this._channelId)
      : super(const ChannelChatStateInitial());

  final Ref _ref;
  final String _channelId;
  final _channelService = ChannelService.instance;

  StreamSubscription<ChannelMessage>? _messageSubscription;

  /// Load the channel and its messages.
  Future<void> loadChannel(Channel channel) async {
    state = const ChannelChatStateLoading();

    try {
      // debugPrint('Loading chat for channel: ${channel.name}');

      // Fetch initial messages
      final messages = await _channelService.fetchChannelMessages(
        channelId: _channelId,
        limit: 50,
      );

      state = ChannelChatStateLoaded(
        channel: channel,
        messages: messages,
        hasMore: messages.length >= 50,
      );

      // Subscribe to new messages
      _subscribeToMessages();

      // debugPrint('Loaded ${messages.length} messages');
    } catch (e, stackTrace) {
      // debugPrint('Error loading channel chat: $e\n$stackTrace');
      state = ChannelChatStateError(
        message: 'Failed to load messages: ${e.toString()}',
      );
    }
  }

  /// Subscribe to real-time messages.
  void _subscribeToMessages() {
    // Cancel existing subscription
    _messageSubscription?.cancel();

    // Subscribe to new messages
    final stream = _channelService.subscribeToChannel(_channelId);
    _messageSubscription = stream.listen(
      (message) {
        _addMessage(message);
      },
      onError: (Object error) {
        // debugPrint('Message subscription error: $error');
      },
    );
  }

  /// Add a new message to the list.
  void _addMessage(ChannelMessage message) {
    final currentState = state;
    if (currentState is! ChannelChatStateLoaded) return;

    // Check for duplicates
    if (currentState.messages.any((m) => m.id == message.id)) {
      return;
    }

    // Add message and sort
    final updatedMessages = [...currentState.messages, message];
    updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    state = currentState.copyWith(messages: updatedMessages);
  }

  /// Load older messages (pagination).
  Future<void> loadMoreMessages() async {
    final currentState = state;
    if (currentState is! ChannelChatStateLoaded) return;
    if (currentState.isLoadingMore || !currentState.hasMore) return;

    state = currentState.copyWith(isLoadingMore: true);

    try {
      final oldestMessage = currentState.messages.isNotEmpty
          ? currentState.messages.first
          : null;

      final until = oldestMessage?.createdAt.millisecondsSinceEpoch != null
          ? (oldestMessage!.createdAt.millisecondsSinceEpoch ~/ 1000) - 1
          : null;

      final olderMessages = await _channelService.fetchChannelMessages(
        channelId: _channelId,
        limit: 50,
        until: until,
      );

      if (olderMessages.isEmpty) {
        state = currentState.copyWith(
          isLoadingMore: false,
          hasMore: false,
        );
        return;
      }

      // Merge messages, avoiding duplicates
      final existingIds = currentState.messages.map((m) => m.id).toSet();
      final newMessages = olderMessages.where((m) => !existingIds.contains(m.id)).toList();

      final allMessages = [...newMessages, ...currentState.messages];
      allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      state = currentState.copyWith(
        messages: allMessages,
        isLoadingMore: false,
        hasMore: olderMessages.length >= 50,
      );
    } catch (e) {
      // debugPrint('Error loading more messages: $e');
      state = currentState.copyWith(isLoadingMore: false);
    }
  }

  /// Send a message to the channel.
  Future<bool> sendMessage({
    required String content,
    String? replyToId,
    String? replyToAuthorPubkey,
  }) async {
    final currentState = state;
    if (currentState is! ChannelChatStateLoaded) return false;

    final authState = _ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) {
      // debugPrint('Cannot send message: not authenticated');
      return false;
    }

    state = currentState.copyWith(isSending: true);

    try {
      final message = await _channelService.sendMessage(
        channelId: _channelId,
        content: content,
        privateKey: authState.keypair.privateKey!,
        replyToId: replyToId,
        replyToAuthorPubkey: replyToAuthorPubkey,
      );

      if (message != null) {
        // Add message to list (will be deduplicated if received via subscription)
        _addMessage(message);
        state = (state as ChannelChatStateLoaded).copyWith(isSending: false);
        return true;
      }

      state = currentState.copyWith(isSending: false);
      return false;
    } catch (e) {
      // debugPrint('Error sending message: $e');
      state = currentState.copyWith(isSending: false);
      return false;
    }
  }

  /// Refresh messages.
  Future<void> refresh() async {
    final currentState = state;
    if (currentState is! ChannelChatStateLoaded) return;

    try {
      final messages = await _channelService.fetchChannelMessages(
        channelId: _channelId,
        limit: 50,
      );

      state = currentState.copyWith(
        messages: messages,
        hasMore: messages.length >= 50,
      );
    } catch (e) {
      // debugPrint('Error refreshing messages: $e');
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    // Use unawaited to ensure cleanup happens without blocking dispose
    unawaited(_channelService.unsubscribeFromChannel(_channelId));
    super.dispose();
  }
}
