// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'verification_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VerificationRequest {

 String get id;@JsonKey(name: 'post_id') String get postId;@JsonKey(name: 'submitter_id') String get submitterId; String get status;@JsonKey(name: 'approve_count') int get approveCount;@JsonKey(name: 'reject_count') int get rejectCount;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'resolved_at') DateTime? get resolvedAt;// joined fields - not serialized from DB
@JsonKey(includeFromJson: false, includeToJson: false) String get imageUrl;@JsonKey(includeFromJson: false, includeToJson: false) String get submitterName;@JsonKey(includeFromJson: false, includeToJson: false) String get submitterAvatar;@JsonKey(includeFromJson: false, includeToJson: false) String get fishType;@JsonKey(includeFromJson: false, includeToJson: false) double? get length;@JsonKey(includeFromJson: false, includeToJson: false) double? get weight;@JsonKey(includeFromJson: false, includeToJson: false) String? get location;@JsonKey(includeFromJson: false, includeToJson: false) String? get myVote;
/// Create a copy of VerificationRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VerificationRequestCopyWith<VerificationRequest> get copyWith => _$VerificationRequestCopyWithImpl<VerificationRequest>(this as VerificationRequest, _$identity);

  /// Serializes this VerificationRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VerificationRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.postId, postId) || other.postId == postId)&&(identical(other.submitterId, submitterId) || other.submitterId == submitterId)&&(identical(other.status, status) || other.status == status)&&(identical(other.approveCount, approveCount) || other.approveCount == approveCount)&&(identical(other.rejectCount, rejectCount) || other.rejectCount == rejectCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.submitterName, submitterName) || other.submitterName == submitterName)&&(identical(other.submitterAvatar, submitterAvatar) || other.submitterAvatar == submitterAvatar)&&(identical(other.fishType, fishType) || other.fishType == fishType)&&(identical(other.length, length) || other.length == length)&&(identical(other.weight, weight) || other.weight == weight)&&(identical(other.location, location) || other.location == location)&&(identical(other.myVote, myVote) || other.myVote == myVote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,postId,submitterId,status,approveCount,rejectCount,createdAt,resolvedAt,imageUrl,submitterName,submitterAvatar,fishType,length,weight,location,myVote);

@override
String toString() {
  return 'VerificationRequest(id: $id, postId: $postId, submitterId: $submitterId, status: $status, approveCount: $approveCount, rejectCount: $rejectCount, createdAt: $createdAt, resolvedAt: $resolvedAt, imageUrl: $imageUrl, submitterName: $submitterName, submitterAvatar: $submitterAvatar, fishType: $fishType, length: $length, weight: $weight, location: $location, myVote: $myVote)';
}


}

