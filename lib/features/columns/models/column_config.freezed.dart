// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'column_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ColumnConfig _$ColumnConfigFromJson(Map<String, dynamic> json) {
  return _ColumnConfig.fromJson(json);
}

/// @nodoc
mixin _$ColumnConfig {
  /// Unique identifier for this column (UUID)
  String get id => throw _privateConstructorUsedError;

  /// Type of content this column displays
  ColumnType get type => throw _privateConstructorUsedError;

  /// Custom title for the column (uses default based on type if null)
  String? get title => throw _privateConstructorUsedError;

  /// Hashtag to display (required for [ColumnType.hashtag])
  String? get hashtag => throw _privateConstructorUsedError;

  /// User's public key (required for [ColumnType.user])
  String? get userPubkey => throw _privateConstructorUsedError;

  /// Channel ID (required for [ColumnType.channel])
  String? get channelId => throw _privateConstructorUsedError;

  /// Search query (required for [ColumnType.search])
  String? get searchQuery => throw _privateConstructorUsedError;

  /// Column width in logical pixels
  double get width => throw _privateConstructorUsedError;

  /// Position in the column order (0-indexed, left to right)
  int get position => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ColumnConfigCopyWith<ColumnConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ColumnConfigCopyWith<$Res> {
  factory $ColumnConfigCopyWith(
          ColumnConfig value, $Res Function(ColumnConfig) then) =
      _$ColumnConfigCopyWithImpl<$Res, ColumnConfig>;
  @useResult
  $Res call(
      {String id,
      ColumnType type,
      String? title,
      String? hashtag,
      String? userPubkey,
      String? channelId,
      String? searchQuery,
      double width,
      int position});
}

/// @nodoc
class _$ColumnConfigCopyWithImpl<$Res, $Val extends ColumnConfig>
    implements $ColumnConfigCopyWith<$Res> {
  _$ColumnConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = freezed,
    Object? hashtag = freezed,
    Object? userPubkey = freezed,
    Object? channelId = freezed,
    Object? searchQuery = freezed,
    Object? width = null,
    Object? position = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ColumnType,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      hashtag: freezed == hashtag
          ? _value.hashtag
          : hashtag // ignore: cast_nullable_to_non_nullable
              as String?,
      userPubkey: freezed == userPubkey
          ? _value.userPubkey
          : userPubkey // ignore: cast_nullable_to_non_nullable
              as String?,
      channelId: freezed == channelId
          ? _value.channelId
          : channelId // ignore: cast_nullable_to_non_nullable
              as String?,
      searchQuery: freezed == searchQuery
          ? _value.searchQuery
          : searchQuery // ignore: cast_nullable_to_non_nullable
              as String?,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as double,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ColumnConfigImplCopyWith<$Res>
    implements $ColumnConfigCopyWith<$Res> {
  factory _$$ColumnConfigImplCopyWith(
          _$ColumnConfigImpl value, $Res Function(_$ColumnConfigImpl) then) =
      __$$ColumnConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      ColumnType type,
      String? title,
      String? hashtag,
      String? userPubkey,
      String? channelId,
      String? searchQuery,
      double width,
      int position});
}

