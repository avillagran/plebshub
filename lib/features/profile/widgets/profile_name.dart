import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../providers/profile_cache_provider.dart';

/// A reactive widget that displays a user's name.
///
/// Shows the shortened pubkey initially, then automatically updates
/// when the profile data loads with the user's display name.
///
/// No loading spinner - just smooth text updates.
///
/// Example:
/// ```dart
/// ProfileName(
///   pubkey: authorPubkey,
///   style: TextStyle(fontWeight: FontWeight.bold),
/// )
/// ```
class ProfileName extends ConsumerWidget {
  const ProfileName({
    super.key,
    required this.pubkey,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.showVerificationBadge = false,
  });

  /// The pubkey of the user whose name to display.
  final String pubkey;

  /// Optional text style.
  final TextStyle? style;

  /// Maximum number of lines.
  final int maxLines;

  /// How to handle text overflow.
  final TextOverflow overflow;

  /// Whether to show a verification badge if user has NIP-05.
  final bool showVerificationBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the profile from cache - triggers fetch if not cached
    final profile = ref.watch(watchProfileProvider(pubkey));

    // Use profile name if available, otherwise shortened pubkey
    final displayName = profile?.nameForDisplay ?? _shortenPubkey(pubkey);
    final hasNip05 = profile?.nip05 != null;

    final effectiveStyle = style ??
        AppTypography.titleMedium.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        );

    if (showVerificationBadge && hasNip05) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              displayName,
              style: effectiveStyle,
              maxLines: maxLines,
              overflow: overflow,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.verified,
            size: 14,
            color: AppColors.success,
          ),
        ],
      );
    }

    return Text(
      displayName,
      style: effectiveStyle,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// Shorten a pubkey for display.
  String _shortenPubkey(String pubkey) {
    if (pubkey.length <= 12) return pubkey;
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
  }
}

/// A reactive widget that displays a user's username (@ handle).
///
/// Shows the shortened pubkey initially, then automatically updates
/// when the profile data loads with the user's name.
///
/// Example:
/// ```dart
/// ProfileUsername(
///   pubkey: authorPubkey,
///   style: TextStyle(color: Colors.grey),
/// )
/// ```
class ProfileUsername extends ConsumerWidget {
  const ProfileUsername({
    super.key,
    required this.pubkey,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.showAtSign = true,
    this.shortFormat = false,
  });

  /// The pubkey of the user whose username to display.
  final String pubkey;

  /// Optional text style.
  final TextStyle? style;

  /// Maximum number of lines.
  final int maxLines;

  /// How to handle text overflow.
  final TextOverflow overflow;

  /// Whether to prefix with @.
  final bool showAtSign;

  /// Use shorter pubkey format for mobile.
  final bool shortFormat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the profile from cache - triggers fetch if not cached
    final profile = ref.watch(watchProfileProvider(pubkey));

    // Use profile name if available, otherwise shortened pubkey
    String username;
    if (profile?.name != null && profile!.name!.isNotEmpty) {
      username = profile.name!;
    } else {
      username = shortFormat ? _shortenPubkeyShort(pubkey) : _shortenPubkey(pubkey);
    }

    final displayText = showAtSign ? '@$username' : username;

    final effectiveStyle = style ??
        AppTypography.bodySmall.copyWith(
          color: AppColors.textSecondary,
          fontSize: 14,
        );

    return Text(
      displayText,
      style: effectiveStyle,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// Shorten a pubkey for display.
  String _shortenPubkey(String pubkey) {
    if (pubkey.length <= 12) return pubkey;
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
  }

  /// Shorter pubkey format for mobile.
  String _shortenPubkeyShort(String pubkey) {
    if (pubkey.length <= 8) return pubkey;
    return '${pubkey.substring(0, 4)}...';
  }
}
