import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/providers/auth_state.dart';
import '../features/auth/screens/auth_screen.dart';
import '../features/feed/models/post.dart';
import '../features/feed/screens/compose_screen.dart';
import '../features/feed/screens/explore_screen.dart';
import '../features/feed/screens/feed_screen.dart';
import '../features/feed/screens/thread_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/channels/screens/channels_list_screen.dart';
import '../features/channels/screens/channel_chat_screen.dart';
import '../features/settings/screens/media_settings_screen.dart';
import '../features/media/screens/media_library_screen.dart';
import 'main_shell.dart';

/// Provider for the app router.
final routerProvider = Provider<GoRouter>((ref) {
  // Watch auth state for route guards
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: _AuthStateNotifier(ref),
    redirect: (context, state) {
      final isAuthenticated = authState is AuthStateAuthenticated;
      final isAuthRoute = state.matchedLocation == '/auth';

      // If going to auth page while authenticated, redirect to home
      if (isAuthRoute && isAuthenticated) {
        return '/';
      }

      // Allow access to all routes (no forced auth requirement)
      return null;
    },
    routes: [
      // Shell route wraps pages that should show the navigation
      ShellRoute(
        builder: (context, state, child) {
          // Update navigation index based on current route
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final container = ProviderScope.containerOf(context);
            final index = getNavigationIndexFromLocation(state.matchedLocation);
            container.read(navigationIndexProvider.notifier).state = index;
          });
          return MainShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const FeedScreen(),
          ),
          GoRoute(
            path: '/explore',
            name: 'explore',
            builder: (context, state) => const ExploreScreen(),
          ),
          GoRoute(
            path: '/channels',
            name: 'channels',
            builder: (context, state) => const ChannelsListScreen(),
          ),
          GoRoute(
            path: '/channels/:id',
            name: 'channel',
            builder: (context, state) {
              final channelId = state.pathParameters['id']!;
              return ChannelChatScreen(channelId: channelId);
            },
          ),
          GoRoute(
            path: '/messages',
            name: 'messages',
            builder: (context, state) => const MessagesPlaceholder(),
          ),
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            builder: (context, state) => const NotificationsPlaceholder(),
          ),
          GoRoute(
            path: '/profile/:pubkey',
            name: 'profile',
            builder: (context, state) {
              final pubkey = state.pathParameters['pubkey']!;
              return ProfileScreen(pubkey: pubkey);
            },
          ),
          GoRoute(
            path: '/thread/:eventId',
            name: 'thread',
            builder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              final initialPost = state.extra as Post?;
              return ThreadScreen(
                eventId: eventId,
                initialPost: initialPost,
              );
            },
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsPlaceholder(),
          ),
          GoRoute(
            path: '/settings/media',
            name: 'media-settings',
            builder: (context, state) => const MediaSettingsScreen(),
          ),
          GoRoute(
            path: '/media-library',
            name: 'media-library',
            builder: (context, state) => const MediaLibraryScreen(),
          ),
        ],
      ),
      // Auth route outside shell (no navigation)
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      // Compose as modal (outside shell)
      GoRoute(
        path: '/compose',
        name: 'compose',
        builder: (context, state) => const ComposeScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

/// Helper class to notify GoRouter when auth state changes.
class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(this._ref) {
    _ref.listen(authProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
}

// Placeholder widgets - will be replaced with actual screens
class MessagesPlaceholder extends StatelessWidget {
  const MessagesPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Messages - Coming soon'));
  }
}

class NotificationsPlaceholder extends StatelessWidget {
  const NotificationsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Notifications - Coming soon'));
  }
}

class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Settings - Coming soon'));
  }
}
