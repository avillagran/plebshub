import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// Represents a single column in the multi-column layout.
class ColumnConfig {
  /// Creates a column configuration.
  const ColumnConfig({
    required this.id,
    required this.title,
    required this.builder,
    this.minWidth = 350,
    this.maxWidth = 600,
    this.flex = 1,
  });

  /// Unique identifier for this column.
  final String id;

  /// Title displayed in the column header.
  final String title;

  /// Builder function that creates the column content.
  final WidgetBuilder builder;

  /// Minimum width for this column.
  final double minWidth;

  /// Maximum width for this column (like Twitter's 600px constraint).
  final double maxWidth;

  /// Flex factor for distributing available space.
  final int flex;
}

/// A multi-column layout for desktop views (TweetDeck-style).
///
/// On desktop, displays multiple columns side by side. Each column
/// can contain different content (Feed, Notifications, Profile, etc.).
/// Columns are configurable with minimum and maximum widths.
///
/// Example:
/// ```dart
/// ColumnLayout(
///   columns: [
///     ColumnConfig(
///       id: 'feed',
///       title: 'Home',
///       builder: (context) => FeedScreen(),
///     ),
///     ColumnConfig(
///       id: 'notifications',
///       title: 'Notifications',
///       builder: (context) => NotificationsScreen(),
///     ),
///   ],
/// )
/// ```
class ColumnLayout extends StatelessWidget {
  /// Creates a column layout.
  const ColumnLayout({
    super.key,
    required this.columns,
    this.showHeaders = true,
    this.dividerWidth = 1,
  });

  /// The columns to display.
  final List<ColumnConfig> columns;

  /// Whether to show column headers with titles.
  final bool showHeaders;

  /// Width of the divider between columns.
  final double dividerWidth;

  @override
  Widget build(BuildContext context) {
    if (columns.isEmpty) {
      return const SizedBox.shrink();
    }

    // On mobile/tablet, show only the first column
    if (!Responsive.isDesktop(context)) {
      return columns.first.builder(context);
    }

    // On desktop, show multiple columns
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildColumns(context),
    );
  }

  List<Widget> _buildColumns(BuildContext context) {
    final widgets = <Widget>[];

    for (var i = 0; i < columns.length; i++) {
      final column = columns[i];

      // Add divider between columns (not before first)
      if (i > 0) {
        widgets.add(
          VerticalDivider(
            width: dividerWidth,
            thickness: dividerWidth,
          ),
        );
      }

      // Add the column
      widgets.add(
        Flexible(
          flex: column.flex,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: column.minWidth,
              maxWidth: column.maxWidth,
            ),
            child: _ColumnContainer(
              config: column,
              showHeader: showHeaders,
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}

/// Container for a single column with optional header.
class _ColumnContainer extends StatelessWidget {
  const _ColumnContainer({
    required this.config,
    required this.showHeader,
  });

  final ColumnConfig config;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!showHeader) {
      return config.builder(context);
    }

    return Column(
      children: [
        // Column header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Text(
            config.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Column content
        Expanded(
          child: config.builder(context),
        ),
      ],
    );
  }
}

/// A wrapper widget that can optionally constrain content width on larger screens.
///
/// By default, content fills the entire available width. Set [useMaxWidth]
/// to true to center the content and apply a maximum width constraint
/// (similar to Twitter's feed on desktop).
class ResponsiveContent extends StatelessWidget {
  /// Creates a responsive content wrapper.
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = Responsive.maxContentWidth,
    this.padding = EdgeInsets.zero,
    this.useMaxWidth = false,
  });

  /// The content to display.
  final Widget child;

  /// Maximum width for the content (default 600px like Twitter).
  /// Only applied when [useMaxWidth] is true.
  final double maxWidth;

  /// Optional padding around the content.
  final EdgeInsets padding;

  /// Whether to constrain content to [maxWidth].
  /// When false (default), content fills available width.
  final bool useMaxWidth;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (useMaxWidth) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// A widget that shows different content based on screen size.
///
/// This is useful for showing different layouts or components
/// based on whether the user is on mobile, tablet, or desktop.
class ResponsiveBuilder extends StatelessWidget {
  /// Creates a responsive builder.
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  /// Widget to show on mobile screens.
  final Widget mobile;

  /// Widget to show on tablet screens (falls back to mobile if null).
  final Widget? tablet;

  /// Widget to show on desktop screens (falls back to tablet/mobile if null).
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return Responsive.builder(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
}
