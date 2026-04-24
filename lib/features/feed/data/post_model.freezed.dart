// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Post {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'league_id') String? get leagueId;@JsonKey(name: 'image_url') String get imageUrl;@JsonKey(name: 'video_url') String? get videoUrl; String? get caption;@JsonKey(name: 'fish_type') String get fishType; double? get length;@JsonKey(name: 'lure_type') String? get lureType; double? get depth; double? get temperature; String? get location; double? get lat; double? get lng; double? get weight;@JsonKey(name: 'catch_count') int get catchCount;@JsonKey(name: 'is_lunker') bool get isLunker;@JsonKey(name: 'is_personal_record') bool get isPersonalRecord;@JsonKey(name: 'created_at') DateTime get createdAt;// Joined user data (can be populated after fetch)
@JsonKey(includeFromJson: false, includeToJson: false) String get username;@JsonKey(includeFromJson: false, includeToJson: false) int get likesCount;@JsonKey(includeFromJson: false, includeToJson: false) int get commentsCount;@JsonKey(includeFromJson: false, includeToJson: false) String get avatarUrl;
/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostCopyWith<Post> get copyWith => _$PostCopyWithImpl<Post>(this as Post, _$identity);

  /// Serializes this Post to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Post&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.leagueId, leagueId) || other.leagueId == leagueId)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.caption, caption) || other.caption == caption)&&(identical(other.fishType, fishType) || other.fishType == fishType)&&(identical(other.length, length) || other.length == length)&&(identical(other.lureType, lureType) || other.lureType == lureType)&&(identical(other.depth, depth) || other.depth == depth)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.location, location) || other.location == location)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.weight, weight) || other.weight == weight)&&(identical(other.catchCount, catchCount) || other.catchCount == catchCount)&&(identical(other.isLunker, isLunker) || other.isLunker == isLunker)&&(identical(other.isPersonalRecord, isPersonalRecord) || other.isPersonalRecord == isPersonalRecord)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.username, username) || other.username == username)&&(identical(other.likesCount, likesCount) || other.likesCount == likesCount)&&(identical(other.commentsCount, commentsCount) || other.commentsCount == commentsCount)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,leagueId,imageUrl,videoUrl,caption,fishType,length,lureType,depth,temperature,location,lat,lng,weight,catchCount,isLunker,isPersonalRecord,createdAt,username,likesCount,commentsCount,avatarUrl]);

