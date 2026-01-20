import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../shared/utils/responsive.dart';
import '../models/column_config.dart';
import '../providers/columns_provider.dart';
import 'column_widget.dart';

/// A multi-column layout for TweetDeck-style desktop views.
///
/// This widget displays multiple content columns side by side, each showing
/// different feeds or content types. Features include:
/// - Add/remove columns dynamically
/// - Reorder columns via drag-and-drop (in edit mode)
/// - Responsive column count based on screen width
///
/// Structure:
/// ```
/// ┌─────────────────────────────────────────────────────────────┐
/// │ [+] Add Column                            [Edit] [Presets]  │ <- Toolbar
/// ├─────────────────────────────────────────────────────────────┤
/// │ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
/// │ │  Home    │ │ Explore  │ │ #bitcoin │ │ Notifs   │        │ <- Columns
/// │ │          │ │          │ │          │ │          │        │
/// │ │  ......  │ │  ......  │ │  ......  │ │  ......  │        │
/// │ │  ......  │ │  ......  │ │  ......  │ │  ......  │        │
/// │ └──────────┘ └──────────┘ └──────────┘ └──────────┘        │
/// └─────────────────────────────────────────────────────────────┘
/// ```
class MultiColumnLayout extends ConsumerWidget {
  const MultiColumnLayout({super.key});

  /// Minimum column width in pixels.
  static const double _minColumnWidth = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columnsState = ref.watch(columnsProvider);
    final isEditMode = ref.watch(isColumnsEditModeProvider);

    // Calculate maximum columns based on screen width
    final screenWidth = MediaQuery.sizeOf(context).width;
    final availableWidth = screenWidth - Responsive.navigationDrawerWidth;
    final maxColumns = (availableWidth / _minColumnWidth).floor().clamp(1, 10);

    return Column(
      children: [
        // Toolbar
        _ColumnToolbar(
          columnCount: columnsState.columns.length,
          maxColumns: maxColumns,
          isEditMode: isEditMode,
        ),

        // Columns area
        Expanded(
          child: columnsState.columns.isEmpty
              ? _buildEmptyState(context, ref)
              : _buildColumnsArea(context, ref, columnsState, isEditMode),
        ),
      ],
    );
  }

  /// Build the empty state when no columns are configured.
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.view_column_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No columns configured',
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Add a column to get started',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddColumnDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add Column'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the columns area with horizontal scrolling.
  Widget _buildColumnsArea(
    BuildContext context,
    WidgetRef ref,
    ColumnsState columnsState,
    bool isEditMode,
  ) {
    if (isEditMode) {
      return _buildReorderableColumns(context, ref, columnsState);
    }

    return _buildScrollableColumns(context, ref, columnsState);
  }

  /// Build scrollable columns (non-edit mode).
  Widget _buildScrollableColumns(
    BuildContext context,
    WidgetRef ref,
    ColumnsState columnsState,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < columnsState.columns.length; i++) ...[
            if (i > 0)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.border,
              ),
            SizedBox(
              width: columnsState.columns[i].width,
              child: ColumnWidget(
                config: columnsState.columns[i],
                onRemove: () {
                  ref.read(columnsProvider.notifier).removeColumn(
                        columnsState.columns[i].id,
                      );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build reorderable columns (edit mode).
  Widget _buildReorderableColumns(
    BuildContext context,
    WidgetRef ref,
    ColumnsState columnsState,
  ) {
    return ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: columnsState.columns.length,
      onReorder: (oldIndex, newIndex) {
        ref.read(columnsProvider.notifier).reorderColumn(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final elevation = Tween<double>(begin: 0, end: 8).evaluate(animation);
            return Material(
              elevation: elevation,
              color: Colors.transparent,
              shadowColor: Colors.black38,
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final column = columnsState.columns[index];
        return Container(
          key: ValueKey(column.id),
          width: column.width,
          margin: EdgeInsets.only(
            right: index < columnsState.columns.length - 1 ? 1 : 0,
          ),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: AppColors.border,
                width: 1,
              ),
            ),
          ),
          child: ColumnWidget(
            config: column,
            onRemove: () {
              ref.read(columnsProvider.notifier).removeColumn(column.id);
            },
          ),
        );
      },
    );
  }

  /// Show the add column dialog.
  void _showAddColumnDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => _AddColumnDialog(
        onColumnTypeSelected: (type, {hashtag, userPubkey, channelId}) {
          ref.read(columnsProvider.notifier).addColumn(
                type,
                hashtag: hashtag,
                userPubkey: userPubkey,
                channelId: channelId,
              );
        },
      ),
    );
  }
}

