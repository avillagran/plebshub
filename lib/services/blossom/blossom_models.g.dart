// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blossom_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BlossomBlobImpl _$$BlossomBlobImplFromJson(Map<String, dynamic> json) =>
    _$BlossomBlobImpl(
      sha256: json['sha256'] as String,
      size: (json['size'] as num).toInt(),
      mimeType: json['mimeType'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      url: json['url'] as String,
      fileName: json['fileName'] as String?,
      blurhash: json['blurhash'] as String?,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );

Map<String, dynamic> _$$BlossomBlobImplToJson(_$BlossomBlobImpl instance) =>
    <String, dynamic>{
      'sha256': instance.sha256,
      'size': instance.size,
      'mimeType': instance.mimeType,
      'uploadedAt': instance.uploadedAt.toIso8601String(),
      'url': instance.url,
      'fileName': instance.fileName,
      'blurhash': instance.blurhash,
      'width': instance.width,
      'height': instance.height,
    };

_$UploadProgressImpl _$$UploadProgressImplFromJson(Map<String, dynamic> json) =>
    _$UploadProgressImpl(
      fileName: json['fileName'] as String,
      bytesUploaded: (json['bytesUploaded'] as num).toInt(),
      totalBytes: (json['totalBytes'] as num).toInt(),
      status: $enumDecode(_$UploadStatusEnumMap, json['status']),
      sha256: json['sha256'] as String?,
      error: json['error'] as String?,
      blobUrl: json['blobUrl'] as String?,
      serverUrl: json['serverUrl'] as String?,
    );

Map<String, dynamic> _$$UploadProgressImplToJson(
        _$UploadProgressImpl instance) =>
    <String, dynamic>{
      'fileName': instance.fileName,
      'bytesUploaded': instance.bytesUploaded,
      'totalBytes': instance.totalBytes,
      'status': _$UploadStatusEnumMap[instance.status]!,
      'sha256': instance.sha256,
      'error': instance.error,
      'blobUrl': instance.blobUrl,
      'serverUrl': instance.serverUrl,
    };

const _$UploadStatusEnumMap = {
  UploadStatus.pending: 'pending',
  UploadStatus.uploading: 'uploading',
  UploadStatus.processing: 'processing',
  UploadStatus.completed: 'completed',
  UploadStatus.failed: 'failed',
};