@override
String toString() {
  return 'Post(id: $id, userId: $userId, leagueId: $leagueId, imageUrl: $imageUrl, videoUrl: $videoUrl, caption: $caption, fishType: $fishType, length: $length, lureType: $lureType, depth: $depth, temperature: $temperature, location: $location, lat: $lat, lng: $lng, weight: $weight, catchCount: $catchCount, isLunker: $isLunker, isPersonalRecord: $isPersonalRecord, createdAt: $createdAt, username: $username, likesCount: $likesCount, commentsCount: $commentsCount, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class $PostCopyWith<$Res>  {
  factory $PostCopyWith(Post value, $Res Function(Post) _then) = _$PostCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'league_id') String? leagueId,@JsonKey(name: 'image_url') String imageUrl,@JsonKey(name: 'video_url') String? videoUrl, String? caption,@JsonKey(name: 'fish_type') String fishType, double? length,@JsonKey(name: 'lure_type') String? lureType, double? depth, double? temperature, String? location, double? lat, double? lng, double? weight,@JsonKey(name: 'catch_count') int catchCount,@JsonKey(name: 'is_lunker') bool isLunker,@JsonKey(name: 'is_personal_record') bool isPersonalRecord,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(includeFromJson: false, includeToJson: false) String username,@JsonKey(includeFromJson: false, includeToJson: false) int likesCount,@JsonKey(includeFromJson: false, includeToJson: false) int commentsCount,@JsonKey(includeFromJson: false, includeToJson: false) String avatarUrl
});




}
/// @nodoc
class _$PostCopyWithImpl<$Res>
    implements $PostCopyWith<$Res> {
  _$PostCopyWithImpl(this._self, this._then);

  final Post _self;
  final $Res Function(Post) _then;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? leagueId = freezed,Object? imageUrl = null,Object? videoUrl = freezed,Object? caption = freezed,Object? fishType = null,Object? length = freezed,Object? lureType = freezed,Object? depth = freezed,Object? temperature = freezed,Object? location = freezed,Object? lat = freezed,Object? lng = freezed,Object? weight = freezed,Object? catchCount = null,Object? isLunker = null,Object? isPersonalRecord = null,Object? createdAt = null,Object? username = null,Object? likesCount = null,Object? commentsCount = null,Object? avatarUrl = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,leagueId: freezed == leagueId ? _self.leagueId : leagueId // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,videoUrl: freezed == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String?,caption: freezed == caption ? _self.caption : caption // ignore: cast_nullable_to_non_nullable
as String?,fishType: null == fishType ? _self.fishType : fishType // ignore: cast_nullable_to_non_nullable
as String,length: freezed == length ? _self.length : length // ignore: cast_nullable_to_non_nullable
as double?,lureType: freezed == lureType ? _self.lureType : lureType // ignore: cast_nullable_to_non_nullable
as String?,depth: freezed == depth ? _self.depth : depth // ignore: cast_nullable_to_non_nullable
as double?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,weight: freezed == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as double?,catchCount: null == catchCount ? _self.catchCount : catchCount // ignore: cast_nullable_to_non_nullable
as int,isLunker: null == isLunker ? _self.isLunker : isLunker // ignore: cast_nullable_to_non_nullable
as bool,isPersonalRecord: null == isPersonalRecord ? _self.isPersonalRecord : isPersonalRecord // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,likesCount: null == likesCount ? _self.likesCount : likesCount // ignore: cast_nullable_to_non_nullable
as int,commentsCount: null == commentsCount ? _self.commentsCount : commentsCount // ignore: cast_nullable_to_non_nullable
as int,avatarUrl: null == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Post].
extension PostPatterns on Post {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Post value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Post() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Post value)  $default,){
final _that = this;
switch (_that) {
case _Post():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Post value)?  $default,){
final _that = this;
switch (_that) {
case _Post() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'league_id')  String? leagueId, @JsonKey(name: 'image_url')  String imageUrl, @JsonKey(name: 'video_url')  String? videoUrl,  String? caption, @JsonKey(name: 'fish_type')  String fishType,  double? length, @JsonKey(name: 'lure_type')  String? lureType,  double? depth,  double? temperature,  String? location,  double? lat,  double? lng,  double? weight, @JsonKey(name: 'catch_count')  int catchCount, @JsonKey(name: 'is_lunker')  bool isLunker, @JsonKey(name: 'is_personal_record')  bool isPersonalRecord, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(includeFromJson: false, includeToJson: false)  String username, @JsonKey(includeFromJson: false, includeToJson: false)  int likesCount, @JsonKey(includeFromJson: false, includeToJson: false)  int commentsCount, @JsonKey(includeFromJson: false, includeToJson: false)  String avatarUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.userId,_that.leagueId,_that.imageUrl,_that.videoUrl,_that.caption,_that.fishType,_that.length,_that.lureType,_that.depth,_that.temperature,_that.location,_that.lat,_that.lng,_that.weight,_that.catchCount,_that.isLunker,_that.isPersonalRecord,_that.createdAt,_that.username,_that.likesCount,_that.commentsCount,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'league_id')  String? leagueId, @JsonKey(name: 'image_url')  String imageUrl, @JsonKey(name: 'video_url')  String? videoUrl,  String? caption, @JsonKey(name: 'fish_type')  String fishType,  double? length, @JsonKey(name: 'lure_type')  String? lureType,  double? depth,  double? temperature,  String? location,  double? lat,  double? lng,  double? weight, @JsonKey(name: 'catch_count')  int catchCount, @JsonKey(name: 'is_lunker')  bool isLunker, @JsonKey(name: 'is_personal_record')  bool isPersonalRecord, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(includeFromJson: false, includeToJson: false)  String username, @JsonKey(includeFromJson: false, includeToJson: false)  int likesCount, @JsonKey(includeFromJson: false, includeToJson: false)  int commentsCount, @JsonKey(includeFromJson: false, includeToJson: false)  String avatarUrl)  $default,) {final _that = this;
switch (_that) {
case _Post():
return $default(_that.id,_that.userId,_that.leagueId,_that.imageUrl,_that.videoUrl,_that.caption,_that.fishType,_that.length,_that.lureType,_that.depth,_that.temperature,_that.location,_that.lat,_that.lng,_that.weight,_that.catchCount,_that.isLunker,_that.isPersonalRecord,_that.createdAt,_that.username,_that.likesCount,_that.commentsCount,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'league_id')  String? leagueId, @JsonKey(name: 'image_url')  String imageUrl, @JsonKey(name: 'video_url')  String? videoUrl,  String? caption, @JsonKey(name: 'fish_type')  String fishType,  double? length, @JsonKey(name: 'lure_type')  String? lureType,  double? depth,  double? temperature,  String? location,  double? lat,  double? lng,  double? weight, @JsonKey(name: 'catch_count')  int catchCount, @JsonKey(name: 'is_lunker')  bool isLunker, @JsonKey(name: 'is_personal_record')  bool isPersonalRecord, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(includeFromJson: false, includeToJson: false)  String username, @JsonKey(includeFromJson: false, includeToJson: false)  int likesCount, @JsonKey(includeFromJson: false, includeToJson: false)  int commentsCount, @JsonKey(includeFromJson: false, includeToJson: false)  String avatarUrl)?  $default,) {final _that = this;
switch (_that) {
case _Post() when $default != null:
return $default(_that.id,_that.userId,_that.leagueId,_that.imageUrl,_that.videoUrl,_that.caption,_that.fishType,_that.length,_that.lureType,_that.depth,_that.temperature,_that.location,_that.lat,_that.lng,_that.weight,_that.catchCount,_that.isLunker,_that.isPersonalRecord,_that.createdAt,_that.username,_that.likesCount,_that.commentsCount,_that.avatarUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Post implements Post {
  const _Post({required this.id, @JsonKey(name: 'user_id') required this.userId, @JsonKey(name: 'league_id') this.leagueId, @JsonKey(name: 'image_url') required this.imageUrl, @JsonKey(name: 'video_url') this.videoUrl, this.caption, @JsonKey(name: 'fish_type') this.fishType = '배스', this.length, @JsonKey(name: 'lure_type') this.lureType, this.depth, this.temperature, this.location, this.lat, this.lng, this.weight, @JsonKey(name: 'catch_count') this.catchCount = 1, @JsonKey(name: 'is_lunker') this.isLunker = false, @JsonKey(name: 'is_personal_record') this.isPersonalRecord = false, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(includeFromJson: false, includeToJson: false) this.username = 'Unknown', @JsonKey(includeFromJson: false, includeToJson: false) this.likesCount = 0, @JsonKey(includeFromJson: false, includeToJson: false) this.commentsCount = 0, @JsonKey(includeFromJson: false, includeToJson: false) this.avatarUrl = ''});
  factory _Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

@override final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'league_id') final  String? leagueId;
@override@JsonKey(name: 'image_url') final  String imageUrl;
@override@JsonKey(name: 'video_url') final  String? videoUrl;
@override final  String? caption;
@override@JsonKey(name: 'fish_type') final  String fishType;
@override final  double? length;
@override@JsonKey(name: 'lure_type') final  String? lureType;
@override final  double? depth;
@override final  double? temperature;
@override final  String? location;
@override final  double? lat;
@override final  double? lng;
@override final  double? weight;
@override@JsonKey(name: 'catch_count') final  int catchCount;
@override@JsonKey(name: 'is_lunker') final  bool isLunker;
@override@JsonKey(name: 'is_personal_record') final  bool isPersonalRecord;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
// Joined user data (can be populated after fetch)
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String username;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  int likesCount;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  int commentsCount;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String avatarUrl;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostCopyWith<_Post> get copyWith => __$PostCopyWithImpl<_Post>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PostToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Post&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.leagueId, leagueId) || other.leagueId == leagueId)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.caption, caption) || other.caption == caption)&&(identical(other.fishType, fishType) || other.fishType == fishType)&&(identical(other.length, length) || other.length == length)&&(identical(other.lureType, lureType) || other.lureType == lureType)&&(identical(other.depth, depth) || other.depth == depth)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.location, location) || other.location == location)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.weight, weight) || other.weight == weight)&&(identical(other.catchCount, catchCount) || other.catchCount == catchCount)&&(identical(other.isLunker, isLunker) || other.isLunker == isLunker)&&(identical(other.isPersonalRecord, isPersonalRecord) || other.isPersonalRecord == isPersonalRecord)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.username, username) || other.username == username)&&(identical(other.likesCount, likesCount) || other.likesCount == likesCount)&&(identical(other.commentsCount, commentsCount) || other.commentsCount == commentsCount)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,leagueId,imageUrl,videoUrl,caption,fishType,length,lureType,depth,temperature,location,lat,lng,weight,catchCount,isLunker,isPersonalRecord,createdAt,username,likesCount,commentsCount,avatarUrl]);