/// Toolbar for managing columns.
class _ColumnToolbar extends ConsumerWidget {
  const _ColumnToolbar({
    required this.columnCount,
    required this.maxColumns,
    required this.isEditMode,
  });

  final int columnCount;
  final int maxColumns;
  final bool isEditMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Add Column button
          OutlinedButton.icon(
            onPressed: columnCount < maxColumns
                ? () => _showAddColumnDialog(context, ref)
                : null,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Column'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),

          const Spacer(),

          // Column count indicator
          Text(
            '$columnCount / $maxColumns columns',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(width: 16),

          // Edit mode toggle
          IconButton(
            onPressed: () {
              ref.read(columnsProvider.notifier).toggleEditMode();
            },
            icon: Icon(
              isEditMode ? Icons.check : Icons.edit_outlined,
              size: 20,
            ),
            tooltip: isEditMode ? 'Done' : 'Edit columns',
            style: IconButton.styleFrom(
              backgroundColor: isEditMode
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Colors.transparent,
              foregroundColor: isEditMode ? AppColors.primary : AppColors.textPrimary,
            ),
          ),

          // Presets button (placeholder for future feature)
          IconButton(
            onPressed: () {
              _showPresetsMenu(context, ref);
            },
            icon: const Icon(Icons.dashboard_outlined, size: 20),
            tooltip: 'Column presets',
            style: IconButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddColumnDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => _AddColumnDialog(
        onColumnTypeSelected: (type, {hashtag, userPubkey, channelId}) {
          ref.read(columnsProvider.notifier).addColumn(
                type,
                hashtag: hashtag,
                userPubkey: userPubkey,
                channelId: channelId,
              );
        },
      ),
    );
  }

  void _showPresetsMenu(BuildContext context, WidgetRef ref) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.sizeOf(context).width - 200,
        56,
        16,
        0,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'default',
          child: const ListTile(
            leading: Icon(Icons.home),
            title: Text('Default'),
            subtitle: Text('Home + Explore + Notifs'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem<String>(
          value: 'bitcoin',
          child: const ListTile(
            leading: Icon(Icons.currency_bitcoin),
            title: Text('Bitcoin'),
            subtitle: Text('Home + #bitcoin + #nostr'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem<String>(
          value: 'social',
          child: const ListTile(
            leading: Icon(Icons.chat),
            title: Text('Social'),
            subtitle: Text('Home + Notifs + Messages'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'default':
          ref.read(columnsProvider.notifier).setDefaultColumns();
        case 'bitcoin':
          _applyBitcoinPreset(ref);
        case 'social':
          _applySocialPreset(ref);
      }
    });
  }

  void _applyBitcoinPreset(WidgetRef ref) {
    final notifier = ref.read(columnsProvider.notifier);
    // Reset first, then add custom columns
    notifier.setDefaultColumns();
    // Remove notifications and add hashtag columns
    final state = ref.read(columnsProvider);
    for (final col in state.columns) {
      if (col.type == ColumnType.notifications) {
        notifier.removeColumn(col.id);
      }
    }
    notifier.addColumn(ColumnType.hashtag, hashtag: 'bitcoin');
    notifier.addColumn(ColumnType.hashtag, hashtag: 'nostr');
  }

  void _applySocialPreset(WidgetRef ref) {
    final notifier = ref.read(columnsProvider.notifier);
    // Reset to defaults - already has Home, Explore, Notifications
    notifier.setDefaultColumns();
    // Add Messages
    notifier.addColumn(ColumnType.messages);
  }
}

/// Dialog for adding a new column.
class _AddColumnDialog extends StatefulWidget {
  const _AddColumnDialog({
    required this.onColumnTypeSelected,
  });

  final void Function(
    ColumnType type, {
    String? hashtag,
    String? userPubkey,
    String? channelId,
  }) onColumnTypeSelected;

  @override
  State<_AddColumnDialog> createState() => _AddColumnDialogState();
}

class _AddColumnDialogState extends State<_AddColumnDialog> {
  final _hashtagController = TextEditingController();
  final _userController = TextEditingController();
  ColumnType? _selectedType;
  bool _showHashtagInput = false;
  bool _showUserInput = false;

  @override
  void dispose() {
    _hashtagController.dispose();
    _userController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Column'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Column type list
            ..._buildColumnTypeOptions(),

            // Hashtag input (shown when hashtag type selected)
            if (_showHashtagInput) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _hashtagController,
                decoration: InputDecoration(
                  labelText: 'Hashtag',
                  hintText: 'bitcoin',
                  prefixText: '#',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                ),
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
            ],

            // User input (shown when user type selected)
            if (_showUserInput) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _userController,
                decoration: InputDecoration(
                  labelText: 'User npub',
                  hintText: 'npub1...',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                ),
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit() ? _submit : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }

  List<Widget> _buildColumnTypeOptions() {
    final types = [
      (ColumnType.home, Icons.home_outlined, 'Home', 'Your home timeline'),
      (ColumnType.explore, Icons.explore_outlined, 'Explore', 'Global feed'),
      (ColumnType.hashtag, Icons.tag, 'Hashtag', 'Posts with a specific tag'),
      (ColumnType.user, Icons.person_outlined, 'User', 'Posts from a specific user'),
      (ColumnType.notifications, Icons.notifications_outlined, 'Notifications', 'Your notifications'),
      (ColumnType.messages, Icons.mail_outlined, 'Messages', 'Direct messages'),
      (ColumnType.channel, Icons.forum_outlined, 'Channel', 'IRC-style chat channel'),
    ];

    return types.map((type) {
      final (columnType, icon, title, subtitle) = type;
      final isSelected = _selectedType == columnType;

      return ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primary : null,
            fontWeight: isSelected ? FontWeight.bold : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onTap: () => _selectType(columnType),
      );
    }).toList();
  }

  void _selectType(ColumnType type) {
    setState(() {
      _selectedType = type;
      _showHashtagInput = type == ColumnType.hashtag;
      _showUserInput = type == ColumnType.user;
    });

    // For types that don't need additional input, submit immediately
    if (type != ColumnType.hashtag &&
        type != ColumnType.user &&
        type != ColumnType.channel) {
      _submit();
    }
  }

  bool _canSubmit() {
    if (_selectedType == null) return false;

    if (_selectedType == ColumnType.hashtag) {
      return _hashtagController.text.trim().isNotEmpty;
    }

    if (_selectedType == ColumnType.user) {
      return _userController.text.trim().isNotEmpty;
    }

    return true;
  }

  void _submit() {
    if (_selectedType == null) return;

    String? hashtag;
    String? userPubkey;

    if (_selectedType == ColumnType.hashtag) {
      hashtag = _hashtagController.text.trim();
      if (hashtag.startsWith('#')) {
        hashtag = hashtag.substring(1);
      }
    }

    if (_selectedType == ColumnType.user) {
      userPubkey = _userController.text.trim();
    }

    widget.onColumnTypeSelected(
      _selectedType!,
      hashtag: hashtag,
      userPubkey: userPubkey,
    );

    Navigator.of(context).pop();
  }
}
