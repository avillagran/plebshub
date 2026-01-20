import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../providers/channel_provider.dart';

/// Dialog for creating a new channel.
///
/// Allows the user to enter:
/// - Channel name (required)
/// - Description (optional)
/// - Picture URL (optional)
class CreateChannelDialog extends ConsumerStatefulWidget {
  const CreateChannelDialog({super.key});

  /// Show the dialog and return the created channel ID (or null if cancelled).
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (context) => const CreateChannelDialog(),
    );
  }

  @override
  ConsumerState<CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends ConsumerState<CreateChannelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final _pictureController = TextEditingController();

  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _pictureController.dispose();
    super.dispose();
  }

  Future<void> _createChannel() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final channel = await ref.read(channelsListProvider.notifier).createChannel(
        name: _nameController.text.trim(),
        about: _aboutController.text.trim().isNotEmpty
            ? _aboutController.text.trim()
            : null,
        picture: _pictureController.text.trim().isNotEmpty
            ? _pictureController.text.trim()
            : null,
      );

      if (mounted) {
        if (channel != null) {
          Navigator.of(context).pop(channel.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Channel "${channel.name}" created!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create channel. Please try again.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {
            _isCreating = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.tag,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          const Text('Create Channel'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Channel name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Channel Name',
                  hintText: 'e.g., nostr-dev',
                  prefixIcon: const Icon(Icons.tag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.none,
                enabled: !_isCreating,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a channel name';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  if (value.trim().length > 50) {
                    return 'Name must be 50 characters or less';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _aboutController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What is this channel about?',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
                minLines: 1,
                enabled: !_isCreating,
                validator: (value) {
                  if (value != null && value.length > 500) {
                    return 'Description must be 500 characters or less';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Picture URL
              TextFormField(
                controller: _pictureController,
                decoration: InputDecoration(
                  labelText: 'Picture URL (optional)',
                  hintText: 'https://example.com/icon.png',
                  prefixIcon: const Icon(Icons.image),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.url,
                enabled: !_isCreating,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final uri = Uri.tryParse(value);
                    if (uri == null || !uri.hasAbsolutePath) {
                      return 'Please enter a valid URL';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isCreating ? null : _createChannel,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
