// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PostImpl _$$PostImplFromJson(Map<String, dynamic> json) => _$PostImpl(
      id: json['id'] as String,
      author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      reactionsCount: (json['reactionsCount'] as num?)?.toInt() ?? 0,
      repostsCount: (json['repostsCount'] as num?)?.toInt() ?? 0,
      zapsCount: (json['zapsCount'] as num?)?.toInt() ?? 0,
      replyToId: json['replyToId'] as String?,
      rootEventId: json['rootEventId'] as String?,
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$PostImplToJson(_$PostImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'author': instance.author,
      'content': instance.content,
      'createdAt': instance.createdAt.toIso8601String(),
      'reactionsCount': instance.reactionsCount,
      'repostsCount': instance.repostsCount,
      'zapsCount': instance.zapsCount,
      'replyToId': instance.replyToId,
      'rootEventId': instance.rootEventId,
      'replyCount': instance.replyCount,
    };

_$PostAuthorImpl _$$PostAuthorImplFromJson(Map<String, dynamic> json) =>
    _$PostAuthorImpl(
      pubkey: json['pubkey'] as String,
      displayName: json['displayName'] as String,
      nip05: json['nip05'] as String?,
      picture: json['picture'] as String?,
      about: json['about'] as String?,
    );

Map<String, dynamic> _$$PostAuthorImplToJson(_$PostAuthorImpl instance) =>
    <String, dynamic>{
      'pubkey': instance.pubkey,
      'displayName': instance.displayName,
      'nip05': instance.nip05,
      'picture': instance.picture,
      'about': instance.about,
    };
