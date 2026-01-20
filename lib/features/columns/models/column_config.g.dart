// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'column_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ColumnConfigImpl _$$ColumnConfigImplFromJson(Map<String, dynamic> json) =>
    _$ColumnConfigImpl(
      id: json['id'] as String,
      type: $enumDecode(_$ColumnTypeEnumMap, json['type']),
      title: json['title'] as String?,
      hashtag: json['hashtag'] as String?,
      userPubkey: json['userPubkey'] as String?,
      channelId: json['channelId'] as String?,
      searchQuery: json['searchQuery'] as String?,
      width: (json['width'] as num?)?.toDouble() ?? 350,
      position: (json['position'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$ColumnConfigImplToJson(_$ColumnConfigImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$ColumnTypeEnumMap[instance.type]!,
      'title': instance.title,
      'hashtag': instance.hashtag,
      'userPubkey': instance.userPubkey,
      'channelId': instance.channelId,
      'searchQuery': instance.searchQuery,
      'width': instance.width,
      'position': instance.position,
    };

const _$ColumnTypeEnumMap = {
  ColumnType.home: 'home',
  ColumnType.explore: 'explore',
  ColumnType.hashtag: 'hashtag',
  ColumnType.user: 'user',
  ColumnType.channel: 'channel',
  ColumnType.notifications: 'notifications',
  ColumnType.messages: 'messages',
  ColumnType.search: 'search',
};