@override
String toString() {
  return 'Post(id: $id, userId: $userId, leagueId: $leagueId, imageUrl: $imageUrl, videoUrl: $videoUrl, caption: $caption, fishType: $fishType, length: $length, lureType: $lureType, depth: $depth, temperature: $temperature, location: $location, lat: $lat, lng: $lng, weight: $weight, catchCount: $catchCount, isLunker: $isLunker, isPersonalRecord: $isPersonalRecord, createdAt: $createdAt, username: $username, likesCount: $likesCount, commentsCount: $commentsCount, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class _$PostCopyWith<$Res> implements $PostCopyWith<$Res> {
  factory _$PostCopyWith(_Post value, $Res Function(_Post) _then) = __$PostCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'league_id') String? leagueId,@JsonKey(name: 'image_url') String imageUrl,@JsonKey(name: 'video_url') String? videoUrl, String? caption,@JsonKey(name: 'fish_type') String fishType, double? length,@JsonKey(name: 'lure_type') String? lureType, double? depth, double? temperature, String? location, double? lat, double? lng, double? weight,@JsonKey(name: 'catch_count') int catchCount,@JsonKey(name: 'is_lunker') bool isLunker,@JsonKey(name: 'is_personal_record') bool isPersonalRecord,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(includeFromJson: false, includeToJson: false) String username,@JsonKey(includeFromJson: false, includeToJson: false) int likesCount,@JsonKey(includeFromJson: false, includeToJson: false) int commentsCount,@JsonKey(includeFromJson: false, includeToJson: false) String avatarUrl
});




}
/// @nodoc
class __$PostCopyWithImpl<$Res>
    implements _$PostCopyWith<$Res> {
  __$PostCopyWithImpl(this._self, this._then);

  final _Post _self;
  final $Res Function(_Post) _then;

/// Create a copy of Post
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? leagueId = freezed,Object? imageUrl = null,Object? videoUrl = freezed,Object? caption = freezed,Object? fishType = null,Object? length = freezed,Object? lureType = freezed,Object? depth = freezed,Object? temperature = freezed,Object? location = freezed,Object? lat = freezed,Object? lng = freezed,Object? weight = freezed,Object? catchCount = null,Object? isLunker = null,Object? isPersonalRecord = null,Object? createdAt = null,Object? username = null,Object? likesCount = null,Object? commentsCount = null,Object? avatarUrl = null,}) {
  return _then(_Post(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,leagueId: freezed == leagueId ? _self.leagueId : leagueId // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,videoUrl: freezed == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String?,caption: freezed == caption ? _self.caption : caption // ignore: cast_nullable_to_non_nullable
as String?,fishType: null == fishType ? _self.fishType : fishType // ignore: cast_nullable_to_non_nullable
as String,length: freezed == length ? _self.length : length // ignore: cast_nullable_to_non_nullable
as double?,lureType: freezed == lureType ? _self.lureType : lureType // ignore: cast_nullable_to_non_nullable
as String?,depth: freezed == depth ? _self.depth : depth // ignore: cast_nullable_to_non_nullable
as double?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,weight: freezed == weight ? _self.weight : weight // ignore: cast_nullable_to_non_nullable
as double?,catchCount: null == catchCount ? _self.catchCount : catchCount // ignore: cast_nullable_to_non_nullable
as int,isLunker: null == isLunker ? _self.isLunker : isLunker // ignore: cast_nullable_to_non_nullable
as bool,isPersonalRecord: null == isPersonalRecord ? _self.isPersonalRecord : isPersonalRecord // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,likesCount: null == likesCount ? _self.likesCount : likesCount // ignore: cast_nullable_to_non_nullable
as int,commentsCount: null == commentsCount ? _self.commentsCount : commentsCount // ignore: cast_nullable_to_non_nullable
as int,avatarUrl: null == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
