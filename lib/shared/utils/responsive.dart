import 'package:flutter/material.dart';

/// Screen size breakpoints for responsive layout.
///
/// - [mobile]: Screens smaller than 600px
/// - [tablet]: Screens between 600px and 1200px
/// - [desktop]: Screens larger than 1200px
enum ScreenSize { mobile, tablet, desktop }

/// Responsive layout utilities for adapting UI to different screen sizes.
///
/// This class provides static methods to determine the current screen size
/// and adapt layouts accordingly. Use these utilities to create adaptive
/// layouts that work well on mobile, tablet, and desktop.
///
/// Example:
/// ```dart
/// if (Responsive.isMobile(context)) {
///   return MobileLayout();
/// } else if (Responsive.isTablet(context)) {
///   return TabletLayout();
/// } else {
///   return DesktopLayout();
/// }
/// ```
class Responsive {
  /// Private constructor to prevent instantiation.
  Responsive._();

  /// Breakpoint for mobile screens (below this width).
  static const double mobileBreakpoint = 600;

  /// Breakpoint for tablet screens (below this width, above mobile).
  static const double tabletBreakpoint = 1200;

  /// Maximum content width for constrained layouts (like Twitter).
  static const double maxContentWidth = 600;

  /// Width of the navigation rail on tablet/desktop.
  static const double navigationRailWidth = 72;

  /// Width of the expanded navigation drawer on desktop.
  static const double navigationDrawerWidth = 280;

  /// Default column width for multi-column layouts.
  static const double defaultColumnWidth = 400;

  /// Get the current screen size based on the device width.
  ///
  /// Uses [MediaQuery] to determine the screen width and returns
  /// the appropriate [ScreenSize] enum value.
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width < mobileBreakpoint) {
      return ScreenSize.mobile;
    } else if (width < tabletBreakpoint) {
      return ScreenSize.tablet;
    } else {
      return ScreenSize.desktop;
    }
  }

  /// Returns true if the current screen is mobile-sized (< 600px).
  static bool isMobile(BuildContext context) {
    return getScreenSize(context) == ScreenSize.mobile;
  }

  /// Returns true if the current screen is tablet-sized (600px - 1200px).
  static bool isTablet(BuildContext context) {
    return getScreenSize(context) == ScreenSize.tablet;
  }

  /// Returns true if the current screen is desktop-sized (> 1200px).
  static bool isDesktop(BuildContext context) {
    return getScreenSize(context) == ScreenSize.desktop;
  }

  /// Returns the recommended number of columns for the current screen size.
  ///
  /// - Mobile: 1 column
  /// - Tablet: 2 columns
  /// - Desktop: 3 columns (can show more with sufficient width)
  static int getColumnCount(BuildContext context) {
    final screenSize = getScreenSize(context);
    final width = MediaQuery.sizeOf(context).width;

    switch (screenSize) {
      case ScreenSize.mobile:
        return 1;
      case ScreenSize.tablet:
        return 2;
      case ScreenSize.desktop:
        // Calculate how many columns can fit based on available width
        // Account for navigation drawer width
        final availableWidth = width - navigationDrawerWidth;
        final columnCount = (availableWidth / defaultColumnWidth).floor();
        return columnCount.clamp(3, 5); // Between 3 and 5 columns
    }
  }

  /// Returns the available content width after accounting for navigation.
  ///
  /// On mobile, returns full width. On tablet/desktop, subtracts
  /// the navigation rail or drawer width.
  static double getContentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final screenSize = getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.mobile:
        return width;
      case ScreenSize.tablet:
        return width - navigationRailWidth;
      case ScreenSize.desktop:
        return width - navigationDrawerWidth;
    }
  }

  /// Calculate the width for each column in a multi-column layout.
  ///
  /// Takes into account the number of columns and any spacing between them.
  static double getColumnWidth(BuildContext context, {double spacing = 1}) {
    final contentWidth = getContentWidth(context);
    final columnCount = getColumnCount(context);
    final totalSpacing = spacing * (columnCount - 1);
    return (contentWidth - totalSpacing) / columnCount;
  }

  /// Build different widgets based on screen size.
  ///
  /// This is a convenience method that returns different widgets
  /// based on the current screen size. The [desktop] parameter
  /// falls back to [tablet] if not provided, and [tablet] falls
  /// back to [mobile] if not provided.
  static Widget builder({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    final screenSize = getScreenSize(context);

    switch (screenSize) {
      case ScreenSize.mobile:
        return mobile;
      case ScreenSize.tablet:
        return tablet ?? mobile;
      case ScreenSize.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
}

/// Extension on [BuildContext] for convenient responsive checks.
extension ResponsiveContext on BuildContext {
  /// Get the current screen size.
  ScreenSize get screenSize => Responsive.getScreenSize(this);

  /// Check if the current screen is mobile-sized.
  bool get isMobile => Responsive.isMobile(this);

  /// Check if the current screen is tablet-sized.
  bool get isTablet => Responsive.isTablet(this);

  /// Check if the current screen is desktop-sized.
  bool get isDesktop => Responsive.isDesktop(this);

  /// Get the recommended number of columns.
  int get columnCount => Responsive.getColumnCount(this);

  /// Get the available content width.
  double get contentWidth => Responsive.getContentWidth(this);
}
