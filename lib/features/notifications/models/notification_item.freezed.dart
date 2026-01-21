// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

NotificationItem _$NotificationItemFromJson(Map<String, dynamic> json) {
  return _NotificationItem.fromJson(json);
}

/// @nodoc
mixin _$NotificationItem {
  /// Unique identifier for this notification (event ID)
  String get id => throw _privateConstructorUsedError;

  /// Type of notification (mention, reply, reaction, repost)
  NotificationType get type => throw _privateConstructorUsedError;

  /// Public key of the user who triggered this notification
  String get fromPubkey => throw _privateConstructorUsedError;

  /// When this notification was created
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// The event ID being referenced (for replies, reactions, reposts)
  String? get eventId => throw _privateConstructorUsedError;

  /// Content of the notification (for mentions, replies, or reaction emoji)
  String? get content => throw _privateConstructorUsedError;

  /// Display name of the user who triggered this notification
  String? get fromDisplayName => throw _privateConstructorUsedError;

  /// Profile picture URL of the user who triggered this notification
  String? get fromPicture => throw _privateConstructorUsedError;

  /// Serializes this NotificationItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NotificationItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationItemCopyWith<NotificationItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationItemCopyWith<$Res> {
  factory $NotificationItemCopyWith(
          NotificationItem value, $Res Function(NotificationItem) then) =
      _$NotificationItemCopyWithImpl<$Res, NotificationItem>;
  @useResult
  $Res call(
      {String id,
      NotificationType type,
      String fromPubkey,
      DateTime createdAt,
      String? eventId,
      String? content,
      String? fromDisplayName,
      String? fromPicture});
}

/// @nodoc
class _$NotificationItemCopyWithImpl<$Res, $Val extends NotificationItem>
    implements $NotificationItemCopyWith<$Res> {
  _$NotificationItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? fromPubkey = null,
    Object? createdAt = null,
    Object? eventId = freezed,
    Object? content = freezed,
    Object? fromDisplayName = freezed,
    Object? fromPicture = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as NotificationType,
      fromPubkey: null == fromPubkey
          ? _value.fromPubkey
          : fromPubkey // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      eventId: freezed == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String?,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
      fromDisplayName: freezed == fromDisplayName
          ? _value.fromDisplayName
          : fromDisplayName // ignore: cast_nullable_to_non_nullable
              as String?,
      fromPicture: freezed == fromPicture
          ? _value.fromPicture
          : fromPicture // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NotificationItemImplCopyWith<$Res>
    implements $NotificationItemCopyWith<$Res> {
  factory _$$NotificationItemImplCopyWith(_$NotificationItemImpl value,
          $Res Function(_$NotificationItemImpl) then) =
      __$$NotificationItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      NotificationType type,
      String fromPubkey,
      DateTime createdAt,
      String? eventId,
      String? content,
      String? fromDisplayName,
      String? fromPicture});
}

/// @nodoc
class __$$NotificationItemImplCopyWithImpl<$Res>
    extends _$NotificationItemCopyWithImpl<$Res, _$NotificationItemImpl>
    implements _$$NotificationItemImplCopyWith<$Res> {
  __$$NotificationItemImplCopyWithImpl(_$NotificationItemImpl _value,
      $Res Function(_$NotificationItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of NotificationItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? fromPubkey = null,
    Object? createdAt = null,
    Object? eventId = freezed,
    Object? content = freezed,
    Object? fromDisplayName = freezed,
    Object? fromPicture = freezed,
  }) {
    return _then(_$NotificationItemImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as NotificationType,
      fromPubkey: null == fromPubkey
          ? _value.fromPubkey
          : fromPubkey // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      eventId: freezed == eventId
          ? _value.eventId
          : eventId // ignore: cast_nullable_to_non_nullable
              as String?,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
      fromDisplayName: freezed == fromDisplayName
          ? _value.fromDisplayName
          : fromDisplayName // ignore: cast_nullable_to_non_nullable
              as String?,
      fromPicture: freezed == fromPicture
          ? _value.fromPicture
          : fromPicture // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NotificationItemImpl implements _NotificationItem {
  const _$NotificationItemImpl(
      {required this.id,
      required this.type,
      required this.fromPubkey,
      required this.createdAt,
      this.eventId,
      this.content,
      this.fromDisplayName,
      this.fromPicture});

  factory _$NotificationItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotificationItemImplFromJson(json);

  /// Unique identifier for this notification (event ID)
  @override
  final String id;

  /// Type of notification (mention, reply, reaction, repost)
  @override
  final NotificationType type;

  /// Public key of the user who triggered this notification
  @override
  final String fromPubkey;

  /// When this notification was created
  @override
  final DateTime createdAt;

  /// The event ID being referenced (for replies, reactions, reposts)
  @override
  final String? eventId;

  /// Content of the notification (for mentions, replies, or reaction emoji)
  @override
  final String? content;

  /// Display name of the user who triggered this notification
  @override
  final String? fromDisplayName;

  /// Profile picture URL of the user who triggered this notification
  @override
  final String? fromPicture;

  @override
  String toString() {
    return 'NotificationItem(id: $id, type: $type, fromPubkey: $fromPubkey, createdAt: $createdAt, eventId: $eventId, content: $content, fromDisplayName: $fromDisplayName, fromPicture: $fromPicture)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.fromPubkey, fromPubkey) ||
                other.fromPubkey == fromPubkey) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.eventId, eventId) || other.eventId == eventId) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.fromDisplayName, fromDisplayName) ||
                other.fromDisplayName == fromDisplayName) &&
            (identical(other.fromPicture, fromPicture) ||
                other.fromPicture == fromPicture));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, type, fromPubkey, createdAt,
      eventId, content, fromDisplayName, fromPicture);

  /// Create a copy of NotificationItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationItemImplCopyWith<_$NotificationItemImpl> get copyWith =>
      __$$NotificationItemImplCopyWithImpl<_$NotificationItemImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NotificationItemImplToJson(
      this,
    );
  }
}

abstract class _NotificationItem implements NotificationItem {
  const factory _NotificationItem(
      {required final String id,
      required final NotificationType type,
      required final String fromPubkey,
      required final DateTime createdAt,
      final String? eventId,
      final String? content,
      final String? fromDisplayName,
      final String? fromPicture}) = _$NotificationItemImpl;

  factory _NotificationItem.fromJson(Map<String, dynamic> json) =
      _$NotificationItemImpl.fromJson;

  /// Unique identifier for this notification (event ID)
  @override
  String get id;

  /// Type of notification (mention, reply, reaction, repost)
  @override
  NotificationType get type;

  /// Public key of the user who triggered this notification
  @override
  String get fromPubkey;

  /// When this notification was created
  @override
  DateTime get createdAt;

  /// The event ID being referenced (for replies, reactions, reposts)
  @override
  String? get eventId;

  /// Content of the notification (for mentions, replies, or reaction emoji)
  @override
  String? get content;

  /// Display name of the user who triggered this notification
  @override
  String? get fromDisplayName;

  /// Profile picture URL of the user who triggered this notification
  @override
  String? get fromPicture;

  /// Create a copy of NotificationItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotificationItemImplCopyWith<_$NotificationItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
