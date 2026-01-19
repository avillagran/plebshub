import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../services/ndk_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';

/// Screen for composing and publishing a new text note (kind:1).
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _textController = TextEditingController();
  final _ndkService = NdkService.instance;
  bool _isPublishing = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _publishNote() async {
    final content = _textController.text.trim();

    // Validate content
    if (content.isEmpty) {
      _showSnackBar('Please enter some content', isError: true);
      return;
    }

    // Get auth state
    final authState = ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) {
      _showSnackBar('You must be logged in to post', isError: true);
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      // Publish the note
      final publishedEvent = await _ndkService.publishTextNote(
        content: content,
        privateKey: authState.keypair.privateKey!,
      );

      if (publishedEvent != null) {
        // Success
        if (mounted) {
          _showSnackBar('Note published successfully!');
          // Navigate back to feed
          context.pop();
        }
      } else {
        // Failed to publish
        if (mounted) {
          _showSnackBar('Failed to publish note', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: ${e.toString()}', isError: true);
      }
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
    final characterCount = _textController.text.length;

    // Check if user is authenticated
    if (authState is! AuthStateAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Compose'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'You must be logged in to post',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.push('/auth'),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compose'),
        actions: [
          if (_isPublishing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _publishNote,
              child: Text(
                'Post',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Icon(
                    Icons.person,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _truncateNpub(authState.npub),
                        style: AppTypography.labelLarge,
                      ),
                      Text(
                        'Posting to global feed',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Text input
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: AppTypography.bodyLarge,
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}), // Update character count
                enabled: !_isPublishing,
              ),
            ),
            // Character counter
            if (characterCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '$characterCount characters',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Truncate npub for display.
  String _truncateNpub(String npub) {
    if (npub.length <= 16) {
      return npub;
    }
    return '${npub.substring(0, 12)}...${npub.substring(npub.length - 4)}';
  }
}
