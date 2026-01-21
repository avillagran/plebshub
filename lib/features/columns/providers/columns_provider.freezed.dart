// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'columns_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ColumnsState {
  /// List of column configurations in display order.
  List<ColumnConfig> get columns => throw _privateConstructorUsedError;

  /// Whether edit mode is active (for reordering/removing columns).
  bool get isEditMode => throw _privateConstructorUsedError;

  /// Create a copy of ColumnsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ColumnsStateCopyWith<ColumnsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ColumnsStateCopyWith<$Res> {
  factory $ColumnsStateCopyWith(
          ColumnsState value, $Res Function(ColumnsState) then) =
      _$ColumnsStateCopyWithImpl<$Res, ColumnsState>;
  @useResult
  $Res call({List<ColumnConfig> columns, bool isEditMode});
}

/// @nodoc
class _$ColumnsStateCopyWithImpl<$Res, $Val extends ColumnsState>
    implements $ColumnsStateCopyWith<$Res> {
  _$ColumnsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ColumnsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? columns = null,
    Object? isEditMode = null,
  }) {
    return _then(_value.copyWith(
      columns: null == columns
          ? _value.columns
          : columns // ignore: cast_nullable_to_non_nullable
              as List<ColumnConfig>,
      isEditMode: null == isEditMode
          ? _value.isEditMode
          : isEditMode // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ColumnsStateImplCopyWith<$Res>
    implements $ColumnsStateCopyWith<$Res> {
  factory _$$ColumnsStateImplCopyWith(
          _$ColumnsStateImpl value, $Res Function(_$ColumnsStateImpl) then) =
      __$$ColumnsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<ColumnConfig> columns, bool isEditMode});
}

/// @nodoc
class __$$ColumnsStateImplCopyWithImpl<$Res>
    extends _$ColumnsStateCopyWithImpl<$Res, _$ColumnsStateImpl>
    implements _$$ColumnsStateImplCopyWith<$Res> {
  __$$ColumnsStateImplCopyWithImpl(
      _$ColumnsStateImpl _value, $Res Function(_$ColumnsStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ColumnsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? columns = null,
    Object? isEditMode = null,
  }) {
    return _then(_$ColumnsStateImpl(
      columns: null == columns
          ? _value._columns
          : columns // ignore: cast_nullable_to_non_nullable
              as List<ColumnConfig>,
      isEditMode: null == isEditMode
          ? _value.isEditMode
          : isEditMode // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$ColumnsStateImpl with DiagnosticableTreeMixin implements _ColumnsState {
  const _$ColumnsStateImpl(
      {final List<ColumnConfig> columns = const [], this.isEditMode = false})
      : _columns = columns;

  /// List of column configurations in display order.
  final List<ColumnConfig> _columns;

  /// List of column configurations in display order.
  @override
  @JsonKey()
  List<ColumnConfig> get columns {
    if (_columns is EqualUnmodifiableListView) return _columns;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_columns);
  }

  /// Whether edit mode is active (for reordering/removing columns).
  @override
  @JsonKey()
  final bool isEditMode;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'ColumnsState(columns: $columns, isEditMode: $isEditMode)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'ColumnsState'))
      ..add(DiagnosticsProperty('columns', columns))
      ..add(DiagnosticsProperty('isEditMode', isEditMode));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ColumnsStateImpl &&
            const DeepCollectionEquality().equals(other._columns, _columns) &&
            (identical(other.isEditMode, isEditMode) ||
                other.isEditMode == isEditMode));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_columns), isEditMode);

  /// Create a copy of ColumnsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ColumnsStateImplCopyWith<_$ColumnsStateImpl> get copyWith =>
      __$$ColumnsStateImplCopyWithImpl<_$ColumnsStateImpl>(this, _$identity);
}

abstract class _ColumnsState implements ColumnsState {
  const factory _ColumnsState(
      {final List<ColumnConfig> columns,
      final bool isEditMode}) = _$ColumnsStateImpl;

  /// List of column configurations in display order.
  @override
  List<ColumnConfig> get columns;

  /// Whether edit mode is active (for reordering/removing columns).
  @override
  bool get isEditMode;

  /// Create a copy of ColumnsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ColumnsStateImplCopyWith<_$ColumnsStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
