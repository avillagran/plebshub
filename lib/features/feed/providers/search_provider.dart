import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndk/ndk.dart';

import '../../../services/ndk_service.dart';
import '../../profile/models/profile.dart';
import '../models/post.dart';

/// Search filter type enum.
enum SearchFilterType {
  all,
  posts,
  users,
  hashtags,
}

/// Provider for the SearchNotifier.
///
/// This provider manages search state and provides methods for:
/// - Searching posts by content
/// - Searching by hashtag
/// - Searching users by name/nip05
///
/// Example:
/// ```dart
/// // In a widget
/// final searchState = ref.watch(searchProvider);
///
/// // Search posts
/// ref.read(searchProvider.notifier).searchPosts('bitcoin');
///
/// // Search by hashtag
/// ref.read(searchProvider.notifier).searchByHashtag('nostr');
///
/// // Search users
/// ref.read(searchProvider.notifier).searchUsers('satoshi');
///
/// // Clear search
/// ref.read(searchProvider.notifier).clearSearch();
/// ```
final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier();
});

/// State for search.
@immutable
sealed class SearchState {
  const SearchState();
}

/// Initial state - no search performed
class SearchStateInitial extends SearchState {
  const SearchStateInitial();
}

/// Loading state - performing search
class SearchStateLoading extends SearchState {
  const SearchStateLoading({required this.query, required this.filterType});

  final String query;
  final SearchFilterType filterType;
}

/// Loaded state - search results available
class SearchStateLoaded extends SearchState {
  const SearchStateLoaded({
    required this.query,
    required this.filterType,
    this.posts = const [],
    this.users = const [],
    this.hasMore = false,
  });

  final String query;
  final SearchFilterType filterType;
  final List<Post> posts;
  final List<Profile> users;
  final bool hasMore;

  /// Create a copy with updated fields.
  SearchStateLoaded copyWith({
    String? query,
    SearchFilterType? filterType,
    List<Post>? posts,
    List<Profile>? users,
    bool? hasMore,
  }) {
    return SearchStateLoaded(
      query: query ?? this.query,
      filterType: filterType ?? this.filterType,
      posts: posts ?? this.posts,
      users: users ?? this.users,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Error state - search failed
class SearchStateError extends SearchState {
  const SearchStateError({required this.message, required this.query});

  final String message;
  final String query;
}

/// Configuration for search.
class SearchConfig {
  /// Maximum number of results to return per search.
  static const int maxResults = 50;

  /// Time window for post search (7 days).
  static const int searchTimeWindowSeconds = 7 * 24 * 60 * 60;
}

/// Notifier for managing search state.
class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier() : super(const SearchStateInitial());

  final _ndkService = NdkService.instance;

  /// Current search query.
  String _currentQuery = '';

  /// Current filter type.
  SearchFilterType _currentFilterType = SearchFilterType.all;

  /// Get the current query.
  String get currentQuery => _currentQuery;

  /// Get the current filter type.
  SearchFilterType get currentFilterType => _currentFilterType;

  /// Search posts by content.
  ///
  /// Note: Nostr doesn't support full-text search natively.
  /// This fetches recent posts and filters locally.
  /// For better search, consider using a search-enabled relay or NIP-50.
  Future<void> searchPosts(String query) async {
    if (query.trim().isEmpty) {
      state = const SearchStateInitial();
      return;
    }

    _currentQuery = query;
    _currentFilterType = SearchFilterType.posts;

    state = SearchStateLoading(
      query: query,
      filterType: SearchFilterType.posts,
    );

    try {
      // debugPrint('Searching posts for: $query');

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final since = now - SearchConfig.searchTimeWindowSeconds;

      // Fetch recent posts
      final filter = Filter(
        kinds: [1],
        since: since,
        limit: SearchConfig.maxResults * 2, // Fetch more to filter locally
      );

      final ndkEvents = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 10),
      );

      // Filter events by content locally
      final lowerQuery = query.toLowerCase();
      final matchingEvents = ndkEvents.where((event) {
        return event.content.toLowerCase().contains(lowerQuery);
      }).toList();

      // Sort by creation time (newest first)
      matchingEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Convert to posts
      final posts = matchingEvents
          .take(SearchConfig.maxResults)
          .map(_convertToPost)
          .toList();

      // debugPrint('Found ${posts.length} posts matching "$query"');

      state = SearchStateLoaded(
        query: query,
        filterType: SearchFilterType.posts,
        posts: posts,
        hasMore: matchingEvents.length > SearchConfig.maxResults,
      );
    } catch (e, stackTrace) {
      // debugPrint('Error searching posts: $e\n$stackTrace');
      state = SearchStateError(
        message: 'Failed to search: ${e.toString()}',
        query: query,
      );
    }
  }

