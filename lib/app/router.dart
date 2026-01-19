import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/feed/screens/feed_screen.dart';
import '../features/feed/screens/compose_screen.dart';
import '../features/feed/screens/thread_screen.dart';
import '../features/auth/screens/auth_screen.dart';
import '../features/profile/screens/profile_screen.dart';

/// Provider for the app router.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const FeedScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/compose',
        name: 'compose',
        builder: (context, state) => const ComposeScreen(),
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
          return ThreadScreen(eventId: eventId);
        },
      ),
      GoRoute(
        path: '/channels',
        name: 'channels',
        builder: (context, state) => const ChannelsPlaceholder(),
      ),
      GoRoute(
        path: '/messages',
        name: 'messages',
        builder: (context, state) => const MessagesPlaceholder(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPlaceholder(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

// Placeholder widgets - will be replaced with actual screens
class ChannelsPlaceholder extends StatelessWidget {
  const ChannelsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Channels')),
      body: const Center(child: Text('Channels - Coming soon')),
    );
  }
}

class MessagesPlaceholder extends StatelessWidget {
  const MessagesPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: const Center(child: Text('Messages - Coming soon')),
    );
  }
}

class SettingsPlaceholder extends StatelessWidget {
  const SettingsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings - Coming soon')),
    );
  }
}
