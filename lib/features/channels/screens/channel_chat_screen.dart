import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../shared/shared.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../models/channel.dart';
import '../models/channel_message.dart';
import '../providers/channel_provider.dart';
import '../widgets/channel_message_bubble.dart';

/// Screen for displaying and interacting with a channel chat.
///
/// Features:
/// - Messages list (oldest at top, newest at bottom)
/// - Auto-scroll to new messages
/// - Pull down for older messages
/// - Message input at bottom
/// - Real-time updates via subscription
class ChannelChatScreen extends ConsumerStatefulWidget {
  const ChannelChatScreen({
    super.key,
    required this.channelId,
    this.channel,
  });

  /// The channel ID to display.
  final String channelId;

  /// Optional pre-loaded channel data.
  final Channel? channel;

  @override
  ConsumerState<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends ConsumerState<ChannelChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  String? _replyToId;
  String? _replyToAuthorPubkey;

  bool _isAtBottom = true;

  @override
  void initState() {
    super.initState();

    // Track scroll position
    _scrollController.addListener(_onScroll);

    // Load channel data
    Future.microtask(() => _loadChannel());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadChannel() {
    // If channel data is provided, use it
    if (widget.channel != null) {
      ref
          .read(channelChatProvider(widget.channelId).notifier)
          .loadChannel(widget.channel!);
    } else {
      // Need to fetch channel info first - for now use a placeholder
      final channel = Channel(
        id: widget.channelId,
        name: 'Channel',
        creatorPubkey: '',
        createdAt: DateTime.now(),
      );
      ref
          .read(channelChatProvider(widget.channelId).notifier)
          .loadChannel(channel);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // Check if we're near the bottom
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    _isAtBottom = currentScroll >= maxScroll - 50;

    // Load more when scrolled near the top
    if (currentScroll <= 100) {
      ref.read(channelChatProvider(widget.channelId).notifier).loadMoreMessages();
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animate) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final authState = ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to send messages'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Clear the input immediately for responsiveness
    _messageController.clear();
    _clearReply();

    final success = await ref
        .read(channelChatProvider(widget.channelId).notifier)
        .sendMessage(
          content: content,
          replyToId: _replyToId,
          replyToAuthorPubkey: _replyToAuthorPubkey,
        );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Scroll to bottom after sending
      _scrollToBottom();
    }
  }

  void _setReplyTo(ChannelMessage message) {
    setState(() {
      _replyToId = message.id;
      _replyToAuthorPubkey = message.authorPubkey;
    });
    _focusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyToId = null;
      _replyToAuthorPubkey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(channelChatProvider(widget.channelId));
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState is AuthStateAuthenticated;

    // Get current user's pubkey for identifying own messages
    final currentUserPubkey = authState is AuthStateAuthenticated
        ? authState.keypair.publicKey
        : null;

    // Auto-scroll when new messages arrive
    ref.listen<ChannelChatState>(
      channelChatProvider(widget.channelId),
      (previous, next) {
        if (previous is ChannelChatStateLoaded &&
            next is ChannelChatStateLoaded &&
            next.messages.length > previous.messages.length) {
          // New message arrived
          if (_isAtBottom) {
            _scrollToBottom();
          }
        }
      },
    );

    // Content fills entire available width
    return ResponsiveContent(
      child: Scaffold(
        appBar: _buildAppBar(chatState),
        body: _buildBody(chatState, currentUserPubkey, isAuthenticated),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ChannelChatState state) {
    final channelName = switch (state) {
      ChannelChatStateLoaded(:final channel) => channel.name,
      _ => 'Channel',
    };

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          Icon(
            Icons.tag,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              channelName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        // Channel info button (could show channel details)
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () {
            final chatState = ref.read(channelChatProvider(widget.channelId));
            if (chatState is ChannelChatStateLoaded) {
              _showChannelInfo(chatState.channel);
            }
          },
        ),
      ],
    );
  }

  Widget _buildBody(
    ChannelChatState state,
    String? currentUserPubkey,
    bool isAuthenticated,
  ) {
    return switch (state) {
      ChannelChatStateInitial() => const Center(
          child: Text('Loading...'),
        ),
      ChannelChatStateLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      ChannelChatStateError(:final message) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading channel',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message,
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadChannel,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ChannelChatStateLoaded(
        :final messages,
        :final isLoadingMore,
        :final isSending,
      ) =>
        Column(
          children: [
            // Messages list
            Expanded(
              child: _buildMessagesList(
                messages,
                isLoadingMore,
                currentUserPubkey,
              ),
            ),

            // Message composer
            _buildMessageComposer(isAuthenticated, isSending),
          ],
        ),
    };
  }

  Widget _buildMessagesList(
    List<ChannelMessage> messages,
    bool isLoadingMore,
    String? currentUserPubkey,
  ) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to say something!',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Loading indicator at the top
        if (isLoadingMore && index == 0) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final messageIndex = isLoadingMore ? index - 1 : index;
        final message = messages[messageIndex];
        final isOwnMessage = currentUserPubkey != null &&
            message.authorPubkey == currentUserPubkey;

        return ChannelMessageBubble(
          message: message,
          isOwnMessage: isOwnMessage,
          onReply: () => _setReplyTo(message),
        );
      },
    );
  }

  Widget _buildMessageComposer(bool isAuthenticated, bool isSending) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reply indicator
            if (_replyToId != null)
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.reply,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Replying to message',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: _clearReply,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // Input row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    enabled: isAuthenticated && !isSending,
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: isAuthenticated
                          ? 'Type a message...'
                          : 'Log in to send messages',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button
                if (isSending)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    onPressed: isAuthenticated &&
                            _messageController.text.trim().isNotEmpty
                        ? _sendMessage
                        : null,
                    icon: Icon(
                      Icons.send,
                      color: isAuthenticated &&
                              _messageController.text.trim().isNotEmpty
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showChannelInfo(Channel channel) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Channel name
            Row(
              children: [
                Icon(
                  Icons.tag,
                  size: 24,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    channel.name,
                    style: AppTypography.headlineSmall,
                  ),
                ),
              ],
            ),

            // Description
            if (channel.about != null && channel.about!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Description',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                channel.about!,
                style: AppTypography.bodyMedium,
              ),
            ],

            // Created info
            const SizedBox(height: 16),
            Text(
              'Created',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDateTime(channel.createdAt),
              style: AppTypography.bodyMedium,
            ),

            // Creator
            const SizedBox(height: 16),
            Text(
              'Creator',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                context.push('/profile/${channel.creatorPubkey}');
              },
              child: Text(
                _truncatePubkey(channel.creatorPubkey),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _truncatePubkey(String pubkey) {
    if (pubkey.isEmpty) return 'Unknown';
    if (pubkey.length <= 16) return pubkey;
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 8)}';
  }
}
