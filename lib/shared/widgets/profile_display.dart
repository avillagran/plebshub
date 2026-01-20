import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../features/profile/models/profile.dart';
import '../../features/profile/providers/profile_cache_provider.dart';
import 'smart_image.dart';

/// Display modes for the ProfileDisplay widget.
///
/// Each mode shows different information about the profile:
/// - [full]: Avatar + name + nip05 verification (for post headers)
/// - [compact]: Avatar + name in a smaller format (for lists)
/// - [nameOnly]: Just the clickable name (for "Replying to @...")
/// - [avatarOnly]: Just the avatar image
enum ProfileDisplayMode {
  /// Full display with avatar, name, and NIP-05 verification.
  /// Best for post headers where you want complete profile information.
  full,

  /// Compact display with avatar and name in a smaller format.
  /// Best for lists or secondary profile mentions.
  compact,

  /// Only the profile name, styled as a clickable link.
  /// Best for inline mentions like "Replying to @username".
  nameOnly,

  /// Only the avatar image.
  /// Best for message bubbles or when space is limited.
  avatarOnly,
}

/// A reusable widget for displaying Nostr user profiles.
///
/// Uses the profile cache for efficient, cache-first loading with
/// automatic background fetches when needed.
///
/// Example usage:
/// ```dart
/// // Full profile display (avatar + name + nip05)
/// ProfileDisplay(
///   pubkey: authorPubkey,
///   mode: ProfileDisplayMode.full,
///   onTap: () => context.push('/profile/$authorPubkey'),
/// )
///
/// // Compact display for lists
/// ProfileDisplay(
///   pubkey: authorPubkey,
///   mode: ProfileDisplayMode.compact,
///   avatarRadius: 16,
/// )
///
/// // Just the name for "Replying to @..."
/// ProfileDisplay(
///   pubkey: replyToPubkey,
///   mode: ProfileDisplayMode.nameOnly,
/// )
///
/// // Just the avatar for chat messages
/// ProfileDisplay(
///   pubkey: senderPubkey,
///   mode: ProfileDisplayMode.avatarOnly,
///   avatarRadius: 18,
/// )
/// ```
class ProfileDisplay extends ConsumerWidget {
  const ProfileDisplay({
    super.key,
    required this.pubkey,
    this.mode = ProfileDisplayMode.full,
    this.onTap,
    this.avatarRadius = 20,
    this.nameStyle,
    this.showVerificationBadge = true,
    this.fallbackName,
    this.fallbackPicture,
  });

  /// The public key of the profile to display.
  final String pubkey;

  /// The display mode determining which elements to show.
  final ProfileDisplayMode mode;

  /// Optional callback when the profile is tapped.
  /// If null, the widget is not tappable.
  final VoidCallback? onTap;

  /// The radius of the avatar circle.
  /// Default is 20, making the avatar 40x40 pixels.
  final double avatarRadius;

  /// Optional text style override for the name.
  /// If null, uses default styling based on the mode.
  final TextStyle? nameStyle;

  /// Whether to show the NIP-05 verification badge.
  /// Only applies to [ProfileDisplayMode.full] mode.
  final bool showVerificationBadge;

  /// Optional fallback name to use while loading or if profile is unavailable.
  final String? fallbackName;

  /// Optional fallback picture URL to use while loading or if profile is unavailable.
  final String? fallbackPicture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the profile from cache - triggers background fetch if not cached
    final profile = ref.watch(watchProfileProvider(pubkey));

    // Use profile data if available, otherwise fall back to provided fallbacks
    final displayName = profile?.nameForDisplay ?? fallbackName ?? _formatPubkey(pubkey);
    final picture = profile?.picture ?? fallbackPicture;
    final nip05 = profile?.nip05;
    final hasNip05 = nip05 != null && nip05.isNotEmpty;

    final content = _buildContent(
      context,
      displayName: displayName,
      picture: picture,
      hasNip05: hasNip05,
      isLoading: profile == null,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }

