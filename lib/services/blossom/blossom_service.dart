import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

import 'blossom_auth.dart';
import 'blossom_constants.dart';
import 'blossom_models.dart';

/// Service for uploading and managing media on Blossom servers.
///
/// Blossom is a decentralized media hosting protocol for Nostr.
/// Files are content-addressed using SHA-256 hashes, allowing
/// deduplication and verification across servers.
///
/// Features:
/// - File upload with progress tracking
/// - List blobs for a public key
/// - Delete blobs
/// - Multiple server support with fallback
///
/// Example:
/// ```dart
/// final service = BlossomService.instance;
///
/// // Upload a file
/// final result = await service.uploadFile(
///   fileBytes: imageBytes,
///   fileName: 'photo.jpg',
///   privateKey: userPrivateKey,
/// );
///
/// // Listen to upload progress
/// service.uploadProgress.listen((progress) {
///   print('${progress.fileName}: ${progress.percentage}%');
/// });
///
/// // List user's blobs
/// final blobs = await service.listBlobs(
///   pubkey: userPubkey,
///   privateKey: userPrivateKey,
/// );
/// ```
class BlossomService {
  BlossomService._();

  static final BlossomService _instance = BlossomService._();

  /// Singleton instance of BlossomService.
  static BlossomService get instance => _instance;

  /// HTTP client for making requests.
  final http.Client _httpClient = http.Client();

  /// Auth helper for creating Blossom auth events.
  final BlossomAuth _auth = BlossomAuth();

  /// Stream controller for upload progress updates.
  final StreamController<UploadProgress> _progressController =
      StreamController<UploadProgress>.broadcast();

  /// Stream of upload progress updates.
  ///
  /// Emits [UploadProgress] events during file uploads.
  /// Multiple listeners can subscribe to this stream.
  Stream<UploadProgress> get uploadProgress => _progressController.stream;

  /// Request timeout duration.
  static const Duration _timeout = Duration(seconds: 30);

  /// Upload timeout for large files.
  static const Duration _uploadTimeout = Duration(minutes: 5);

