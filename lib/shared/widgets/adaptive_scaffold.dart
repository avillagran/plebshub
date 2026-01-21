import 'package:flutter/material.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../utils/responsive.dart';

/// Navigation destination item for adaptive navigation.
class NavigationItem {
  /// Creates a navigation item.
  const NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.path,
  });

  /// The icon when not selected.
  final IconData icon;

  /// The icon when selected.
  final IconData selectedIcon;

  /// The label for the navigation item.
  final String label;

  /// The route path for navigation.
  final String path;
}

/// Default navigation items for the app.
const List<NavigationItem> defaultNavigationItems = [
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
    icon: Icons.mail_outlined,
    selectedIcon: Icons.mail,
    label: 'Messages',
    path: '/messages',
  ),
  NavigationItem(
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
    label: 'Notifs',
    path: '/notifications',
  ),
  NavigationItem(
    icon: Icons.person_outlined,
    selectedIcon: Icons.person,
    label: 'Profile',
    path: '/profile',
  ),
];

/// An adaptive scaffold that changes layout based on screen size.
///
/// On mobile: Uses a standard Scaffold with BottomNavigationBar.
/// On tablet: Uses a Scaffold with NavigationRail (collapsible).
/// On desktop: Uses a Scaffold with a permanent navigation drawer (collapsible).
///
/// This widget handles navigation state and provides smooth transitions
/// when the window is resized between breakpoints.
class AdaptiveScaffold extends StatefulWidget {
  /// Creates an adaptive scaffold.
  const AdaptiveScaffold({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.navigationItems = defaultNavigationItems,
    this.floatingActionButton,
    this.appBar,
    this.onCompose,
    this.showCompose = false,
  });

  /// The main content of the scaffold.
  final Widget body;

  /// The currently selected navigation index.
  final int selectedIndex;

  /// Callback when a navigation destination is selected.
  final ValueChanged<int> onDestinationSelected;

  /// The navigation items to display.
  final List<NavigationItem> navigationItems;

  /// Optional floating action button.
  final Widget? floatingActionButton;

  /// Optional app bar (used only on mobile).
  final PreferredSizeWidget? appBar;

  /// Callback when compose button is pressed.
  final VoidCallback? onCompose;

  /// Whether to show the compose button (only for authenticated users).
  final bool showCompose;

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  /// Whether the sidebar is expanded (on tablet/desktop).
  bool _isSidebarExpanded = true;

  /// Animation duration for sidebar expansion.
  static const _animationDuration = Duration(milliseconds: 300);

  /// Animation curve for sidebar expansion.
  static const _animationCurve = Curves.easeInOut;

  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = Responsive.getScreenSize(context);

    return switch (screenSize) {
      ScreenSize.mobile => _buildMobileLayout(context),
      ScreenSize.tablet => _buildTabletLayout(context),
      ScreenSize.desktop => _buildDesktopLayout(context),
    };
  }

  /// Build the mobile layout with bottom navigation bar.
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      key: const ValueKey('mobile_scaffold'),
      appBar: widget.appBar,
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: widget.onDestinationSelected,
        destinations: widget.navigationItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  /// Build the tablet layout with animated navigation rail.
  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      key: const ValueKey('tablet_scaffold'),
      body: Row(
        children: [
          // Animated sidebar
          AnimatedContainer(
            duration: _animationDuration,
            curve: _animationCurve,
            width: _isSidebarExpanded
                ? Responsive.navigationDrawerWidth
                : Responsive.navigationRailWidth,
            child: _buildAnimatedSidebar(context, isDesktop: false),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: widget.body),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  /// Build the desktop layout with animated navigation drawer.
  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      key: const ValueKey('desktop_scaffold'),
      body: Row(
        children: [
          // Animated sidebar
          AnimatedContainer(
            duration: _animationDuration,
            curve: _animationCurve,
            width: _isSidebarExpanded
                ? Responsive.navigationDrawerWidth
                : Responsive.navigationRailWidth,
            child: _buildAnimatedSidebar(context, isDesktop: true),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: widget.body),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  /// Build the animated sidebar that morphs between rail and drawer.
  Widget _buildAnimatedSidebar(BuildContext context, {required bool isDesktop}) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo/Brand header with toggle button
            Padding(
              padding: EdgeInsets.all(_isSidebarExpanded ? 16 : 12),
              child: Row(
                children: [
                  // Toggle button
                  IconButton(
                    icon: AnimatedRotation(
                      turns: _isSidebarExpanded ? 0 : 0.5,
                      duration: _animationDuration,
                      child: const Icon(Icons.menu),
                    ),
                    onPressed: _toggleSidebar,
                    tooltip: _isSidebarExpanded ? 'Collapse' : 'Expand',
                  ),
                  // Logo and title (only when expanded)
                  if (_isSidebarExpanded) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.bolt,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: _isSidebarExpanded ? 1.0 : 0.0,
                        duration: _animationDuration,
                        child: Text(
                          'PlebsHub',
                          style: AppTypography.titleLarge.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Navigation items
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: _isSidebarExpanded ? 12 : 8,
                ),
                itemCount: widget.navigationItems.length,
                itemBuilder: (context, index) {
                  final item = widget.navigationItems[index];
                  final isSelected = index == widget.selectedIndex;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _AnimatedNavigationItem(
                      icon: isSelected ? item.selectedIcon : item.icon,
                      label: item.label,
                      isSelected: isSelected,
                      isExpanded: _isSidebarExpanded,
                      onTap: () => widget.onDestinationSelected(index),
                      animationDuration: _animationDuration,
                    ),
                  );
                },
              ),
            ),
            // Compose button at bottom (only for authenticated users)
            if (widget.showCompose)
              Padding(
                padding: EdgeInsets.all(_isSidebarExpanded ? 16 : 12),
                child: _isSidebarExpanded
                    ? SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: widget.onCompose,
                          icon: const Icon(Icons.edit),
                          label: const Text('Compose'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      )
                    : Center(
                        child: FloatingActionButton.small(
                          onPressed: widget.onCompose,
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.edit),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// An animated navigation item that adapts between expanded and collapsed states.
class _AnimatedNavigationItem extends StatelessWidget {
  const _AnimatedNavigationItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
    required this.animationDuration,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: AnimatedContainer(
          duration: animationDuration,
          padding: EdgeInsets.symmetric(
            horizontal: isExpanded ? 16 : 12,
            vertical: 12,
          ),
          child: Row(
            mainAxisAlignment: isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 26,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              if (isExpanded) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedOpacity(
                    opacity: isExpanded ? 1.0 : 0.0,
                    duration: animationDuration,
                    child: Text(
                      label,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
