import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../shared/shared.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../models/channel.dart';
import '../providers/channel_provider.dart';
import '../widgets/create_channel_dialog.dart';

/// Screen displaying a list of available channels.
///
/// Features:
/// - List of discovered channels
/// - Search/filter functionality
/// - Create channel button (FAB)
/// - Pull to refresh
class ChannelsListScreen extends ConsumerStatefulWidget {
  const ChannelsListScreen({super.key});

  @override
  ConsumerState<ChannelsListScreen> createState() => _ChannelsListScreenState();
}

class _ChannelsListScreenState extends ConsumerState<ChannelsListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    // Load channels on initialization
    Future.microtask(() {
      ref.read(channelsListProvider.notifier).loadChannels();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Channel> _filterChannels(List<Channel> channels) {
    if (_searchQuery.isEmpty) return channels;

    final query = _searchQuery.toLowerCase();
    return channels.where((channel) {
      return channel.name.toLowerCase().contains(query) ||
          (channel.about?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _handleRefresh() async {
    await ref.read(channelsListProvider.notifier).refresh();
  }

  void _openCreateChannelDialog() async {
    final authState = ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to create a channel'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.push('/auth');
      return;
    }

    final channelId = await CreateChannelDialog.show(context);
    if (channelId != null && mounted) {
      // Navigate to the new channel
      context.push('/channels/$channelId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelsState = ref.watch(channelsListProvider);
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState is AuthStateAuthenticated;

    // Content fills entire available width
    return ResponsiveContent(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Channels'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(channelsListProvider.notifier).loadChannels(),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search channels...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // Channel list
            Expanded(
              child: _buildBody(channelsState),
            ),
          ],
        ),
        floatingActionButton: isAuthenticated
            ? FloatingActionButton.extended(
                onPressed: _openCreateChannelDialog,
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              )
            : null,
      ),
    );
  }

  Widget _buildBody(ChannelsListState state) {
    return switch (state) {
      ChannelsListStateInitial() => const Center(
          child: Text('Pull to load channels'),
        ),
      ChannelsListStateLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
      ChannelsListStateError(:final message) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading channels',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message,
                  style: AppTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(channelsListProvider.notifier).loadChannels();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ChannelsListStateLoaded(:final channels, :final isRefreshing) =>
        _buildChannelsList(channels, isRefreshing),
    };
  }

  Widget _buildChannelsList(List<Channel> channels, bool isRefreshing) {
    final filteredChannels = _filterChannels(channels);

    if (filteredChannels.isEmpty) {
      return RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.tag,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? 'No channels found'
                          : 'No channels match "$_searchQuery"',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _searchQuery.isEmpty
                          ? 'Be the first to create one!'
                          : 'Try a different search',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 80), // Space for FAB
        itemCount: filteredChannels.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: AppColors.border.withValues(alpha: 0.3),
        ),
        itemBuilder: (context, index) {
          final channel = filteredChannels[index];
          return _ChannelListTile(
            channel: channel,
            onTap: () => context.push('/channels/${channel.id}'),
          );
        },
      ),
    );
  }
}

/// A list tile for displaying a channel.
class _ChannelListTile extends StatelessWidget {
  const _ChannelListTile({
    required this.channel,
    required this.onTap,
  });

  final Channel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Channel icon/picture
              _buildChannelIcon(),
              const SizedBox(width: 12),

              // Channel info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Channel name - single line on mobile
                    Row(
                      children: [
                        Icon(
                          Icons.tag,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            channel.name,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Description - single line on mobile, two lines on larger screens
                    if (channel.about != null && channel.about!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        channel.about!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: isMobile ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Created date
                    const SizedBox(height: 4),
                    Text(
                      'Created ${_formatDate(channel.createdAt)}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow indicator
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelIcon() {
    if (channel.picture != null && channel.picture!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SmartImage(
          imageUrl: channel.picture!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildIconPlaceholder(),
          errorWidget: (context, url, error) => _buildIconPlaceholder(),
        ),
      );
    }
    return _buildIconPlaceholder();
  }

  Widget _buildIconPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          channel.name.isNotEmpty ? channel.name[0].toUpperCase() : '#',
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays < 1) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      final weeks = diff.inDays ~/ 7;
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (diff.inDays < 365) {
      final months = diff.inDays ~/ 30;
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
