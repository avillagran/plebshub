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

  /// Navigation items mapping to routes.
  static const List<NavigationItem> _navigationItems = [
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
      icon: Icons.person_outlined,
      selectedIcon: Icons.person,
      label: 'Profile',
      path: '/profile',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationIndexProvider);
    final authState = ref.watch(authProvider);

    // Determine FAB visibility based on auth state
    final showFab = authState is AuthStateAuthenticated;

    return AdaptiveScaffold(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => _onNavigationSelected(context, ref, index),
      navigationItems: _navigationItems,
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
  Widget _buildBreadcrumbHeader(BuildContext context, int selectedIndex) {
    final currentItem = _navigationItems[selectedIndex];

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

  void _onNavigationSelected(BuildContext context, WidgetRef ref, int index) {
    // Update the selected index
    ref.read(navigationIndexProvider.notifier).state = index;

    // Navigate to the corresponding route
    final path = _navigationItems[index].path;

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
}

/// Helper to get the current navigation index from a route location.
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
  } else if (location.startsWith('/profile')) {
    return 5; // Profile
  }
  return 0; // Default to Home
}
