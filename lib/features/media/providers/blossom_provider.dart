import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/blossom/blossom_models.dart';
import '../../../services/blossom/blossom_service.dart';
import '../../../services/secure_storage_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/auth_state.dart';

/// Type alias for backwards compatibility - BlobDescriptor is BlossomBlob
typedef BlobDescriptor = BlossomBlob;

/// Provider for SecureStorageService (uses existing if available).
final _storageServiceProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

/// Provider for the Blossom server URL.
///
/// Retrieves the configured Blossom server URL from secure storage.
/// Returns the default server URL if none is configured.
///
/// Example:
/// ```dart
/// final serverUrl = await ref.watch(blossomServerProvider.future);
/// ```
final blossomServerProvider = FutureProvider<String>((ref) async {
  final storageService = ref.watch(_storageServiceProvider);
  return await storageService.getBlossomServer();
});

/// Provider for updating the Blossom server URL.
///
/// Example:
/// ```dart
/// await ref.read(blossomServerSetterProvider)(newUrl);
/// ref.invalidate(blossomServerProvider); // Refresh the server URL
/// ```
final blossomServerSetterProvider = Provider<Future<bool> Function(String)>(
  (ref) {
    final storageService = ref.watch(_storageServiceProvider);
    return (String serverUrl) async {
      final success = await storageService.setBlossomServer(serverUrl);
      if (success) {
        ref.invalidate(blossomServerProvider);
      }
      return success;
    };
  },
);

/// Provider for the BlossomService singleton instance.
///
/// Returns the BlossomService singleton. The service URL and auth
/// are configured separately.
final blossomServiceProvider = Provider<BlossomService>((ref) {
  return BlossomService.instance;
});

/// Provider for the current user's private key.
///
/// Returns the private key if authenticated, null otherwise.
final _privateKeyProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState is AuthStateAuthenticated) {
    return authState.keypair.privateKey;
  }
  return null;
});

/// Provider for the current user's public key.
///
/// Returns the public key if authenticated, null otherwise.
final _publicKeyProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState is AuthStateAuthenticated) {
    return authState.keypair.publicKey;
  }
  return null;
});

/// Provider for upload progress stream from BlossomService.
///
/// Provides real-time upload progress updates.
///
/// Example:
/// ```dart
/// ref.listen(uploadProgressProvider, (previous, next) {
///   next.whenData((progress) {
///     print('Upload progress: ${progress.percentage}%');
///   });
/// });
/// ```
final uploadProgressProvider = StreamProvider<UploadProgress>((ref) {
  final blossomService = ref.watch(blossomServiceProvider);
  return blossomService.uploadProgress;
});

/// Provider for the media library state.
///
/// Manages the list of uploaded blobs and upload operations.
///
/// Example:
/// ```dart
/// final state = ref.watch(mediaLibraryProvider);
///
/// state.when(
///   initial: () => showEmptyState(),
///   loading: () => showLoadingIndicator(),
///   loaded: (blobs, isUploading) => showBlobsList(blobs),
///   error: (message) => showError(message),
/// );
///
/// // Load media library
/// ref.read(mediaLibraryProvider.notifier).loadLibrary();
///
/// // Upload a file
/// await ref.read(mediaLibraryProvider.notifier).uploadFile(file);
/// ```
final mediaLibraryProvider =
    StateNotifierProvider<MediaLibraryNotifier, MediaLibraryState>((ref) {
  return MediaLibraryNotifier(ref);
});

/// State for the media library.
///
/// Uses sealed class pattern for type-safe state handling:
/// - [MediaLibraryStateInitial]: Initial state, no data loaded
/// - [MediaLibraryStateLoading]: Loading blobs from server
/// - [MediaLibraryStateLoaded]: Blobs loaded successfully
/// - [MediaLibraryStateError]: An error occurred
@immutable
sealed class MediaLibraryState extends Equatable {
  const MediaLibraryState();

  @override
  List<Object?> get props => [];

  /// Pattern matching helper for consuming state.
  T when<T>({
    required T Function() initial,
    required T Function() loading,
    required T Function(List<BlobDescriptor> blobs, bool isUploading) loaded,
    required T Function(String message) error,
  }) {
    return switch (this) {
      MediaLibraryStateInitial() => initial(),
      MediaLibraryStateLoading() => loading(),
      MediaLibraryStateLoaded(blobs: final b, isUploading: final u) =>
        loaded(b, u),
      MediaLibraryStateError(message: final m) => error(m),
    };
  }

