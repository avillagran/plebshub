// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Post _$PostFromJson(Map<String, dynamic> json) {
  return _Post.fromJson(json);
}

/// @nodoc
mixin _$Post {
  /// Event ID (32-byte hex string)
  String get id => throw _privateConstructorUsedError;

  /// Author information
  PostAuthor get author => throw _privateConstructorUsedError;

  /// Post content (text)
  String get content => throw _privateConstructorUsedError;

  /// When the post was created
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Number of reactions (likes) this post has received
  int get reactionsCount => throw _privateConstructorUsedError;

  /// Number of times this post has been reposted
  int get repostsCount => throw _privateConstructorUsedError;

  /// Number of zaps (Lightning payments) this post has received
  int get zapsCount => throw _privateConstructorUsedError;

  /// Reply-to event ID (if this is a reply)
  String? get replyToId => throw _privateConstructorUsedError;

  /// Root event ID (for threading)
  String? get rootEventId => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PostCopyWith<Post> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PostCopyWith<$Res> {
  factory $PostCopyWith(Post value, $Res Function(Post) then) =
      _$PostCopyWithImpl<$Res, Post>;
  @useResult
  $Res call(
      {String id,
      PostAuthor author,
      String content,
      DateTime createdAt,
      int reactionsCount,
      int repostsCount,
      int zapsCount,
      String? replyToId,
      String? rootEventId});

  $PostAuthorCopyWith<$Res> get author;
}

/// @nodoc
class _$PostCopyWithImpl<$Res, $Val extends Post>
    implements $PostCopyWith<$Res> {
  _$PostCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? author = null,
    Object? content = null,
    Object? createdAt = null,
    Object? reactionsCount = null,
    Object? repostsCount = null,
    Object? zapsCount = null,
    Object? replyToId = freezed,
    Object? rootEventId = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as PostAuthor,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      reactionsCount: null == reactionsCount
          ? _value.reactionsCount
          : reactionsCount // ignore: cast_nullable_to_non_nullable
              as int,
      repostsCount: null == repostsCount
          ? _value.repostsCount
          : repostsCount // ignore: cast_nullable_to_non_nullable
              as int,
      zapsCount: null == zapsCount
          ? _value.zapsCount
          : zapsCount // ignore: cast_nullable_to_non_nullable
              as int,
      replyToId: freezed == replyToId
          ? _value.replyToId
          : replyToId // ignore: cast_nullable_to_non_nullable
              as String?,
      rootEventId: freezed == rootEventId
          ? _value.rootEventId
          : rootEventId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $PostAuthorCopyWith<$Res> get author {
    return $PostAuthorCopyWith<$Res>(_value.author, (value) {
      return _then(_value.copyWith(author: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PostImplCopyWith<$Res> implements $PostCopyWith<$Res> {
  factory _$$PostImplCopyWith(
          _$PostImpl value, $Res Function(_$PostImpl) then) =
      __$$PostImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      PostAuthor author,
      String content,
      DateTime createdAt,
      int reactionsCount,
      int repostsCount,
      int zapsCount,
      String? replyToId,
      String? rootEventId});

  @override
  $PostAuthorCopyWith<$Res> get author;
}

/// @nodoc
class __$$PostImplCopyWithImpl<$Res>
    extends _$PostCopyWithImpl<$Res, _$PostImpl>
    implements _$$PostImplCopyWith<$Res> {
  __$$PostImplCopyWithImpl(_$PostImpl _value, $Res Function(_$PostImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? author = null,
    Object? content = null,
    Object? createdAt = null,
    Object? reactionsCount = null,
    Object? repostsCount = null,
    Object? zapsCount = null,
    Object? replyToId = freezed,
    Object? rootEventId = freezed,
  }) {
    return _then(_$PostImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as PostAuthor,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      reactionsCount: null == reactionsCount
          ? _value.reactionsCount
          : reactionsCount // ignore: cast_nullable_to_non_nullable
              as int,
      repostsCount: null == repostsCount
          ? _value.repostsCount
          : repostsCount // ignore: cast_nullable_to_non_nullable
              as int,
      zapsCount: null == zapsCount
          ? _value.zapsCount
          : zapsCount // ignore: cast_nullable_to_non_nullable
              as int,
      replyToId: freezed == replyToId
          ? _value.replyToId
          : replyToId // ignore: cast_nullable_to_non_nullable
              as String?,
      rootEventId: freezed == rootEventId
          ? _value.rootEventId
          : rootEventId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PostImpl implements _Post {
  const _$PostImpl(
      {required this.id,
      required this.author,
      required this.content,
      required this.createdAt,
      this.reactionsCount = 0,
      this.repostsCount = 0,
      this.zapsCount = 0,
      this.replyToId,
      this.rootEventId});

  factory _$PostImpl.fromJson(Map<String, dynamic> json) =>
      _$$PostImplFromJson(json);

  /// Event ID (32-byte hex string)
  @override
  final String id;

  /// Author information
  @override
  final PostAuthor author;

  /// Post content (text)
  @override
  final String content;

  /// When the post was created
  @override
  final DateTime createdAt;

  /// Number of reactions (likes) this post has received
  @override
  @JsonKey()
  final int reactionsCount;

  /// Number of times this post has been reposted
  @override
  @JsonKey()
  final int repostsCount;

  /// Number of zaps (Lightning payments) this post has received
  @override
  @JsonKey()
  final int zapsCount;

  /// Reply-to event ID (if this is a reply)
  @override
  final String? replyToId;

  /// Root event ID (for threading)
  @override
  final String? rootEventId;

  @override
  String toString() {
    return 'Post(id: $id, author: $author, content: $content, createdAt: $createdAt, reactionsCount: $reactionsCount, repostsCount: $repostsCount, zapsCount: $zapsCount, replyToId: $replyToId, rootEventId: $rootEventId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PostImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.reactionsCount, reactionsCount) ||
                other.reactionsCount == reactionsCount) &&
            (identical(other.repostsCount, repostsCount) ||
                other.repostsCount == repostsCount) &&
            (identical(other.zapsCount, zapsCount) ||
                other.zapsCount == zapsCount) &&
            (identical(other.replyToId, replyToId) ||
                other.replyToId == replyToId) &&
            (identical(other.rootEventId, rootEventId) ||
                other.rootEventId == rootEventId));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, author, content, createdAt,
      reactionsCount, repostsCount, zapsCount, replyToId, rootEventId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PostImplCopyWith<_$PostImpl> get copyWith =>
      __$$PostImplCopyWithImpl<_$PostImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PostImplToJson(
      this,
    );
  }
}

abstract class _Post implements Post {
  const factory _Post(
      {required final String id,
      required final PostAuthor author,
      required final String content,
      required final DateTime createdAt,
      final int reactionsCount,
      final int repostsCount,
      final int zapsCount,
      final String? replyToId,
      final String? rootEventId}) = _$PostImpl;

  factory _Post.fromJson(Map<String, dynamic> json) = _$PostImpl.fromJson;

  @override

  /// Event ID (32-byte hex string)
  String get id;
  @override

  /// Author information
  PostAuthor get author;
  @override

  /// Post content (text)
  String get content;
  @override

  /// When the post was created
  DateTime get createdAt;
  @override

  /// Number of reactions (likes) this post has received
  int get reactionsCount;
  @override

  /// Number of times this post has been reposted
  int get repostsCount;
  @override

  /// Number of zaps (Lightning payments) this post has received
  int get zapsCount;
  @override

  /// Reply-to event ID (if this is a reply)
  String? get replyToId;
  @override

  /// Root event ID (for threading)
  String? get rootEventId;
  @override
  @JsonKey(ignore: true)
  _$$PostImplCopyWith<_$PostImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PostAuthor _$PostAuthorFromJson(Map<String, dynamic> json) {
  return _PostAuthor.fromJson(json);
}

/// @nodoc
mixin _$PostAuthor {
  /// Author's public key (32-byte hex string)
  String get pubkey => throw _privateConstructorUsedError;

  /// Display name (from kind:0 metadata, or truncated pubkey if not available)
  String get displayName => throw _privateConstructorUsedError;

  /// NIP-05 verification (e.g., alice@example.com)
  String? get nip05 => throw _privateConstructorUsedError;

  /// Profile picture URL
  String? get picture => throw _privateConstructorUsedError;

  /// About/bio text
  String? get about => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PostAuthorCopyWith<PostAuthor> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PostAuthorCopyWith<$Res> {
  factory $PostAuthorCopyWith(
          PostAuthor value, $Res Function(PostAuthor) then) =
      _$PostAuthorCopyWithImpl<$Res, PostAuthor>;
  @useResult
  $Res call(
      {String pubkey,
      String displayName,
      String? nip05,
      String? picture,
      String? about});
}

/// @nodoc
class _$PostAuthorCopyWithImpl<$Res, $Val extends PostAuthor>
    implements $PostAuthorCopyWith<$Res> {
  _$PostAuthorCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pubkey = null,
    Object? displayName = null,
    Object? nip05 = freezed,
    Object? picture = freezed,
    Object? about = freezed,
  }) {
    return _then(_value.copyWith(
      pubkey: null == pubkey
          ? _value.pubkey
          : pubkey // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      nip05: freezed == nip05
          ? _value.nip05
          : nip05 // ignore: cast_nullable_to_non_nullable
              as String?,
      picture: freezed == picture
          ? _value.picture
          : picture // ignore: cast_nullable_to_non_nullable
              as String?,
      about: freezed == about
          ? _value.about
          : about // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PostAuthorImplCopyWith<$Res>
    implements $PostAuthorCopyWith<$Res> {
  factory _$$PostAuthorImplCopyWith(
          _$PostAuthorImpl value, $Res Function(_$PostAuthorImpl) then) =
      __$$PostAuthorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String pubkey,
      String displayName,
      String? nip05,
      String? picture,
      String? about});
}

/// @nodoc
class __$$PostAuthorImplCopyWithImpl<$Res>
    extends _$PostAuthorCopyWithImpl<$Res, _$PostAuthorImpl>
    implements _$$PostAuthorImplCopyWith<$Res> {
  __$$PostAuthorImplCopyWithImpl(
      _$PostAuthorImpl _value, $Res Function(_$PostAuthorImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pubkey = null,
    Object? displayName = null,
    Object? nip05 = freezed,
    Object? picture = freezed,
    Object? about = freezed,
  }) {
    return _then(_$PostAuthorImpl(
      pubkey: null == pubkey
          ? _value.pubkey
          : pubkey // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      nip05: freezed == nip05
          ? _value.nip05
          : nip05 // ignore: cast_nullable_to_non_nullable
              as String?,
      picture: freezed == picture
          ? _value.picture
          : picture // ignore: cast_nullable_to_non_nullable
              as String?,
      about: freezed == about
          ? _value.about
          : about // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PostAuthorImpl implements _PostAuthor {
  const _$PostAuthorImpl(
      {required this.pubkey,
      required this.displayName,
      this.nip05,
      this.picture,
      this.about});

  factory _$PostAuthorImpl.fromJson(Map<String, dynamic> json) =>
      _$$PostAuthorImplFromJson(json);

  /// Author's public key (32-byte hex string)
  @override
  final String pubkey;

  /// Display name (from kind:0 metadata, or truncated pubkey if not available)
  @override
  final String displayName;

  /// NIP-05 verification (e.g., alice@example.com)
  @override
  final String? nip05;

  /// Profile picture URL
  @override
  final String? picture;

  /// About/bio text
  @override
  final String? about;

  @override
  String toString() {
    return 'PostAuthor(pubkey: $pubkey, displayName: $displayName, nip05: $nip05, picture: $picture, about: $about)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PostAuthorImpl &&
            (identical(other.pubkey, pubkey) || other.pubkey == pubkey) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.nip05, nip05) || other.nip05 == nip05) &&
            (identical(other.picture, picture) || other.picture == picture) &&
            (identical(other.about, about) || other.about == about));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, pubkey, displayName, nip05, picture, about);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PostAuthorImplCopyWith<_$PostAuthorImpl> get copyWith =>
      __$$PostAuthorImplCopyWithImpl<_$PostAuthorImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PostAuthorImplToJson(
      this,
    );
  }
}

abstract class _PostAuthor implements PostAuthor {
  const factory _PostAuthor(
      {required final String pubkey,
      required final String displayName,
      final String? nip05,
      final String? picture,
      final String? about}) = _$PostAuthorImpl;

  factory _PostAuthor.fromJson(Map<String, dynamic> json) =
      _$PostAuthorImpl.fromJson;

  @override

  /// Author's public key (32-byte hex string)
  String get pubkey;
  @override

  /// Display name (from kind:0 metadata, or truncated pubkey if not available)
  String get displayName;
  @override

  /// NIP-05 verification (e.g., alice@example.com)
  String? get nip05;
  @override

  /// Profile picture URL
  String? get picture;
  @override

  /// About/bio text
  String? get about;
  @override
  @JsonKey(ignore: true)
  _$$PostAuthorImplCopyWith<_$PostAuthorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