/// @nodoc
abstract mixin class $VerificationRequestCopyWith<$Res>  {
  factory $VerificationRequestCopyWith(VerificationRequest value, $Res Function(VerificationRequest) _then) = _$VerificationRequestCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'post_id') String postId,@JsonKey(name: 'submitter_id') String submitterId, String status,@JsonKey(name: 'approve_count') int approveCount,@JsonKey(name: 'reject_count') int rejectCount,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'resolved_at') DateTime? resolvedAt,@JsonKey(includeFromJson: false, includeToJson: false) String imageUrl,@JsonKey(includeFromJson: false, includeToJson: false) String submitterName,@JsonKey(includeFromJson: false, includeToJson: false) String submitterAvatar,@JsonKey(includeFromJson: false, includeToJson: false) String fishType,@JsonKey(includeFromJson: false, includeToJson: false) double? length,@JsonKey(includeFromJson: false, includeToJson: false) double? weight,@JsonKey(includeFromJson: false, includeToJson: false) String? location,@JsonKey(includeFromJson: false, includeToJson: false) String? myVote
});




}
/// @nodoc
class _$VerificationRequestCopyWithImpl<$Res>
    implements $VerificationRequestCopyWith<$Res> {
  _$VerificationRequestCopyWithImpl(this._self, this._then);

  final VerificationRequest _self;
  final $Res Function(VerificationRequest) _then;

/// Create a copy of VerificationRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? postId = null,Object? submitterId = null,Object? status = null,Object? approveCount = null,Object? rejectCount = null,Object? createdAt = null,Object? resolvedAt = freezed,Object? imageUrl = null,Object? submitterName = null,Object? submitterAvatar = null,Object? fishType = null,Object? length = freezed,Object? weight = freezed,Object? location = freezed,Object? myVote = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,postId: null == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String,submitterId: null == submitterId ? _self.submitterId : submitterId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,approveCount: null == approveCount ? _self.approveCount : approveCount // ignore: cast_nullable_to_non_nullable
as int,rejectCount: null == rejectCount ? _self.rejectCount : rejectCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,submitterName: null == submitterName ? _self.submitterName : submitterName // ignore: cast_nullable_to_non_nullable
as String,submitterAvatar: null == submitterAvatar ? _self.submitterAvatar : submitterAvatar // ignore: cast_nullable_to_non_nullable
as String,fishType: null == fishType ? _self.fishType : fishType // ignore: cast_nullable_to_non_nullable
as String,length: freezed == length ? _self.length : length // ignore: cast_nullable_to_non_nullable
as double?,weight: freezed == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as double?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,myVote: freezed == myVote ? _self.myVote : myVote // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VerificationRequest].
extension VerificationRequestPatterns on VerificationRequest {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VerificationRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VerificationRequest() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VerificationRequest value)  $default,){
final _that = this;
switch (_that) {
case _VerificationRequest():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VerificationRequest value)?  $default,){
final _that = this;
switch (_that) {
case _VerificationRequest() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'post_id')  String postId, @JsonKey(name: 'submitter_id')  String submitterId,  String status, @JsonKey(name: 'approve_count')  int approveCount, @JsonKey(name: 'reject_count')  int rejectCount, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'resolved_at')  DateTime? resolvedAt, @JsonKey(includeFromJson: false, includeToJson: false)  String imageUrl, @JsonKey(includeFromJson: false, includeToJson: false)  String submitterName, @JsonKey(includeFromJson: false, includeToJson: false)  String submitterAvatar, @JsonKey(includeFromJson: false, includeToJson: false)  String fishType, @JsonKey(includeFromJson: false, includeToJson: false)  double? length, @JsonKey(includeFromJson: false, includeToJson: false)  double? weight, @JsonKey(includeFromJson: false, includeToJson: false)  String? location, @JsonKey(includeFromJson: false, includeToJson: false)  String? myVote)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VerificationRequest() when $default != null:
return $default(_that.id,_that.postId,_that.submitterId,_that.status,_that.approveCount,_that.rejectCount,_that.createdAt,_that.resolvedAt,_that.imageUrl,_that.submitterName,_that.submitterAvatar,_that.fishType,_that.length,_that.weight,_that.location,_that.myVote);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'post_id')  String postId, @JsonKey(name: 'submitter_id')  String submitterId,  String status, @JsonKey(name: 'approve_count')  int approveCount, @JsonKey(name: 'reject_count')  int rejectCount, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'resolved_at')  DateTime? resolvedAt, @JsonKey(includeFromJson: false, includeToJson: false)  String imageUrl, @JsonKey(includeFromJson: false, includeToJson: false)  String submitterName, @JsonKey(includeFromJson: false, includeToJson: false)  String submitterAvatar, @JsonKey(includeFromJson: false, includeToJson: false)  String fishType, @JsonKey(includeFromJson: false, includeToJson: false)  double? length, @JsonKey(includeFromJson: false, includeToJson: false)  double? weight, @JsonKey(includeFromJson: false, includeToJson: false)  String? location, @JsonKey(includeFromJson: false, includeToJson: false)  String? myVote)  $default,) {final _that = this;
switch (_that) {
case _VerificationRequest():
return $default(_that.id,_that.postId,_that.submitterId,_that.status,_that.approveCount,_that.rejectCount,_that.createdAt,_that.resolvedAt,_that.imageUrl,_that.submitterName,_that.submitterAvatar,_that.fishType,_that.length,_that.weight,_that.location,_that.myVote);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'post_id')  String postId, @JsonKey(name: 'submitter_id')  String submitterId,  String status, @JsonKey(name: 'approve_count')  int approveCount, @JsonKey(name: 'reject_count')  int rejectCount, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'resolved_at')  DateTime? resolvedAt, @JsonKey(includeFromJson: false, includeToJson: false)  String imageUrl, @JsonKey(includeFromJson: false, includeToJson: false)  String submitterName, @JsonKey(includeFromJson: false, includeToJson: false)  String submitterAvatar, @JsonKey(includeFromJson: false, includeToJson: false)  String fishType, @JsonKey(includeFromJson: false, includeToJson: false)  double? length, @JsonKey(includeFromJson: false, includeToJson: false)  double? weight, @JsonKey(includeFromJson: false, includeToJson: false)  String? location, @JsonKey(includeFromJson: false, includeToJson: false)  String? myVote)?  $default,) {final _that = this;
switch (_that) {
case _VerificationRequest() when $default != null:
return $default(_that.id,_that.postId,_that.submitterId,_that.status,_that.approveCount,_that.rejectCount,_that.createdAt,_that.resolvedAt,_that.imageUrl,_that.submitterName,_that.submitterAvatar,_that.fishType,_that.length,_that.weight,_that.location,_that.myVote);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VerificationRequest implements VerificationRequest {
  const _VerificationRequest({required this.id, @JsonKey(name: 'post_id') required this.postId, @JsonKey(name: 'submitter_id') required this.submitterId, required this.status, @JsonKey(name: 'approve_count') this.approveCount = 0, @JsonKey(name: 'reject_count') this.rejectCount = 0, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'resolved_at') this.resolvedAt, @JsonKey(includeFromJson: false, includeToJson: false) this.imageUrl = '', @JsonKey(includeFromJson: false, includeToJson: false) this.submitterName = '', @JsonKey(includeFromJson: false, includeToJson: false) this.submitterAvatar = '', @JsonKey(includeFromJson: false, includeToJson: false) this.fishType = '배스', @JsonKey(includeFromJson: false, includeToJson: false) this.length, @JsonKey(includeFromJson: false, includeToJson: false) this.weight, @JsonKey(includeFromJson: false, includeToJson: false) this.location, @JsonKey(includeFromJson: false, includeToJson: false) this.myVote});
  factory _VerificationRequest.fromJson(Map<String, dynamic> json) => _$VerificationRequestFromJson(json);

@override final  String id;
@override@JsonKey(name: 'post_id') final  String postId;
@override@JsonKey(name: 'submitter_id') final  String submitterId;
@override final  String status;
@override@JsonKey(name: 'approve_count') final  int approveCount;
@override@JsonKey(name: 'reject_count') final  int rejectCount;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'resolved_at') final  DateTime? resolvedAt;
// joined fields - not serialized from DB
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String imageUrl;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String submitterName;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String submitterAvatar;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String fishType;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  double? length;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  double? weight;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? location;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? myVote;

/// Create a copy of VerificationRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerificationRequestCopyWith<_VerificationRequest> get copyWith => __$VerificationRequestCopyWithImpl<_VerificationRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VerificationRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerificationRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.postId, postId) || other.postId == postId)&&(identical(other.submitterId, submitterId) || other.submitterId == submitterId)&&(identical(other.status, status) || other.status == status)&&(identical(other.approveCount, approveCount) || other.approveCount == approveCount)&&(identical(other.rejectCount, rejectCount) || other.rejectCount == rejectCount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.resolvedAt, resolvedAt) || other.resolvedAt == resolvedAt)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.submitterName, submitterName) || other.submitterName == submitterName)&&(identical(other.submitterAvatar, submitterAvatar) || other.submitterAvatar == submitterAvatar)&&(identical(other.fishType, fishType) || other.fishType == fishType)&&(identical(other.length, length) || other.length == length)&&(identical(other.weight, weight) || other.weight == weight)&&(identical(other.location, location) || other.location == location)&&(identical(other.myVote, myVote) || other.myVote == myVote));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,postId,submitterId,status,approveCount,rejectCount,createdAt,resolvedAt,imageUrl,submitterName,submitterAvatar,fishType,length,weight,location,myVote);

@override
String toString() {
  return 'VerificationRequest(id: $id, postId: $postId, submitterId: $submitterId, status: $status, approveCount: $approveCount, rejectCount: $rejectCount, createdAt: $createdAt, resolvedAt: $resolvedAt, imageUrl: $imageUrl, submitterName: $submitterName, submitterAvatar: $submitterAvatar, fishType: $fishType, length: $length, weight: $weight, location: $location, myVote: $myVote)';
}


}