  /// Pattern matching helper with default case.
  T maybeWhen<T>({
    T Function()? initial,
    T Function()? loading,
    T Function(List<BlobDescriptor> blobs, bool isUploading)? loaded,
    T Function(String message)? error,
    required T Function() orElse,
  }) {
    return switch (this) {
      MediaLibraryStateInitial() => initial?.call() ?? orElse(),
      MediaLibraryStateLoading() => loading?.call() ?? orElse(),
      MediaLibraryStateLoaded(blobs: final b, isUploading: final u) =>
        loaded?.call(b, u) ?? orElse(),
      MediaLibraryStateError(message: final m) => error?.call(m) ?? orElse(),
    };
  }
}

/// Initial state - no data loaded yet.
class MediaLibraryStateInitial extends MediaLibraryState {
  const MediaLibraryStateInitial();

  @override
  String toString() => 'MediaLibraryStateInitial';
}

/// Loading state - fetching blobs from server.
class MediaLibraryStateLoading extends MediaLibraryState {
  const MediaLibraryStateLoading();

  @override
  String toString() => 'MediaLibraryStateLoading';
}

/// Loaded state - blobs available.
class MediaLibraryStateLoaded extends MediaLibraryState {
  const MediaLibraryStateLoaded({
    required this.blobs,
    this.isUploading = false,
  });

  /// List of blob descriptors from the server.
  final List<BlobDescriptor> blobs;

  /// Whether an upload is currently in progress.
  final bool isUploading;

  @override
  List<Object?> get props => [blobs, isUploading];

  @override
  String toString() =>
      'MediaLibraryStateLoaded(blobs: ${blobs.length}, isUploading: $isUploading)';

