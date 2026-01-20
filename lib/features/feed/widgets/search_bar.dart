import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../providers/search_provider.dart';

/// A search bar widget for the explore screen.
///
/// Features:
/// - Text input with search icon
/// - Filter chips for search type (All, Posts, Users, Hashtags)
/// - Clear button when there's text
/// - Submit on enter
class ExploreSearchBar extends ConsumerStatefulWidget {
  const ExploreSearchBar({
    super.key,
    this.onSearchSubmitted,
    this.autofocus = false,
  });

  /// Callback when search is submitted.
  final VoidCallback? onSearchSubmitted;

  /// Whether to autofocus the search field.
  final bool autofocus;

  @override
  ConsumerState<ExploreSearchBar> createState() => _ExploreSearchBarState();
}

class _ExploreSearchBarState extends ConsumerState<ExploreSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSubmitted(String query) {
    if (query.trim().isEmpty) {
      ref.read(searchProvider.notifier).clearSearch();
      return;
    }

    ref.read(searchProvider.notifier).search(query);
    widget.onSearchSubmitted?.call();
  }

  void _onClear() {
    _controller.clear();
    ref.read(searchProvider.notifier).clearSearch();
    _focusNode.requestFocus();
  }

  void _onFilterSelected(SearchFilterType filterType) {
    ref.read(searchProvider.notifier).setFilterType(filterType);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final currentFilterType = ref.read(searchProvider.notifier).currentFilterType;

    // Update controller text if search is cleared externally
    if (searchState is SearchStateInitial && _controller.text.isNotEmpty) {
      // Don't update if we're typing
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search input field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            decoration: InputDecoration(
              hintText: 'Search posts, users, or #hashtags',
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: AppColors.textSecondary,
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: _onClear,
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            style: AppTypography.bodyMedium,
            textInputAction: TextInputAction.search,
            onSubmitted: _onSubmitted,
            onChanged: (value) {
              setState(() {}); // Rebuild to show/hide clear button
            },
          ),
        ),

        // Filter chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _FilterChip(
                label: 'All',
                isSelected: currentFilterType == SearchFilterType.all,
                onSelected: () => _onFilterSelected(SearchFilterType.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Posts',
                isSelected: currentFilterType == SearchFilterType.posts,
                onSelected: () => _onFilterSelected(SearchFilterType.posts),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Users',
                isSelected: currentFilterType == SearchFilterType.users,
                onSelected: () => _onFilterSelected(SearchFilterType.users),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Hashtags',
                isSelected: currentFilterType == SearchFilterType.hashtags,
                onSelected: () => _onFilterSelected(SearchFilterType.hashtags),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A filter chip for selecting search type.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: isSelected ? Colors.white : AppColors.textSecondary,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      side: BorderSide.none,
    );
  }
}
