import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../media/providers/blossom_provider.dart';

/// Common Blossom servers that users can choose from.
const List<BlossomServerOption> kCommonBlossomServers = [
  BlossomServerOption(
    name: 'Primal',
    url: 'https://blossom.primal.net',
    description: 'Popular, reliable server by Primal',
  ),
  BlossomServerOption(
    name: 'Oxtr.dev',
    url: 'https://blossom.oxtr.dev',
    description: 'Community server',
  ),
  BlossomServerOption(
    name: 'Satellite.earth',
    url: 'https://cdn.satellite.earth',
    description: 'CDN-backed server',
  ),
];

/// Represents a Blossom server option.
class BlossomServerOption {
  const BlossomServerOption({
    required this.name,
    required this.url,
    required this.description,
  });

  final String name;
  final String url;
  final String description;
}

/// Screen for configuring Blossom media server settings.
///
/// Features:
/// - View and edit the Blossom server URL
/// - Quick selection of common servers
/// - Test connection to verify server is reachable
/// - Save configuration
class MediaSettingsScreen extends ConsumerStatefulWidget {
  const MediaSettingsScreen({super.key});

  @override
  ConsumerState<MediaSettingsScreen> createState() =>
      _MediaSettingsScreenState();
}

class _MediaSettingsScreenState extends ConsumerState<MediaSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _serverUrlController;

  bool _isLoading = false;
  bool _isTesting = false;
  bool _hasChanges = false;
  String? _errorMessage;
  String? _testResult;
  bool? _testSuccess;
  String? _originalServerUrl;

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController();
    _serverUrlController.addListener(_onFieldChanged);
    Future.microtask(_loadCurrentServer);
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_originalServerUrl != null) {
      final hasChanges =
          _serverUrlController.text.trim() != _originalServerUrl;

      if (hasChanges != _hasChanges) {
        setState(() {
          _hasChanges = hasChanges;
          // Clear test results when URL changes
          _testResult = null;
          _testSuccess = null;
        });
      }
    }
  }

  Future<void> _loadCurrentServer() async {
    try {
      final serverUrl = await ref.read(blossomServerProvider.future);
      _originalServerUrl = serverUrl;
      setState(() {
        _serverUrlController.text = serverUrl;
      });
    } on Exception catch (e) {
      setState(() {
        _errorMessage = 'Failed to load server settings: $e';
      });
    }
  }

  Future<void> _testConnection() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testResult = 'Please enter a server URL';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      // Try to reach the server by making a HEAD request
      final uri = Uri.parse(url);
      final response = await http
          .head(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 400) {
        setState(() {
          _testResult = 'Connection successful!';
          _testSuccess = true;
        });
      } else {
        setState(() {
          _testResult = 'Server returned status ${response.statusCode}';
          _testSuccess = false;
        });
      }
    } on Exception catch (e) {
      setState(() {
        _testResult = 'Connection failed: ${e.toString().split(':').first}';
        _testSuccess = false;
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final serverUrl = _serverUrlController.text.trim();
      final setServer = ref.read(blossomServerSetterProvider);
      final success = await setServer(serverUrl);

      if (success) {
        _originalServerUrl = serverUrl;
        setState(() {
          _hasChanges = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Media settings saved'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to save settings';
        });
      }
    } on Exception catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectServer(BlossomServerOption server) {
    setState(() {
      _serverUrlController.text = server.url;
    });
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Server URL is required';
    }

    final trimmed = value.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'URL must start with http:// or https://';
    }

    try {
      final uri = Uri.parse(trimmed);
      if (uri.host.isEmpty) {
        return 'Invalid URL';
      }
      return null;
    } on FormatException {
      return 'Invalid URL format';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: context.pop,
        ),
        actions: [
          TextButton(
            onPressed: _isLoading || !_hasChanges ? null : _saveSettings,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color:
                          _hasChanges ? AppColors.primary : AppColors.textTertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Info card about Blossom
            _buildInfoCard(),
            const SizedBox(height: 24),

            // Server URL input
            Text(
              'Blossom Server URL',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _serverUrlController,
              keyboardType: TextInputType.url,
              validator: _validateUrl,
              decoration: InputDecoration(
                hintText: 'https://blossom.example.com',
                prefixIcon: const Icon(Icons.cloud),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.error),
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 16),

            // Test connection button and result
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering, size: 18),
                  label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                ),
                if (_testResult != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          (_testSuccess ?? false)
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: (_testSuccess ?? false)
                              ? Colors.green
                              : AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _testResult!,
                            style: AppTypography.bodySmall.copyWith(
                              color: (_testSuccess ?? false)
                                  ? Colors.green
                                  : AppColors.error,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Common servers section
            Text(
              'Common Servers',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to select a pre-configured server',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _buildServerChips(),
            const SizedBox(height: 24),

            // Server cards with more details
            ...kCommonBlossomServers.map((server) => _buildServerCard(server)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'What is Blossom?',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Blossom is a decentralized media hosting protocol for Nostr. '
            'Files are stored using content-addressing (SHA-256 hashes), '
            'enabling deduplication and verification across servers. '
            'Your media uploads will be stored on the configured server.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );

  Widget _buildServerChips() {
    final currentUrl = _serverUrlController.text.trim();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kCommonBlossomServers.map((server) {
        final isSelected = currentUrl == server.url;
        return FilterChip(
          label: Text(server.name),
          selected: isSelected,
          onSelected: (_) => _selectServer(server),
          selectedColor: AppColors.primary.withValues(alpha: 0.2),
          checkmarkColor: AppColors.primary,
          labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServerCard(BlossomServerOption server) {
    final isSelected = _serverUrlController.text.trim() == server.url;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _selectServer(server),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.cloud,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      server.url,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      server.description,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
