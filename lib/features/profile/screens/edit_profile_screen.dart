import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

import '../../../services/profile_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';
import '../models/profile.dart';
import '../providers/profile_provider.dart';

/// Screen for editing the current user's profile.
///
/// Allows editing:
/// - Display name
/// - Username (@name)
/// - About/bio
/// - Profile picture URL
/// - Banner URL
/// - NIP-05 identifier
/// - Lightning address (lud16)
/// - Website
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _displayNameController;
  late TextEditingController _usernameController;
  late TextEditingController _aboutController;
  late TextEditingController _pictureController;
  late TextEditingController _bannerController;
  late TextEditingController _nip05Controller;
  late TextEditingController _lud16Controller;
  late TextEditingController _websiteController;

  bool _isLoading = false;
  bool _hasChanges = false;
  String? _errorMessage;
  Profile? _originalProfile;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _usernameController = TextEditingController();
    _aboutController = TextEditingController();
    _pictureController = TextEditingController();
    _bannerController = TextEditingController();
    _nip05Controller = TextEditingController();
    _lud16Controller = TextEditingController();
    _websiteController = TextEditingController();

    // Add listeners for change detection
    _displayNameController.addListener(_onFieldChanged);
    _usernameController.addListener(_onFieldChanged);
    _aboutController.addListener(_onFieldChanged);
    _pictureController.addListener(_onFieldChanged);
    _bannerController.addListener(_onFieldChanged);
    _nip05Controller.addListener(_onFieldChanged);
    _lud16Controller.addListener(_onFieldChanged);
    _websiteController.addListener(_onFieldChanged);

    // Load current profile data
    Future.microtask(_loadCurrentProfile);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _aboutController.dispose();
    _pictureController.dispose();
    _bannerController.dispose();
    _nip05Controller.dispose();
    _lud16Controller.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (_originalProfile != null) {
      final hasChanges = _displayNameController.text != (_originalProfile!.displayName ?? '') ||
          _usernameController.text != (_originalProfile!.name ?? '') ||
          _aboutController.text != (_originalProfile!.about ?? '') ||
          _pictureController.text != (_originalProfile!.picture ?? '') ||
          _bannerController.text != (_originalProfile!.banner ?? '') ||
          _nip05Controller.text != (_originalProfile!.nip05 ?? '') ||
          _lud16Controller.text != (_originalProfile!.lud16 ?? '') ||
          _websiteController.text != (_originalProfile!.website ?? '');

      if (hasChanges != _hasChanges) {
        setState(() {
          _hasChanges = hasChanges;
        });
      }
    }
  }

  Future<void> _loadCurrentProfile() async {
    final authState = ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) {
      context.go('/auth');
      return;
    }

    final profileService = ProfileService.instance;
    final profile = await profileService.fetchProfile(
      authState.keypair.publicKey,
      forceRefresh: true,
    );

    _originalProfile = profile;

    setState(() {
      _displayNameController.text = profile.displayName ?? '';
      _usernameController.text = profile.name ?? '';
      _aboutController.text = profile.about ?? '';
      _pictureController.text = profile.picture ?? '';
      _bannerController.text = profile.banner ?? '';
      _nip05Controller.text = profile.nip05 ?? '';
      _lud16Controller.text = profile.lud16 ?? '';
      _websiteController.text = profile.website ?? '';
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authState = ref.read(authProvider);
    if (authState is! AuthStateAuthenticated) {
      setState(() {
        _errorMessage = 'Not authenticated';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profileService = ProfileService.instance;

      final updatedProfile = Profile(
        pubkey: authState.keypair.publicKey,
        displayName: _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : null,
        name: _usernameController.text.trim().isNotEmpty
            ? _usernameController.text.trim()
            : null,
        about: _aboutController.text.trim().isNotEmpty
            ? _aboutController.text.trim()
            : null,
        picture: _pictureController.text.trim().isNotEmpty
            ? _pictureController.text.trim()
            : null,
        banner: _bannerController.text.trim().isNotEmpty
            ? _bannerController.text.trim()
            : null,
        nip05: _nip05Controller.text.trim().isNotEmpty
            ? _nip05Controller.text.trim()
            : null,
        lud16: _lud16Controller.text.trim().isNotEmpty
            ? _lud16Controller.text.trim()
            : null,
        website: _websiteController.text.trim().isNotEmpty
            ? _websiteController.text.trim()
            : null,
      );

      final event = await profileService.updateProfile(
        profile: updatedProfile,
        privateKey: authState.keypair.privateKey!,
      );

      if (event != null) {
        // Invalidate the profile provider to refresh data
        ref.invalidate(profileProvider(authState.keypair.publicKey));
        ref.invalidate(currentUserProfileProvider);
        ref.invalidate(profileScreenProvider(authState.keypair.publicKey));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to publish profile update';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateUrl(String? value, {bool required = false}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'This field is required' : null;
    }

    final trimmed = value.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'URL must start with http:// or https://';
    }

    try {
      Uri.parse(trimmed);
      return null;
    } catch (e) {
      return 'Invalid URL format';
    }
  }

  String? _validateNip05(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final trimmed = value.trim();
    // NIP-05 format: name@domain.com or _@domain.com
    final nip05Pattern = RegExp(r'^[a-zA-Z0-9_]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!nip05Pattern.hasMatch(trimmed)) {
      return 'Invalid NIP-05 format (e.g., alice@example.com)';
    }

    return null;
  }

  String? _validateLud16(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final trimmed = value.trim();
    // Lightning address format: name@domain.com
    final lud16Pattern = RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!lud16Pattern.hasMatch(trimmed)) {
      return 'Invalid lightning address format';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _handleCancel(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading || !_hasChanges ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: _hasChanges ? AppColors.primary : AppColors.textTertiary,
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

            // Banner preview
            _buildImagePreview(
              url: _bannerController.text,
              height: 120,
              placeholder: 'Banner Preview',
              icon: Icons.panorama,
            ),
            const SizedBox(height: 16),

            // Avatar preview
            Center(
              child: _buildAvatarPreview(),
            ),
            const SizedBox(height: 24),

            // Display Name
            _buildTextField(
              controller: _displayNameController,
              label: 'Display Name',
              hint: 'How your name appears to others',
              icon: Icons.person,
            ),
            const SizedBox(height: 16),

            // Username
            _buildTextField(
              controller: _usernameController,
              label: 'Username',
              hint: '@username',
              icon: Icons.alternate_email,
              prefixText: '@',
            ),
            const SizedBox(height: 16),

            // About/Bio
            _buildTextField(
              controller: _aboutController,
              label: 'About',
              hint: 'Tell others about yourself',
              icon: Icons.info_outline,
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // Profile Picture URL
            _buildTextField(
              controller: _pictureController,
              label: 'Profile Picture URL',
              hint: 'https://example.com/avatar.jpg',
              icon: Icons.image,
              keyboardType: TextInputType.url,
              validator: (value) => _validateUrl(value),
            ),
            const SizedBox(height: 16),

            // Banner URL
            _buildTextField(
              controller: _bannerController,
              label: 'Banner URL',
              hint: 'https://example.com/banner.jpg',
              icon: Icons.panorama,
              keyboardType: TextInputType.url,
              validator: (value) => _validateUrl(value),
            ),
            const SizedBox(height: 16),

            // NIP-05 Identifier
            _buildTextField(
              controller: _nip05Controller,
              label: 'NIP-05 Identifier',
              hint: 'alice@example.com',
              icon: Icons.verified,
              keyboardType: TextInputType.emailAddress,
              validator: _validateNip05,
            ),
            const SizedBox(height: 16),

            // Lightning Address
            _buildTextField(
              controller: _lud16Controller,
              label: 'Lightning Address',
              hint: 'alice@getalby.com',
              icon: Icons.bolt,
              keyboardType: TextInputType.emailAddress,
              validator: _validateLud16,
            ),
            const SizedBox(height: 16),

            // Website
            _buildTextField(
              controller: _websiteController,
              label: 'Website',
              hint: 'https://example.com',
              icon: Icons.link,
              keyboardType: TextInputType.url,
              validator: (value) => _validateUrl(value),
            ),
            const SizedBox(height: 32),

            // Info text
            Text(
              'Your profile will be published to connected relays. Changes may take a moment to propagate.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? prefixText,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        prefixText: prefixText,
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
    );
  }

  Widget _buildImagePreview({
    required String url,
    required double height,
    required String placeholder,
    required IconData icon,
  }) {
    if (url.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: AppColors.textTertiary),
              const SizedBox(height: 8),
              Text(
                placeholder,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: height,
          color: AppColors.surfaceVariant,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          height: height,
          color: AppColors.surfaceVariant,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: AppColors.error),
                const SizedBox(height: 4),
                Text(
                  'Invalid image URL',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    final url = _pictureController.text;
    const size = 100.0;

    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceVariant,
        ),
        child: Icon(
          Icons.person,
          size: 48,
          color: AppColors.textTertiary,
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          color: AppColors.surfaceVariant,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          color: AppColors.surfaceVariant,
          child: Icon(Icons.broken_image, color: AppColors.error),
        ),
      ),
    );
  }

  void _handleCancel() {
    if (_hasChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                this.context.pop();
              },
              child: Text(
                'Discard',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
    } else {
      context.pop();
    }
  }
}