/// @nodoc
class __$$ColumnConfigImplCopyWithImpl<$Res>
    extends _$ColumnConfigCopyWithImpl<$Res, _$ColumnConfigImpl>
    implements _$$ColumnConfigImplCopyWith<$Res> {
  __$$ColumnConfigImplCopyWithImpl(
      _$ColumnConfigImpl _value, $Res Function(_$ColumnConfigImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = freezed,
    Object? hashtag = freezed,
    Object? userPubkey = freezed,
    Object? channelId = freezed,
    Object? searchQuery = freezed,
    Object? width = null,
    Object? position = null,
  }) {
    return _then(_$ColumnConfigImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ColumnType,
      title: freezed == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      hashtag: freezed == hashtag
          ? _value.hashtag
          : hashtag // ignore: cast_nullable_to_non_nullable
              as String?,
      userPubkey: freezed == userPubkey
          ? _value.userPubkey
          : userPubkey // ignore: cast_nullable_to_non_nullable
              as String?,
      channelId: freezed == channelId
          ? _value.channelId
          : channelId // ignore: cast_nullable_to_non_nullable
              as String?,
      searchQuery: freezed == searchQuery
          ? _value.searchQuery
          : searchQuery // ignore: cast_nullable_to_non_nullable
              as String?,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as double,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ColumnConfigImpl extends _ColumnConfig {
  const _$ColumnConfigImpl(
      {required this.id,
      required this.type,
      this.title,
      this.hashtag,
      this.userPubkey,
      this.channelId,
      this.searchQuery,
      this.width = 350,
      this.position = 0})
      : super._();

  factory _$ColumnConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$ColumnConfigImplFromJson(json);

  /// Unique identifier for this column (UUID)
  @override
  final String id;

  /// Type of content this column displays
  @override
  final ColumnType type;

  /// Custom title for the column (uses default based on type if null)
  @override
  final String? title;

  /// Hashtag to display (required for [ColumnType.hashtag])
  @override
  final String? hashtag;

  /// User's public key (required for [ColumnType.user])
  @override
  final String? userPubkey;

  /// Channel ID (required for [ColumnType.channel])
  @override
  final String? channelId;

  /// Search query (required for [ColumnType.search])
  @override
  final String? searchQuery;

  /// Column width in logical pixels
  @override
  @JsonKey()
  final double width;

  /// Position in the column order (0-indexed, left to right)
  @override
  @JsonKey()
  final int position;

  @override
  String toString() {
    return 'ColumnConfig(id: $id, type: $type, title: $title, hashtag: $hashtag, userPubkey: $userPubkey, channelId: $channelId, searchQuery: $searchQuery, width: $width, position: $position)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ColumnConfigImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.hashtag, hashtag) || other.hashtag == hashtag) &&
            (identical(other.userPubkey, userPubkey) ||
                other.userPubkey == userPubkey) &&
            (identical(other.channelId, channelId) ||
                other.channelId == channelId) &&
            (identical(other.searchQuery, searchQuery) ||
                other.searchQuery == searchQuery) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.position, position) ||
                other.position == position));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, type, title, hashtag,
      userPubkey, channelId, searchQuery, width, position);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ColumnConfigImplCopyWith<_$ColumnConfigImpl> get copyWith =>
      __$$ColumnConfigImplCopyWithImpl<_$ColumnConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ColumnConfigImplToJson(
      this,
    );
  }
}

abstract class _ColumnConfig extends ColumnConfig {
  const factory _ColumnConfig(
      {required final String id,
      required final ColumnType type,
      final String? title,
      final String? hashtag,
      final String? userPubkey,
      final String? channelId,
      final String? searchQuery,
      final double width,
      final int position}) = _$ColumnConfigImpl;
  const _ColumnConfig._() : super._();

  factory _ColumnConfig.fromJson(Map<String, dynamic> json) =
      _$ColumnConfigImpl.fromJson;

  @override

  /// Unique identifier for this column (UUID)
  String get id;
  @override

  /// Type of content this column displays
  ColumnType get type;
  @override

  /// Custom title for the column (uses default based on type if null)
  String? get title;
  @override

  /// Hashtag to display (required for [ColumnType.hashtag])
  String? get hashtag;
  @override

  /// User's public key (required for [ColumnType.user])
  String? get userPubkey;
  @override

  /// Channel ID (required for [ColumnType.channel])
  String? get channelId;
  @override

  /// Search query (required for [ColumnType.search])
  String? get searchQuery;
  @override

  /// Column width in logical pixels
  double get width;
  @override

  /// Position in the column order (0-indexed, left to right)
  int get position;
  @override
  @JsonKey(ignore: true)
  _$$ColumnConfigImplCopyWith<_$ColumnConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
