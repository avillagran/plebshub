import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../widgets/post_card.dart';

/// The main feed screen showing the user's timeline.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.bolt, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'PlebsHub',
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => context.push('/auth'),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _mockPosts.length,
        itemBuilder: (context, index) {
          final post = _mockPosts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PostCard(
              authorName: post['author'] as String,
              authorPubkey: post['pubkey'] as String,
              content: post['content'] as String,
              createdAt: DateTime.now().subtract(
                Duration(hours: index * 2),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Open compose dialog
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              // Already on feed
              break;
            case 1:
              context.push('/channels');
              break;
            case 2:
              context.push('/messages');
              break;
            case 3:
              context.push('/settings');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tag),
            label: 'Channels',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mail),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Mock data for testing UI
final _mockPosts = [
  {
    'author': 'Satoshi Nakamoto',
    'pubkey': 'npub1abc...xyz',
    'content':
        'The Times 03/Jan/2009 Chancellor on brink of second bailout for banks.',
  },
  {
    'author': 'Jack',
    'pubkey': 'npub1def...uvw',
    'content': 'Just mass-adopted Nostr. LFG! #Bitcoin #Nostr',
  },
  {
    'author': 'Pleb',
    'pubkey': 'npub1ghi...rst',
    'content':
        'Building something cool with PlebsHub. Stay tuned! ⚡️',
  },
  {
    'author': 'fiatjaf',
    'pubkey': 'npub1jkl...opq',
    'content': 'Nostr is the future of social media. Simple and decentralized.',
  },
];
