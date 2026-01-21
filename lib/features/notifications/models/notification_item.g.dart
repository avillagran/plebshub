// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NotificationItemImpl _$$NotificationItemImplFromJson(
        Map<String, dynamic> json) =>
    _$NotificationItemImpl(
      id: json['id'] as String,
      type: $enumDecode(_$NotificationTypeEnumMap, json['type']),
      fromPubkey: json['fromPubkey'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      eventId: json['eventId'] as String?,
      content: json['content'] as String?,
      fromDisplayName: json['fromDisplayName'] as String?,
      fromPicture: json['fromPicture'] as String?,
    );

Map<String, dynamic> _$$NotificationItemImplToJson(
        _$NotificationItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$NotificationTypeEnumMap[instance.type]!,
      'fromPubkey': instance.fromPubkey,
      'createdAt': instance.createdAt.toIso8601String(),
      'eventId': instance.eventId,
      'content': instance.content,
      'fromDisplayName': instance.fromDisplayName,
      'fromPicture': instance.fromPicture,
    };

const _$NotificationTypeEnumMap = {
  NotificationType.mention: 'mention',
  NotificationType.reply: 'reply',
  NotificationType.reaction: 'reaction',
  NotificationType.repost: 'repost',
};