/// @nodoc
abstract mixin class _$VerificationRequestCopyWith<$Res> implements $VerificationRequestCopyWith<$Res> {
  factory _$VerificationRequestCopyWith(_VerificationRequest value, $Res Function(_VerificationRequest) _then) = __$VerificationRequestCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'post_id') String postId,@JsonKey(name: 'submitter_id') String submitterId, String status,@JsonKey(name: 'approve_count') int approveCount,@JsonKey(name: 'reject_count') int rejectCount,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'resolved_at') DateTime? resolvedAt,@JsonKey(includeFromJson: false, includeToJson: false) String imageUrl,@JsonKey(includeFromJson: false, includeToJson: false) String submitterName,@JsonKey(includeFromJson: false, includeToJson: false) String submitterAvatar,@JsonKey(includeFromJson: false, includeToJson: false) String fishType,@JsonKey(includeFromJson: false, includeToJson: false) double? length,@JsonKey(includeFromJson: false, includeToJson: false) double? weight,@JsonKey(includeFromJson: false, includeToJson: false) String? location,@JsonKey(includeFromJson: false, includeToJson: false) String? myVote
});




}
/// @nodoc
class __$VerificationRequestCopyWithImpl<$Res>
    implements _$VerificationRequestCopyWith<$Res> {
  __$VerificationRequestCopyWithImpl(this._self, this._then);

  final _VerificationRequest _self;
  final $Res Function(_VerificationRequest) _then;

/// Create a copy of VerificationRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? postId = null,Object? submitterId = null,Object? status = null,Object? approveCount = null,Object? rejectCount = null,Object? createdAt = null,Object? resolvedAt = freezed,Object? imageUrl = null,Object? submitterName = null,Object? submitterAvatar = null,Object? fishType = null,Object? length = freezed,Object? weight = freezed,Object? location = freezed,Object? myVote = freezed,}) {
  return _then(_VerificationRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,postId: null == postId ? _self.postId : postId // ignore: cast_nullable_to_non_nullable
as String,submitterId: null == submitterId ? _self.submitterId : submitterId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,approveCount: null == approveCount ? _self.approveCount : approveCount // ignore: cast_nullable_to_non_nullable
as int,rejectCount: null == rejectCount ? _self.rejectCount : rejectCount // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,resolvedAt: freezed == resolvedAt ? _self.resolvedAt : resolvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,submitterName: null == submitterName ? _self.submitterName : submitterName // ignore: cast_nullable_to_non_nullable
as String,submitterAvatar: null == submitterAvatar ? _self.submitterAvatar : submitterAvatar // ignore: cast_nullable_to_non_nullable
as String,fishType: null == fishType ? _self.fishType : fishType // ignore: cast_nullable_to_non_nullable
as String,length: freezed == length ? _self.length : length // ignore: cast_nullable_to_non_nullable
as double?,weight: freezed == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as double?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,myVote: freezed == myVote ? _self.myVote : myVote // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