  Widget _buildContent(
    BuildContext context, {
    required String displayName,
    String? picture,
    required bool hasNip05,
    required bool isLoading,
  }) {
    switch (mode) {
      case ProfileDisplayMode.full:
        return _buildFullDisplay(
          context,
          displayName: displayName,
          picture: picture,
          hasNip05: hasNip05,
          isLoading: isLoading,
        );
      case ProfileDisplayMode.compact:
        return _buildCompactDisplay(
          context,
          displayName: displayName,
          picture: picture,
          isLoading: isLoading,
        );
      case ProfileDisplayMode.nameOnly:
        return _buildNameOnlyDisplay(
          context,
          displayName: displayName,
          isLoading: isLoading,
        );
      case ProfileDisplayMode.avatarOnly:
        return _buildAvatarOnlyDisplay(
          displayName: displayName,
          picture: picture,
          isLoading: isLoading,
        );
    }
  }

  /// Full display: Avatar + Name + NIP-05 badge
  Widget _buildFullDisplay(
    BuildContext context, {
    required String displayName,
    String? picture,
    required bool hasNip05,
    required bool isLoading,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAvatar(displayName, picture, isLoading),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: nameStyle ??
                          AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (showVerificationBadge && hasNip05) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified,
                      size: 14,
                      color: AppColors.success,
                    ),
                  ],
                ],
              ),
              Text(
                '@${_formatPubkey(pubkey)}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact display: Avatar + Name in a single row
  Widget _buildCompactDisplay(
    BuildContext context, {
    required String displayName,
    String? picture,
    required bool isLoading,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAvatar(displayName, picture, isLoading),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            displayName,
            style: nameStyle ??
                AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  /// Name-only display: Just the clickable name
  Widget _buildNameOnlyDisplay(
    BuildContext context, {
    required String displayName,
    required bool isLoading,
  }) {
    return Text(
      '@$displayName',
      style: nameStyle ??
          AppTypography.bodyMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  /// Avatar-only display: Just the avatar
  Widget _buildAvatarOnlyDisplay({
    required String displayName,
    String? picture,
    required bool isLoading,
  }) {
    return _buildAvatar(displayName, picture, isLoading);
  }

  /// Build the avatar widget with profile picture support.
  Widget _buildAvatar(String displayName, String? picture, bool isLoading) {
    final diameter = avatarRadius * 2;

    if (picture != null && picture.isNotEmpty) {
      return ClipOval(
        child: SmartImage(
          imageUrl: picture,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildAvatarPlaceholder(displayName, diameter, isLoading),
          errorWidget: (context, url, error) => _buildAvatarPlaceholder(displayName, diameter, false),
        ),
      );
    }
    return _buildAvatarPlaceholder(displayName, diameter, isLoading);
  }

  /// Build avatar placeholder with initial letter.
  Widget _buildAvatarPlaceholder(String displayName, double diameter, bool isLoading) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: isLoading ? AppColors.surfaceVariant.withValues(alpha: 0.5) : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(avatarRadius),
      ),
      child: Center(
        child: isLoading
            ? SizedBox(
                width: diameter * 0.4,
                height: diameter * 0.4,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
              )
            : Text(
                initial,
                style: AppTypography.titleLarge.copyWith(
                  fontSize: diameter * 0.4,
                  color: AppColors.textSecondary,
                ),
              ),
      ),
    );
  }

  /// Format pubkey for display (first 8 + last 4 chars).
  String _formatPubkey(String pubkey) {
    if (pubkey.length <= 12) return pubkey;
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
  }
}

/// Extension for convenient profile display in widgets.
extension ProfileDisplayExtensions on Profile {
  /// Creates a ProfileDisplay widget from this profile.
  ///
  /// Note: This still uses the cache provider internally, but pre-populates
  /// with this profile's data as fallback.
  Widget toDisplay({
    ProfileDisplayMode mode = ProfileDisplayMode.full,
    VoidCallback? onTap,
    double avatarRadius = 20,
    TextStyle? nameStyle,
  }) {
    return ProfileDisplay(
      pubkey: pubkey,
      mode: mode,
      onTap: onTap,
      avatarRadius: avatarRadius,
      nameStyle: nameStyle,
      fallbackName: nameForDisplay,
      fallbackPicture: picture,
    );
  }
}
