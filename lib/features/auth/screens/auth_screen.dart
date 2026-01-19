import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';

/// Authentication screen for login/signup.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _nsecController = TextEditingController();

  @override
  void dispose() {
    _nsecController.dispose();
    super.dispose();
  }

  Future<void> _generateNewKey() async {
    final authNotifier = ref.read(authProvider.notifier);
    await authNotifier.generateNewIdentity();
  }

  Future<void> _importKey() async {
    final nsec = _nsecController.text.trim();
    if (nsec.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your nsec key')),
      );
      return;
    }

    final authNotifier = ref.read(authProvider.notifier);
    await authNotifier.importFromNsec(nsec);
  }

  void _showKeyGeneratedDialog(AuthStateAuthenticated authState) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Key Generated', style: AppTypography.headlineMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your new Nostr identity has been created!',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your npub (public):',
                    style: AppTypography.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          authState.npub,
                          style: AppTypography.bodySmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: authState.npub));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied npub')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your nsec (private - SAVE THIS!):',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          authState.nsec,
                          style: AppTypography.bodySmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: authState.nsec));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied nsec')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Save your nsec key securely! You cannot recover it if lost.',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/');
            },
            child: const Text('I saved it, continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthStateAuthenticated) {
        // Show success dialog when key is generated
        if (previous is AuthStateLoading &&
            (previous.operation == 'generating')) {
          _showKeyGeneratedDialog(next);
        } else {
          // Navigate to home on successful import
          context.go('/');
        }
      } else if (next is AuthStateError) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthStateLoading;
    final errorMessage = authState is AuthStateError ? authState.message : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bolt,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PlebsHub',
                    style: AppTypography.displayMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Generate new key
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New to Nostr?',
                    style: AppTypography.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate a new identity to get started.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Generate New Key',
                    icon: Icons.add,
                    isExpanded: true,
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _generateNewKey,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Divider
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('or', style: AppTypography.labelMedium),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),

            // Import key
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Already have a key?',
                    style: AppTypography.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Import your existing nsec key.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nsecController,
                    decoration: const InputDecoration(
                      labelText: 'nsec key',
                      hintText: 'nsec1...',
                    ),
                    obscureText: true,
                    enabled: !isLoading,
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Import Key',
                    icon: Icons.login,
                    isExpanded: true,
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _importKey,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // NIP-07 (web only)
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browser Extension',
                    style: AppTypography.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect with a NIP-07 browser extension like Alby or nos2x.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Connect Extension',
                    icon: Icons.extension,
                    isExpanded: true,
                    onPressed: () {
                      // TODO: NIP-07 connection
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('NIP-07 support coming soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