  /// Search posts by hashtag.
  ///
  /// Uses the 't' tag filter for hashtag search.
  Future<void> searchByHashtag(String hashtag) async {
    // Remove # prefix if present
    final tag = hashtag.startsWith('#') ? hashtag.substring(1) : hashtag;

    if (tag.trim().isEmpty) {
      state = const SearchStateInitial();
      return;
    }

    _currentQuery = '#$tag';
    _currentFilterType = SearchFilterType.hashtags;

    state = SearchStateLoading(
      query: '#$tag',
      filterType: SearchFilterType.hashtags,
    );

    try {
      // debugPrint('Searching hashtag: #$tag');

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final since = now - SearchConfig.searchTimeWindowSeconds;

      // Create filter with hashtag tag
      final filter = Filter(
        kinds: [1],
        tTags: [tag.toLowerCase()],
        since: since,
        limit: SearchConfig.maxResults,
      );

      final ndkEvents = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 10),
      );

      // Sort by creation time (newest first)
      ndkEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Convert to posts
      final posts = ndkEvents.map(_convertToPost).toList();

      // debugPrint('Found ${posts.length} posts with hashtag #$tag');

      state = SearchStateLoaded(
        query: '#$tag',
        filterType: SearchFilterType.hashtags,
        posts: posts,
        hasMore: ndkEvents.length >= SearchConfig.maxResults,
      );
    } catch (e, stackTrace) {
      // debugPrint('Error searching hashtag: $e\n$stackTrace');
      state = SearchStateError(
        message: 'Failed to search: ${e.toString()}',
        query: '#$tag',
      );
    }
  }

  /// Search users by name or NIP-05.
  ///
  /// Note: Nostr doesn't support user search natively.
  /// This fetches recent profiles and filters locally.
  /// For better search, consider using a profile search relay.
  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      state = const SearchStateInitial();
      return;
    }

    _currentQuery = query;
    _currentFilterType = SearchFilterType.users;

    state = SearchStateLoading(
      query: query,
      filterType: SearchFilterType.users,
    );

    try {
      // debugPrint('Searching users for: $query');

      // Fetch recent profiles
      final filter = Filter(
        kinds: [0],
        limit: SearchConfig.maxResults * 2, // Fetch more to filter locally
      );

      final ndkEvents = await _ndkService.fetchEvents(
        filter: filter,
        timeout: const Duration(seconds: 10),
      );

      // Filter profiles by name/nip05 locally
      final lowerQuery = query.toLowerCase();
      final matchingProfiles = <Profile>[];

      for (final event in ndkEvents) {
        final profile = Profile.fromEvent(event);
        final nameMatch = (profile.name?.toLowerCase().contains(lowerQuery) ?? false) ||
            (profile.displayName?.toLowerCase().contains(lowerQuery) ?? false);
        final nip05Match = profile.nip05?.toLowerCase().contains(lowerQuery) ?? false;

        if (nameMatch || nip05Match) {
          matchingProfiles.add(profile);
        }
      }

      // Limit results
      final users = matchingProfiles.take(SearchConfig.maxResults).toList();

      // debugPrint('Found ${users.length} users matching "$query"');

      state = SearchStateLoaded(
        query: query,
        filterType: SearchFilterType.users,
        users: users,
        hasMore: matchingProfiles.length > SearchConfig.maxResults,
      );
    } catch (e, stackTrace) {
      // debugPrint('Error searching users: $e\n$stackTrace');
      state = SearchStateError(
        message: 'Failed to search: ${e.toString()}',
        query: query,
      );
    }
  }

  /// Perform a combined search based on filter type.
  Future<void> search(String query, {SearchFilterType? filterType}) async {
    final type = filterType ?? _currentFilterType;

    // Detect if query is a hashtag
    if (query.startsWith('#')) {
      await searchByHashtag(query);
      return;
    }

    switch (type) {
      case SearchFilterType.all:
        // For "all", search both posts and users
        await _searchAll(query);
        break;
      case SearchFilterType.posts:
        await searchPosts(query);
        break;
      case SearchFilterType.users:
        await searchUsers(query);
        break;
      case SearchFilterType.hashtags:
        await searchByHashtag(query);
        break;
    }
  }

  /// Search all (posts and users combined).
  Future<void> _searchAll(String query) async {
    if (query.trim().isEmpty) {
      state = const SearchStateInitial();
      return;
    }

    _currentQuery = query;
    _currentFilterType = SearchFilterType.all;

    state = SearchStateLoading(
      query: query,
      filterType: SearchFilterType.all,
    );

    try {
      // debugPrint('Searching all for: $query');

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final since = now - SearchConfig.searchTimeWindowSeconds;
      final lowerQuery = query.toLowerCase();

      // Fetch posts and profiles in parallel
      final postFilter = Filter(
        kinds: [1],
        since: since,
        limit: SearchConfig.maxResults,
      );

      final profileFilter = Filter(
        kinds: [0],
        limit: SearchConfig.maxResults,
      );

      final results = await Future.wait([
        _ndkService.fetchEvents(filter: postFilter, timeout: const Duration(seconds: 10)),
        _ndkService.fetchEvents(filter: profileFilter, timeout: const Duration(seconds: 10)),
      ]);

      final postEvents = results[0];
      final profileEvents = results[1];

      // Filter posts by content
      final matchingPosts = postEvents.where((event) {
        return event.content.toLowerCase().contains(lowerQuery);
      }).toList();

      matchingPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final posts = matchingPosts.take(SearchConfig.maxResults ~/ 2).map(_convertToPost).toList();

      // Filter profiles by name/nip05
      final matchingProfiles = <Profile>[];
      for (final event in profileEvents) {
        final profile = Profile.fromEvent(event);
        final nameMatch = (profile.name?.toLowerCase().contains(lowerQuery) ?? false) ||
            (profile.displayName?.toLowerCase().contains(lowerQuery) ?? false);
        final nip05Match = profile.nip05?.toLowerCase().contains(lowerQuery) ?? false;

        if (nameMatch || nip05Match) {
          matchingProfiles.add(profile);
        }
      }

      final users = matchingProfiles.take(SearchConfig.maxResults ~/ 2).toList();

      // debugPrint('Found ${posts.length} posts and ${users.length} users matching "$query"');

      state = SearchStateLoaded(
        query: query,
        filterType: SearchFilterType.all,
        posts: posts,
        users: users,
        hasMore: matchingPosts.length > SearchConfig.maxResults ~/ 2 ||
            matchingProfiles.length > SearchConfig.maxResults ~/ 2,
      );
    } catch (e, stackTrace) {
      // debugPrint('Error searching all: $e\n$stackTrace');
      state = SearchStateError(
        message: 'Failed to search: ${e.toString()}',
        query: query,
      );
    }
  }

  /// Set the current filter type.
  void setFilterType(SearchFilterType filterType) {
    _currentFilterType = filterType;

    // Re-search if we have a current query
    if (_currentQuery.isNotEmpty) {
      search(_currentQuery, filterType: filterType);
    }
  }

  /// Clear the search.
  void clearSearch() {
    _currentQuery = '';
    state = const SearchStateInitial();
  }

  /// Convert an NDK event to a Post model.
  Post _convertToPost(Nip01Event event) {
    // Extract reply and root event IDs from tags
    String? replyToId;
    String? rootEventId;

    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'e') {
        // 'e' tag references another event
        if (tag.length > 3) {
          // NIP-10 format: ["e", <event-id>, <relay-url>, <marker>]
          final marker = tag[3];
          if (marker == 'reply') {
            replyToId = tag[1];
          } else if (marker == 'root') {
            rootEventId = tag[1];
          }
        } else if (replyToId == null && tag.length >= 2) {
          // Fallback: first 'e' tag is reply-to
          replyToId = tag[1];
        }
      }
    }

    // Create author (using truncated pubkey as display name for now)
    final author = PostAuthor(
      pubkey: event.pubKey,
      displayName: _truncatePubkey(event.pubKey),
    );

    return Post(
      id: event.id,
      author: author,
      content: event.content,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        event.createdAt * 1000,
      ),
      replyToId: replyToId,
      rootEventId: rootEventId,
    );
  }

  /// Truncate a pubkey for display.
  String _truncatePubkey(String pubkey) {
    if (pubkey.length <= 12) {
      return pubkey;
    }
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 4)}';
  }
}
