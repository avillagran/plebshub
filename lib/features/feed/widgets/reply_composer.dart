import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../providers/thread_provider.dart';

/// A widget for composing replies to posts.
///
/// Displays a text input with "Replying to @username" indicator
/// and a submit button.
class ReplyComposer extends ConsumerStatefulWidget {
  const ReplyComposer({
    super.key,
    required this.threadEventId,
    required this.replyToId,
    required this.replyToAuthorPubkey,
    required this.replyToDisplayName,
    this.onReplyPublished,
    this.autoFocus = false,
  });

  /// The root thread event ID (for provider).
  final String threadEventId;

  /// The event ID to reply to.
  final String replyToId;

  /// The pubkey of the post author being replied to.
  final String replyToAuthorPubkey;

  /// Display name of the user being replied to.
  final String replyToDisplayName;

  /// Callback when a reply is successfully published.
  final VoidCallback? onReplyPublished;

  /// Whether to auto-focus the text field.
  final bool autoFocus;

  @override
  ConsumerState<ReplyComposer> createState() => _ReplyComposerState();
}

class _ReplyComposerState extends ConsumerState<ReplyComposer> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _publishReply() async {
    final content = _textController.text.trim();

    if (content.isEmpty) {
      _showSnackBar('Please enter a reply', isError: true);
      return;
    }

    final authState = ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) {
      _showSnackBar('You must be logged in to reply', isError: true);
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      final success = await ref
          .read(threadProvider(widget.threadEventId).notifier)
          .publishReply(
            content: content,
            privateKey: authState.keypair.privateKey!,
            replyToId: widget.replyToId,
            replyToAuthorPubkey: widget.replyToAuthorPubkey,
          );

      if (success) {
        _textController.clear();
        _showSnackBar('Reply published!');
        widget.onReplyPublished?.call();
      } else {
        _showSnackBar('Failed to publish reply', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState is AuthStateAuthenticated;

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
            // Replying to indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Replying to ',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '@${widget.replyToDisplayName}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
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
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    enabled: isAuthenticated && !_isPublishing,
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: isAuthenticated
                          ? 'Write your reply...'
                          : 'Login to reply',
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
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                if (_isPublishing)
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
                    onPressed: isAuthenticated && _textController.text.trim().isNotEmpty
                        ? _publishReply
                        : null,
                    icon: Icon(
                      Icons.send,
                      color: isAuthenticated && _textController.text.trim().isNotEmpty
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
}

/// A compact reply button that expands into a composer.
class ReplyButton extends StatefulWidget {
  const ReplyButton({
    super.key,
    required this.threadEventId,
    required this.replyToId,
    required this.replyToAuthorPubkey,
    required this.replyToDisplayName,
    this.replyCount = 0,
  });

  final String threadEventId;
  final String replyToId;
  final String replyToAuthorPubkey;
  final String replyToDisplayName;
  final int replyCount;

  @override
  State<ReplyButton> createState() => _ReplyButtonState();
}

class _ReplyButtonState extends State<ReplyButton> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isExpanded ? Icons.close : Icons.chat_bubble_outline,
                  size: 20,
                  color: _isExpanded ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.replyCount > 0 ? '${widget.replyCount}' : '',
                  style: AppTypography.labelMedium,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ReplyComposer(
              threadEventId: widget.threadEventId,
              replyToId: widget.replyToId,
              replyToAuthorPubkey: widget.replyToAuthorPubkey,
              replyToDisplayName: widget.replyToDisplayName,
              autoFocus: true,
              onReplyPublished: () {
                setState(() {
                  _isExpanded = false;
                });
              },
            ),
          ),
      ],
    );
  }
}
