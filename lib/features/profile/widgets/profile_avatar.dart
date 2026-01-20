import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../shared/widgets/smart_image.dart';
import '../providers/profile_cache_provider.dart';

/// A reactive widget that displays a user's avatar.
///
/// Shows a colored circle placeholder with initial initially,
/// then automatically updates when the profile picture URL loads.
///
/// Example:
/// ```dart
/// ProfileAvatar(
///   pubkey: authorPubkey,
///   size: 40,
///   onTap: () => navigateToProfile(authorPubkey),
/// )
/// ```
class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({
    super.key,
    required this.pubkey,
    this.size = 40,
    this.onTap,
    this.borderRadius,
  });

  /// The pubkey of the user whose avatar to display.
  final String pubkey;

  /// Size of the avatar (width and height).
  final double size;

  /// Optional callback when avatar is tapped.
  final VoidCallback? onTap;

  /// Optional border radius. Defaults to circular.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the profile from cache - triggers fetch if not cached
    final profile = ref.watch(watchProfileProvider(pubkey));

    final pictureUrl = profile?.picture;
    final displayName = profile?.nameForDisplay ?? '';
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(size / 2);

    Widget avatar;

    if (pictureUrl != null && pictureUrl.isNotEmpty) {
      // Profile has a picture URL - load it
      avatar = ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: SmartImage(
          imageUrl: pictureUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholder(displayName),
          errorWidget: (context, url, error) => _buildPlaceholder(displayName),
        ),
      );
    } else {
      // No picture URL yet (or doesn't have one) - show placeholder
      avatar = _buildPlaceholder(displayName);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  /// Build a placeholder avatar with colored background and initial.
  Widget _buildPlaceholder(String displayName) {
    // Generate a consistent color based on pubkey
    final color = _generateColor(pubkey);
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: AppTypography.titleLarge.copyWith(
            fontSize: size * 0.4,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Generate a consistent color based on pubkey.
  ///
  /// Uses the first 6 hex characters of the pubkey to generate
  /// a color that's not too light or too dark.
  Color _generateColor(String pubkey) {
    // Use pubkey hash for consistent color
    final hash = pubkey.hashCode.abs();

    // Generate HSL color with good saturation and lightness
    final hue = (hash % 360).toDouble();
    const saturation = 0.6;
    const lightness = 0.45;

    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }
}

/// A variant of ProfileAvatar that uses AppColors.surfaceVariant as placeholder.
///
/// This matches the original PostCard style more closely.
class ProfileAvatarSimple extends ConsumerWidget {
  const ProfileAvatarSimple({
    super.key,
    required this.pubkey,
    this.size = 40,
    this.onTap,
  });

  /// The pubkey of the user whose avatar to display.
  final String pubkey;

  /// Size of the avatar (width and height).
  final double size;

  /// Optional callback when avatar is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the profile from cache - triggers fetch if not cached
    final profile = ref.watch(watchProfileProvider(pubkey));

    final pictureUrl = profile?.picture;
    final displayName = profile?.nameForDisplay ?? '';

    Widget avatar;

    if (pictureUrl != null && pictureUrl.isNotEmpty) {
      avatar = ClipOval(
        child: SmartImage(
          imageUrl: pictureUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholder(displayName),
          errorWidget: (context, url, error) => _buildPlaceholder(displayName),
        ),
      );
    } else {
      avatar = _buildPlaceholder(displayName);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildPlaceholder(String displayName) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: AppTypography.titleLarge.copyWith(fontSize: size * 0.4),
        ),
      ),
    );
  }
}