  /// Create a copy with updated fields.
  MediaLibraryStateLoaded copyWith({
    List<BlobDescriptor>? blobs,
    bool? isUploading,
  }) {
    return MediaLibraryStateLoaded(
      blobs: blobs ?? this.blobs,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}

/// Error state - something went wrong.
class MediaLibraryStateError extends MediaLibraryState {
  const MediaLibraryStateError({required this.message});

  /// Error message describing what went wrong.
  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => 'MediaLibraryStateError(message: $message)';
}

/// Notifier for managing media library state.
///
/// Provides methods for:
/// - Loading the media library (list of blobs)
/// - Uploading files to Blossom server
/// - Deleting blobs
class MediaLibraryNotifier extends StateNotifier<MediaLibraryState> {
  MediaLibraryNotifier(this._ref) : super(const MediaLibraryStateInitial());

  final Ref _ref;

  /// Load the media library from the Blossom server.
  ///
  /// Fetches the list of blobs uploaded by the current user.
  /// Requires authentication.
  Future<void> loadLibrary() async {
    debugPrint('[MediaLibrary] loadLibrary started');
    state = const MediaLibraryStateLoading();

    try {
      final blossomService = _ref.read(blossomServiceProvider);
      final pubkey = _ref.read(_publicKeyProvider);
      final privateKey = _ref.read(_privateKeyProvider);
      debugPrint('[MediaLibrary] pubkey: $pubkey');

      final serverUrl = await _ref.read(blossomServerProvider.future);
      debugPrint('[MediaLibrary] serverUrl: $serverUrl');

      if (pubkey == null) {
        state = const MediaLibraryStateError(
          message: 'Not authenticated. Please log in to view your media.',
        );
        return;
      }

      debugPrint('[MediaLibrary] Calling listBlobs...');
      final result = await blossomService.listBlobs(
        pubkey: pubkey,
        privateKey: privateKey,
        serverUrl: serverUrl,
      );
      debugPrint('[MediaLibrary] listBlobs result: isSuccess=${result.isSuccess}');

      if (result.isSuccess) {
        final blobs = result.dataOrNull ?? [];
        // Sort by upload time (newest first)
        blobs.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        state = MediaLibraryStateLoaded(blobs: blobs);
      } else {
        state = MediaLibraryStateError(
          message: result.errorOrNull ?? 'Failed to load media library',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading media library: $e\n$stackTrace');
      state = MediaLibraryStateError(
        message: 'Failed to load media library: $e',
      );
    }
  }

  /// Upload a file to the Blossom server.
  ///
  /// Returns the [BlobDescriptor] of the uploaded file on success,
  /// or null on failure. The state is updated with the new blob.
  ///
  /// [file] - The file to upload.
  Future<BlobDescriptor?> uploadFile(File file) async {
    final currentState = state;

    // Set uploading state
    if (currentState is MediaLibraryStateLoaded) {
      state = currentState.copyWith(isUploading: true);
    } else {
      state = const MediaLibraryStateLoaded(blobs: [], isUploading: true);
    }

    try {
      final blossomService = _ref.read(blossomServiceProvider);
      final privateKey = _ref.read(_privateKeyProvider);
      final serverUrl = await _ref.read(blossomServerProvider.future);

      if (privateKey == null) {
        final afterFailState = state;
        if (afterFailState is MediaLibraryStateLoaded) {
          state = afterFailState.copyWith(isUploading: false);
        }
        return null;
      }

      final fileBytes = await file.readAsBytes();
      final fileName = file.path.split('/').last;

      final result = await blossomService.uploadFile(
        fileBytes: fileBytes,
        fileName: fileName,
        privateKey: privateKey,
        serverUrl: serverUrl,
      );

      if (result.isSuccess && result.dataOrNull != null) {
        final blob = result.dataOrNull!;
        // Add the new blob to the list
        final afterUploadState = state;
        if (afterUploadState is MediaLibraryStateLoaded) {
          state = afterUploadState.copyWith(
            blobs: [blob, ...afterUploadState.blobs],
            isUploading: false,
          );
        }
        return blob;
      } else {
        // Upload failed, revert uploading state
        final afterFailState = state;
        if (afterFailState is MediaLibraryStateLoaded) {
          state = afterFailState.copyWith(isUploading: false);
        }
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('Error uploading file: $e\n$stackTrace');

      // Revert uploading state on error
      final afterErrorState = state;
      if (afterErrorState is MediaLibraryStateLoaded) {
        state = afterErrorState.copyWith(isUploading: false);
      } else {
        state = MediaLibraryStateError(
          message: 'Failed to upload file: $e',
        );
      }
      return null;
    }
  }

  /// Upload multiple files to the Blossom server.
  ///
  /// Returns a list of successfully uploaded [BlobDescriptor]s.
  /// Files that fail to upload are skipped.
  ///
  /// [files] - The files to upload.
  Future<List<BlobDescriptor>> uploadFiles(List<File> files) async {
    final uploadedBlobs = <BlobDescriptor>[];

    for (final file in files) {
      final blob = await uploadFile(file);
      if (blob != null) {
        uploadedBlobs.add(blob);
      }
    }

    return uploadedBlobs;
  }

  /// Delete a blob from the Blossom server.
  ///
  /// Returns true if successful, false otherwise.
  /// Removes the blob from the local state on success.
  ///
  /// [sha256] - The SHA-256 hash of the blob to delete.
  Future<bool> deleteBlob(String sha256) async {
    try {
      final blossomService = _ref.read(blossomServiceProvider);
      final privateKey = _ref.read(_privateKeyProvider);
      final serverUrl = await _ref.read(blossomServerProvider.future);

      if (privateKey == null) {
        return false;
      }

      final result = await blossomService.deleteBlob(
        sha256: sha256,
        privateKey: privateKey,
        serverUrl: serverUrl,
      );

      if (result.isSuccess && result.dataOrNull == true) {
        final currentState = state;
        if (currentState is MediaLibraryStateLoaded) {
          final updatedBlobs = currentState.blobs
              .where((blob) => blob.sha256 != sha256)
              .toList();
          state = currentState.copyWith(blobs: updatedBlobs);
        }
        return true;
      }

      return false;
    } catch (e, stackTrace) {
      debugPrint('Error deleting blob: $e\n$stackTrace');
      return false;
    }
  }

  /// Refresh the media library.
  ///
  /// Reloads the blob list from the server.
  Future<void> refresh() => loadLibrary();

  /// Clear error state and return to initial state.
  void clearError() {
    if (state is MediaLibraryStateError) {
      state = const MediaLibraryStateInitial();
    }
  }

  /// Check if the library is currently loading.
  bool get isLoading => state is MediaLibraryStateLoading;

  /// Check if an upload is in progress.
  bool get isUploading {
    final currentState = state;
    return currentState is MediaLibraryStateLoaded && currentState.isUploading;
  }

  /// Get the current list of blobs (empty if not loaded).
  List<BlobDescriptor> get blobs {
    final currentState = state;
    if (currentState is MediaLibraryStateLoaded) {
      return currentState.blobs;
    }
    return [];
  }
}
