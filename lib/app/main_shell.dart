import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../shared/shared.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/providers/auth_state.dart';
import '../features/columns/columns.dart';

/// Provider for the current navigation index.
final navigationIndexProvider = StateProvider<int>((ref) => 0);

/// The main shell widget that provides adaptive navigation.
///
/// This widget wraps the main content with an [AdaptiveScaffold] that
/// provides different navigation patterns based on screen size:
/// - Mobile: Bottom navigation bar
/// - Tablet: Navigation rail
/// - Desktop: Permanent navigation drawer
class MainShell extends ConsumerWidget {
  /// Creates a main shell.
  const MainShell({
    super.key,
    required this.child,
  });

  /// The current route's content.
  final Widget child;

  /// Navigation items for desktop/tablet (full menu).
  static const List<NavigationItem> _desktopNavigationItems = [
    NavigationItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
      path: '/',
    ),
    NavigationItem(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: 'Explore',
      path: '/explore',
    ),
    NavigationItem(
      icon: Icons.tag_outlined,
      selectedIcon: Icons.tag,
      label: 'Channels',
      path: '/channels',
    ),
    NavigationItem(
      icon: Icons.mail_outlined,
      selectedIcon: Icons.mail,
      label: 'Messages',
      path: '/messages',
    ),
    NavigationItem(
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications,
      label: 'Notifications',
      path: '/notifications',
    ),
    NavigationItem(
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library,
      label: 'Media',
      path: '/media-library',
    ),
    NavigationItem(
      icon: Icons.person_outlined,
      selectedIcon: Icons.person,
      label: 'Profile',
      path: '/profile',
    ),
  ];

  /// Navigation items for mobile (with "More" menu).
  static const List<NavigationItem> _mobileNavigationItems = [
    NavigationItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
      path: '/',
    ),
    NavigationItem(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: 'Explore',
      path: '/explore',
    ),
    NavigationItem(
      icon: Icons.tag_outlined,
      selectedIcon: Icons.tag,
      label: 'Channels',
      path: '/channels',
    ),
    NavigationItem(
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications,
      label: 'Notifications',
      path: '/notifications',
    ),
    NavigationItem(
      icon: Icons.more_horiz,
      selectedIcon: Icons.more_horiz,
      label: 'More',
      path: '/more', // Special path for popup menu
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationIndexProvider);
    final authState = ref.watch(authProvider);
    final isMobile = Responsive.isMobile(context);

    // Determine FAB visibility based on auth state
    final showFab = authState is AuthStateAuthenticated;

    // Use different navigation items based on screen size
    final navigationItems = isMobile ? _mobileNavigationItems : _desktopNavigationItems;

    // Adjust selected index for mobile (map desktop indices to mobile)
    final adjustedIndex = isMobile ? _getAdjustedMobileIndex(selectedIndex) : selectedIndex;

    return AdaptiveScaffold(
      selectedIndex: adjustedIndex,
      onDestinationSelected: (index) => _onNavigationSelected(context, ref, index, isMobile),
      navigationItems: navigationItems,
      appBar: Responsive.isMobile(context)
          ? AppBar(
              title: Row(
                children: [
                  Icon(Icons.bolt, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'PlebsHub',
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    // TODO: Implement search
                  },
                ),
                // Show different icon based on auth state
                if (showFab)
                  IconButton(
                    icon: const Icon(Icons.account_circle),
                    onPressed: () {
                      final authStateValue = ref.read(authProvider);
                      if (authStateValue is AuthStateAuthenticated) {
                        context.go('/profile/${authStateValue.keypair.publicKey}');
                      }
                    },
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.login),
                    onPressed: () => context.push('/auth'),
                  ),
              ],
            )
          : null,
      floatingActionButton: showFab && Responsive.isMobile(context)
          ? FloatingActionButton(
              onPressed: () => context.push('/compose'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.edit),
            )
          : null,
      showCompose: showFab,
      onCompose: () => context.push('/compose'),
      body: Responsive.isDesktop(context)
          ? const MultiColumnLayout() // Desktop: multi-column TweetDeck-style layout
          : Responsive.isMobile(context)
              ? child // Mobile: single column with bottom nav
              : Column(
                  // Tablet: breadcrumb header with single column content
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBreadcrumbHeader(context, selectedIndex),
                    Expanded(child: child),
                  ],
                ),
    );
  }

  /// Builds the breadcrumb header for desktop/tablet screens.
  /// Maps desktop navigation index to mobile navigation index.
  int _getAdjustedMobileIndex(int desktopIndex) {
    // Desktop: Home(0), Explore(1), Channels(2), Messages(3), Notifications(4), Media(5), Profile(6)
    // Mobile:  Home(0), Explore(1), Channels(2), Notifications(3), More(4)
    switch (desktopIndex) {
      case 0: return 0; // Home
      case 1: return 1; // Explore
      case 2: return 2; // Channels
      case 3: return 4; // Messages -> More
      case 4: return 3; // Notifications
      case 5: return 4; // Media -> More
      case 6: return 4; // Profile -> More
      default: return 0;
    }
  }

  Widget _buildBreadcrumbHeader(BuildContext context, int selectedIndex) {
    final currentItem = _desktopNavigationItems[selectedIndex];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'PlebsHub',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
          const SizedBox(width: 8),
          Icon(
            currentItem.selectedIcon,
            size: 20,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          const SizedBox(width: 8),
          Text(
            currentItem.label,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _onNavigationSelected(BuildContext context, WidgetRef ref, int index, bool isMobile) {
    if (isMobile && index == 4) {
      // "More" menu tapped on mobile - show popup
      _showMoreMenu(context, ref);
      return;
    }

    // Map mobile index to desktop index for state
    final desktopIndex = isMobile ? _getMobileToDesktopIndex(index) : index;

    // Update the selected index
    ref.read(navigationIndexProvider.notifier).state = desktopIndex;

    // Navigate to the corresponding route
    final items = isMobile ? _mobileNavigationItems : _desktopNavigationItems;
    final path = items[index].path;

    // Handle profile navigation with current user's pubkey
    if (path == '/profile') {
      final authState = ref.read(authProvider);
      if (authState is AuthStateAuthenticated) {
        context.go('/profile/${authState.keypair.publicKey}');
      } else {
        // If not authenticated, go to auth screen
        context.push('/auth');
      }
    } else {
      context.go(path);
    }
  }

  /// Maps mobile navigation index to desktop navigation index.
  int _getMobileToDesktopIndex(int mobileIndex) {
    // Mobile:  Home(0), Explore(1), Channels(2), Notifications(3), More(4)
    // Desktop: Home(0), Explore(1), Channels(2), Messages(3), Notifications(4), Media(5), Profile(6)
    switch (mobileIndex) {
      case 0: return 0; // Home
      case 1: return 1; // Explore
      case 2: return 2; // Channels
      case 3: return 4; // Notifications
      case 4: return 6; // More -> Profile (default)
      default: return 0;
    }
  }

  /// Shows the "More" popup menu on mobile.
  void _showMoreMenu(BuildContext context, WidgetRef ref) {
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        overlay.size.width - 150,
        overlay.size.height - 200,
        16,
        100,
      ),
      items: [
        PopupMenuItem<String>(
          value: '/profile',
          child: Row(
            children: [
              Icon(Icons.person_outlined, color: AppColors.textPrimary),
              const SizedBox(width: 12),
              Text('Profile', style: AppTypography.bodyLarge),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: '/media-library',
          child: Row(
            children: [
              Icon(Icons.photo_library_outlined, color: AppColors.textPrimary),
              const SizedBox(width: 12),
              Text('Media', style: AppTypography.bodyLarge),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: '/messages',
          child: Row(
            children: [
              Icon(Icons.mail_outlined, color: AppColors.textPrimary),
              const SizedBox(width: 12),
              Text('Messages', style: AppTypography.bodyLarge),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: '/settings/media',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, color: AppColors.textPrimary),
              const SizedBox(width: 12),
              Text('Settings', style: AppTypography.bodyLarge),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      if (value == '/profile') {
        final authState = ref.read(authProvider);
        if (authState is AuthStateAuthenticated) {
          ref.read(navigationIndexProvider.notifier).state = 6; // Profile index
          context.go('/profile/${authState.keypair.publicKey}');
        } else {
          context.push('/auth');
        }
      } else if (value == '/media-library') {
        ref.read(navigationIndexProvider.notifier).state = 5; // Media index
        context.go(value);
      } else {
        context.go(value);
      }
    });
  }
}

/// Helper to get the current navigation index from a route location.
/// Returns desktop navigation index.
int getNavigationIndexFromLocation(String location) {
  if (location == '/' || location.startsWith('/thread')) {
    return 0; // Home
  } else if (location.startsWith('/explore')) {
    return 1; // Explore
  } else if (location.startsWith('/channels')) {
    return 2; // Channels
  } else if (location.startsWith('/messages')) {
    return 3; // Messages
  } else if (location.startsWith('/notifications')) {
    return 4; // Notifications
  } else if (location.startsWith('/media-library')) {
    return 5; // Media
  } else if (location.startsWith('/profile')) {
    return 6; // Profile
  }
  return 0; // Default to Home
}
