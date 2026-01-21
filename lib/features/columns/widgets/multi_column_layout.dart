import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../services/key_service.dart';
import '../../../services/profile_service.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/smart_image.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../../profile/models/profile.dart';
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
class _AddColumnDialog extends ConsumerStatefulWidget {
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
  ConsumerState<_AddColumnDialog> createState() => _AddColumnDialogState();
}

class _AddColumnDialogState extends ConsumerState<_AddColumnDialog> {
  final _hashtagController = TextEditingController();
  final _userController = TextEditingController();
  final _keyService = KeyService();
  final _profileService = ProfileService.instance;

  ColumnType? _selectedType;
  bool _showHashtagInput = false;
  bool _showUserInput = false;

  // User selection state
  List<Profile> _followedUsers = [];
  bool _isLoadingFollowed = false;
  String? _userInputError;
  Profile? _selectedFollowedUser;

  @override
  void dispose() {
    _hashtagController.dispose();
    _userController.dispose();
    super.dispose();
  }

  /// Validate and resolve user input (npub or hex pubkey).
  String? _validateUserInput(String input) {
    if (input.isEmpty) return null;

    // Try npub format
    if (input.startsWith('npub1')) {
      try {
        return _keyService.npubToPublicKey(input);
      } catch (e) {
        return null;
      }
    }

    // Try hex format
    if (input.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(input)) {
      return input.toLowerCase();
    }

    return null;
  }

  /// Load followed users for selection.
  Future<void> _loadFollowedUsers() async {
    final authState = ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) return;

    setState(() {
      _isLoadingFollowed = true;
    });

    try {
      // Fetch followed pubkeys
      final followedPubkeys = await _profileService.fetchFollowing(
        authState.keypair.publicKey,
      );

      if (!mounted) return;

      if (followedPubkeys.isEmpty) {
        setState(() {
          _followedUsers = [];
          _isLoadingFollowed = false;
        });
        return;
      }

      // Fetch profiles for followed users (batch fetch)
      final profiles = await _profileService.fetchProfiles(followedPubkeys);

      if (!mounted) return;

      // Sort by name for easier browsing
      final sortedProfiles = profiles.values.toList()
        ..sort((a, b) => a.nameForDisplay.toLowerCase().compareTo(
              b.nameForDisplay.toLowerCase(),
            ));

      setState(() {
        _followedUsers = sortedProfiles;
        _isLoadingFollowed = false;
      });
    } catch (e) {
      debugPrint('Error loading followed users: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingFollowed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Column'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
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

              // User input section (shown when user type selected)
              if (_showUserInput) ...[
                const SizedBox(height: 16),
                _buildUserInputSection(),
              ],
            ],
          ),
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

  Widget _buildUserInputSection() {
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState is AuthStateAuthenticated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Manual npub/pubkey input
        TextField(
          controller: _userController,
          decoration: InputDecoration(
            labelText: 'User npub or pubkey',
            hintText: 'npub1... or hex pubkey',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            errorText: _userInputError,
            suffixIcon: _userController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() {
                        _userController.clear();
                        _userInputError = null;
                        _selectedFollowedUser = null;
                      });
                    },
                  )
                : null,
          ),
          autofocus: true,
          onChanged: (value) {
            setState(() {
              _selectedFollowedUser = null;
              if (value.trim().isNotEmpty) {
                final resolved = _validateUserInput(value.trim());
                _userInputError = resolved == null
                    ? 'Invalid npub or pubkey format'
                    : null;
              } else {
                _userInputError = null;
              }
            });
          },
          onSubmitted: (_) {
            if (_canSubmit()) _submit();
          },
        ),

        // Followed users section (only for authenticated users)
        if (isAuthenticated) ...[
          const SizedBox(height: 16),
          _buildFollowedUsersSection(),
        ],
      ],
    );
  }

  Widget _buildFollowedUsersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header
        Row(
          children: [
            Expanded(
              child: Text(
                'Or select from followed users',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (_followedUsers.isEmpty && !_isLoadingFollowed)
              TextButton.icon(
                onPressed: _loadFollowedUsers,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Load'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Loading indicator
        if (_isLoadingFollowed)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        // Followed users list (scrollable, max height)
        else if (_followedUsers.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _followedUsers.length,
              itemBuilder: (context, index) {
                final profile = _followedUsers[index];
                final isSelected = _selectedFollowedUser?.pubkey == profile.pubkey;

                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                  leading: ClipOval(
                    child: profile.picture != null && profile.picture!.isNotEmpty
                        ? SmartImage(
                            imageUrl: profile.picture!,
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            placeholder: (ctx, url) => _buildMiniAvatarPlaceholder(profile),
                            errorWidget: (ctx, url, err) => _buildMiniAvatarPlaceholder(profile),
                          )
                        : _buildMiniAvatarPlaceholder(profile),
                  ),
                  title: Text(
                    profile.nameForDisplay,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : null,
                      color: isSelected ? AppColors.primary : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: profile.nip05 != null
                      ? Text(
                          profile.nip05!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedFollowedUser = profile;
                      _userController.text = profile.pubkey;
                      _userInputError = null;
                    });
                  },
                );
              },
            ),
          )
        // Empty state
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'Tap "Load" to see followed users',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMiniAvatarPlaceholder(Profile profile) {
    return Container(
      width: 32,
      height: 32,
      color: AppColors.surfaceVariant,
      child: Center(
        child: Text(
          profile.nameForDisplay.isNotEmpty
              ? profile.nameForDisplay[0].toUpperCase()
              : '?',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
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
      _userInputError = null;
      _selectedFollowedUser = null;
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
      final input = _userController.text.trim();
      if (input.isEmpty) return false;
      return _validateUserInput(input) != null;
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
      final input = _userController.text.trim();
      userPubkey = _validateUserInput(input);
      if (userPubkey == null) {
        setState(() {
          _userInputError = 'Invalid npub or pubkey format';
        });
        return;
      }
    }

    widget.onColumnTypeSelected(
      _selectedType!,
      hashtag: hashtag,
      userPubkey: userPubkey,
    );

    Navigator.of(context).pop();
  }
}
