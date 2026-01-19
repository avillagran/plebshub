import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A card with PlebsHub surface styling.
///
/// Uses the surface color with subtle border for depth.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderRadius = 12,
  });

  /// The card content.
  final Widget child;

  /// Padding inside the card.
  final EdgeInsetsGeometry padding;

  /// Optional tap callback.
  final VoidCallback? onTap;

  /// Border radius of the card.
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          hoverColor: AppColors.surfaceHover,
          child: card,
        ),
      );
    }

    return card;
  }
}