  /// Uploads a file to a Blossom server.
  ///
  /// Parameters:
  /// - [fileBytes]: Raw file content as bytes
  /// - [fileName]: Original filename (used for MIME type detection)
  /// - [privateKey]: User's private key (hex) for authentication
  /// - [serverUrl]: Blossom server URL (defaults to [kDefaultBlossomServer])
  /// - [mimeType]: Optional MIME type (auto-detected if not provided)
  ///
  /// Returns: [BlossomResult] containing [BlossomBlob] on success or error message.
  ///
  /// Progress updates are emitted via [uploadProgress] stream.
  ///
  /// Example:
  /// ```dart
  /// final bytes = await file.readAsBytes();
  /// final result = await BlossomService.instance.uploadFile(
  ///   fileBytes: bytes,
  ///   fileName: 'photo.jpg',
  ///   privateKey: myPrivateKey,
  /// );
  ///
  /// result.when(
  ///   success: (blob) => print('Uploaded: ${blob.url}'),
  ///   failure: (error) => print('Error: $error'),
  /// );
  /// ```
  Future<BlossomResult<BlossomBlob>> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    required String privateKey,
    String serverUrl = kDefaultBlossomServer,
    String? mimeType,
  }) async {
    // Validate file size
    if (fileBytes.length > kMaxBlossomFileSize) {
      return const BlossomResult.failure(
        'File too large. Maximum size is 100 MB',
      );
    }

    // Detect or validate MIME type
    final detectedMimeType =
        mimeType ?? lookupMimeType(fileName) ?? 'application/octet-stream';

    // Emit initial progress
    _emitProgress(
      UploadProgress.initial(fileName, fileBytes.length),
    );

    try {
      // Calculate SHA-256 hash
      final digest = sha256.convert(fileBytes);
      final sha256Hash = digest.toString();

      _emitProgress(
        UploadProgress(
          fileName: fileName,
          bytesUploaded: 0,
          totalBytes: fileBytes.length,
          status: UploadStatus.uploading,
          sha256: sha256Hash,
          serverUrl: serverUrl,
        ),
      );

      // Create auth headers
      final headers = _auth.createUploadHeaders(
        sha256: sha256Hash,
        privateKey: privateKey,
        mimeType: detectedMimeType,
        contentLength: fileBytes.length,
        serverUrl: serverUrl,
      );

      // Create and send the request using StreamedRequest for progress
      final uploadUrl = Uri.parse(BlossomEndpoints.upload(serverUrl));
      final request = http.StreamedRequest('PUT', uploadUrl);

      // Add headers
      request.headers.addAll(headers);

      // Track upload progress
      var bytesSent = 0;
      final totalBytes = fileBytes.length;

      // Create a stream that tracks progress
      final byteStream = _createProgressStream(
        fileBytes,
        (sent) {
          bytesSent = sent;
          _emitProgress(
            UploadProgress(
              fileName: fileName,
              bytesUploaded: bytesSent,
              totalBytes: totalBytes,
              status: UploadStatus.uploading,
              sha256: sha256Hash,
              serverUrl: serverUrl,
            ),
          );
        },
      );

      // Pipe the bytes to the request
      request.contentLength = totalBytes;
      byteStream.listen(
        request.sink.add,
        onDone: request.sink.close,
        onError: request.sink.addError,
      );

      // Send the request
      final streamedResponse =
          await _httpClient.send(request).timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      // Emit processing status
      _emitProgress(
        UploadProgress(
          fileName: fileName,
          bytesUploaded: totalBytes,
          totalBytes: totalBytes,
          status: UploadStatus.processing,
          sha256: sha256Hash,
          serverUrl: serverUrl,
        ),
      );

      // Check response
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;
          final blob = BlossomBlob.fromServerResponse(responseData, serverUrl);

          // Emit success
          _emitProgress(
            UploadProgress(
              fileName: fileName,
              bytesUploaded: totalBytes,
              totalBytes: totalBytes,
              status: UploadStatus.completed,
              sha256: sha256Hash,
              blobUrl: blob.url,
              serverUrl: serverUrl,
            ),
          );

          return BlossomResult.success(blob);
        } on FormatException {
          // If response parsing fails, construct blob from known data
          final blob = BlossomBlob(
            sha256: sha256Hash,
            size: fileBytes.length,
            mimeType: detectedMimeType,
            uploadedAt: DateTime.now(),
            url: '$serverUrl/$sha256Hash',
            fileName: fileName,
          );

          _emitProgress(
            UploadProgress(
              fileName: fileName,
              bytesUploaded: totalBytes,
              totalBytes: totalBytes,
              status: UploadStatus.completed,
              sha256: sha256Hash,
              blobUrl: blob.url,
              serverUrl: serverUrl,
            ),
          );

          return BlossomResult.success(blob);
        }
      } else {
        final errorMessage = _parseErrorResponse(response);
        _emitProgress(
          UploadProgress(
            fileName: fileName,
            bytesUploaded: bytesSent,
            totalBytes: totalBytes,
            status: UploadStatus.failed,
            sha256: sha256Hash,
            error: errorMessage,
            serverUrl: serverUrl,
          ),
        );
        return BlossomResult.failure(errorMessage);
      }
    } on Exception catch (e) {
      final errorMessage = 'Upload failed: $e';
      _emitProgress(
        UploadProgress(
          fileName: fileName,
          bytesUploaded: 0,
          totalBytes: fileBytes.length,
          status: UploadStatus.failed,
          error: errorMessage,
          serverUrl: serverUrl,
        ),
      );
      debugPrint('BlossomService upload error: $e');
      return BlossomResult.failure(errorMessage);
    }
  }

  /// Lists blobs uploaded by a specific public key.
  ///
  /// Parameters:
  /// - [pubkey]: Public key (hex) to list blobs for
  /// - [privateKey]: User's private key for authentication (optional for public blobs)
  /// - [serverUrl]: Blossom server URL (defaults to [kDefaultBlossomServer])
  ///
  /// Returns: [BlossomResult] containing list of [BlossomBlob] or error.
  ///
  /// Example:
  /// ```dart
  /// final result = await BlossomService.instance.listBlobs(
  ///   pubkey: myPubkey,
  ///   privateKey: myPrivateKey,
  /// );
  ///
  /// result.when(
  ///   success: (blobs) {
  ///     for (final blob in blobs) {
  ///       print('${blob.fileName}: ${blob.url}');
  ///     }
  ///   },
  ///   failure: (error) => print('Error: $error'),
  /// );
  /// ```
  Future<BlossomResult<List<BlossomBlob>>> listBlobs({
    required String pubkey,
    String? privateKey,
    String serverUrl = kDefaultBlossomServer,
  }) async {
    try {
      final url = Uri.parse(BlossomEndpoints.list(serverUrl, pubkey));

      final headers = <String, String>{
        'Accept': 'application/json',
        'User-Agent': kBlossomUserAgent,
      };

      // Add auth if private key provided
      if (privateKey != null) {
        headers.addAll(
          _auth.createListHeaders(
            privateKey: privateKey,
            serverUrl: serverUrl,
          ),
        );
      }

      final response = await _httpClient.get(url, headers: headers).timeout(
            _timeout,
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final blobsJson = data is List ? data : (data['blobs'] as List? ?? []);

        final blobs = blobsJson
            .map(
              (json) => BlossomBlob.fromServerResponse(
                json as Map<String, dynamic>,
                serverUrl,
              ),
            )
            .toList();

        return BlossomResult.success(blobs);
      } else {
        return BlossomResult.failure(_parseErrorResponse(response));
      }
    } on Exception catch (e) {
      debugPrint('BlossomService listBlobs error: $e');
      return BlossomResult.failure('Failed to list blobs: $e');
    }
  }

  /// Deletes a blob from the Blossom server.
  ///
  /// Only the original uploader can delete a blob.
  ///
  /// Parameters:
  /// - [sha256]: SHA-256 hash of the blob to delete
  /// - [privateKey]: User's private key for authentication
  /// - [serverUrl]: Blossom server URL (defaults to [kDefaultBlossomServer])
  ///
  /// Returns: [BlossomResult] with true on success or error message.
  ///
  /// Example:
  /// ```dart
  /// final result = await BlossomService.instance.deleteBlob(
  ///   sha256: blobHash,
  ///   privateKey: myPrivateKey,
  /// );
  ///
  /// if (result.isSuccess) {
  ///   print('Blob deleted successfully');
  /// }
  /// ```
  Future<BlossomResult<bool>> deleteBlob({
    required String sha256,
    required String privateKey,
    String serverUrl = kDefaultBlossomServer,
  }) async {
    try {
      final url = Uri.parse(BlossomEndpoints.delete(serverUrl, sha256));

      final headers = _auth.createDeleteHeaders(
        sha256: sha256,
        privateKey: privateKey,
        serverUrl: serverUrl,
      );

      final response = await _httpClient.delete(url, headers: headers).timeout(
            _timeout,
          );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return const BlossomResult.success(true);
      } else {
        return BlossomResult.failure(_parseErrorResponse(response));
      }
    } on Exception catch (e) {
      debugPrint('BlossomService deleteBlob error: $e');
      return BlossomResult.failure('Failed to delete blob: $e');
    }
  }

  /// Gets blob metadata without downloading the content.
  ///
  /// Uses HEAD request to fetch only the headers.
  ///
  /// Parameters:
  /// - [sha256]: SHA-256 hash of the blob
  /// - [serverUrl]: Blossom server URL (defaults to [kDefaultBlossomServer])
  ///
  /// Returns: [BlossomResult] with blob metadata or error.
  Future<BlossomResult<BlossomBlob>> getBlobInfo({
    required String sha256,
    String serverUrl = kDefaultBlossomServer,
  }) async {
    try {
      final url = Uri.parse(BlossomEndpoints.get(serverUrl, sha256));

      final response = await _httpClient.head(
        url,
        headers: {'User-Agent': kBlossomUserAgent},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final headers = response.headers;
        final contentLength =
            int.tryParse(headers['content-length'] ?? '0') ?? 0;
        final contentType =
            headers['content-type'] ?? 'application/octet-stream';

        final blob = BlossomBlob(
          sha256: sha256,
          size: contentLength,
          mimeType: contentType,
          uploadedAt: DateTime.now(),
          url: url.toString(),
        );

        return BlossomResult.success(blob);
      } else if (response.statusCode == 404) {
        return const BlossomResult.failure('Blob not found');
      } else {
        return BlossomResult.failure(
          'Failed to get blob info: ${response.statusCode}',
        );
      }
    } on Exception catch (e) {
      debugPrint('BlossomService getBlobInfo error: $e');
      return BlossomResult.failure('Failed to get blob info: $e');
    }
  }

  /// Checks if a blob exists on the server.
  ///
  /// Parameters:
  /// - [sha256]: SHA-256 hash of the blob
  /// - [serverUrl]: Blossom server URL (defaults to [kDefaultBlossomServer])
  ///
  /// Returns: true if blob exists, false otherwise.
  Future<bool> blobExists({
    required String sha256,
    String serverUrl = kDefaultBlossomServer,
  }) async {
    final result = await getBlobInfo(sha256: sha256, serverUrl: serverUrl);
    return result.isSuccess;
  }

  /// Calculates SHA-256 hash of file bytes.
  ///
  /// Utility method to pre-calculate hash before upload.
  String calculateSha256(Uint8List bytes) => sha256.convert(bytes).toString();

  /// Creates a stream that tracks upload progress.
  Stream<List<int>> _createProgressStream(
    Uint8List bytes,
    void Function(int bytesSent) onProgress,
  ) {
    var bytesSent = 0;
    return Stream.fromIterable(_chunkBytes(bytes)).map((chunk) {
      bytesSent += chunk.length;
      onProgress(bytesSent);
      return chunk;
    });
  }

  /// Chunks bytes for streaming upload with progress tracking.
  Iterable<List<int>> _chunkBytes(Uint8List bytes) sync* {
    const chunkSize = 64 * 1024; // 64KB chunks
    var offset = 0;

    while (offset < bytes.length) {
      final end =
          (offset + chunkSize > bytes.length) ? bytes.length : offset + chunkSize;
      yield bytes.sublist(offset, end);
      offset = end;
    }
  }

  /// Emits a progress update to the stream.
  void _emitProgress(UploadProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  /// Parses error response from the server.
  String _parseErrorResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data['message'] as String? ??
            data['error'] as String? ??
            'Server error: ${response.statusCode}';
      }
    } on FormatException {
      // Not JSON, use body directly if short enough
    }

    if (response.body.length < 200) {
      return response.body.isNotEmpty
          ? response.body
          : 'Server error: ${response.statusCode}';
    }

    return 'Server error: ${response.statusCode}';
  }

  /// Disposes of resources.
  void dispose() {
    _progressController.close();
    _httpClient.close();
  }
}
