import 'package:flutter/material.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

/// A button to send zaps (Lightning payments) to a Nostr user or event.
///
/// This is a placeholder implementation. Full functionality will be added
/// in Phase 2 when wallet integration is complete.
class ZapButton extends StatefulWidget {
  const ZapButton({
    super.key,
    required this.recipientPubkey,
    this.eventId,
    this.defaultAmount = 21,
    this.onZapSent,
    this.size = ZapButtonSize.medium,
  });

  /// The recipient's Nostr public key (hex or npub).
  final String recipientPubkey;

  /// Optional event ID to zap a specific post.
  final String? eventId;

  /// Default zap amount in sats.
  final int defaultAmount;

  /// Callback when zap is successfully sent.
  final void Function(int amount)? onZapSent;

  /// Button size variant.
  final ZapButtonSize size;

  @override
  State<ZapButton> createState() => _ZapButtonState();
}

class _ZapButtonState extends State<ZapButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // TODO: Show zap amount picker and process zap in Phase 2
    _showComingSoonDialog();
  }

  void _showComingSoonDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.bolt, color: AppColors.zapOrange, size: 28),
            const SizedBox(width: 8),
            const Text('Zaps', style: AppTypography.headlineMedium),
          ],
        ),
        content: const Text(
          'Zap functionality will be available in Phase 2 with wallet integration.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = switch (widget.size) {
      ZapButtonSize.small => 16.0,
      ZapButtonSize.medium => 20.0,
      ZapButtonSize.large => 24.0,
    };

    final padding = switch (widget.size) {
      ZapButtonSize.small => const EdgeInsets.all(6),
      ZapButtonSize.medium => const EdgeInsets.all(8),
      ZapButtonSize.large => const EdgeInsets.all(10),
    };

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        _handleTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _isPressed
                ? AppColors.zapOrange.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt,
                size: iconSize,
                color: _isPressed ? AppColors.zapOrange : AppColors.textSecondary,
              ),
              // Zap count will be shown here when zap functionality is implemented
              // For now, only show the icon without a count
            ],
          ),
        ),
      ),
    );
  }
}

/// Size variants for [ZapButton].
enum ZapButtonSize {
  small,
  medium,
  large,
}
