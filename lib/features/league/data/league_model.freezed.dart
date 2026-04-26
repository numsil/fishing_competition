// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'league_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$League {

 String get id;@JsonKey(name: 'host_id') String get hostId; String get title; String? get description;@JsonKey(name: 'short_description') String? get shortDescription; String get location; double? get lat; double? get lng;@JsonKey(name: 'start_time') DateTime get startTime;@JsonKey(name: 'end_time') DateTime get endTime;@JsonKey(name: 'entry_fee') int get entryFee;@JsonKey(name: 'max_participants') int get maxParticipants; String get status;@JsonKey(name: 'fish_types') String get fishTypes; String get rule;@JsonKey(name: 'catch_limit') int get catchLimit;@JsonKey(name: 'prize_info') String? get prizeInfo;@JsonKey(name: 'is_public') bool get isPublic;@JsonKey(name: 'allow_gallery') bool get allowGallery;@JsonKey(name: 'intro_image_urls') List<String> get introImageUrls;@JsonKey(name: 'created_at') DateTime get createdAt;// 조인된 데이터
@JsonKey(includeFromJson: false, includeToJson: false) int get participantsCount;
/// Create a copy of League
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LeagueCopyWith<League> get copyWith => _$LeagueCopyWithImpl<League>(this as League, _$identity);

  /// Serializes this League to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is League&&(identical(other.id, id) || other.id == id)&&(identical(other.hostId, hostId) || other.hostId == hostId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.shortDescription, shortDescription) || other.shortDescription == shortDescription)&&(identical(other.location, location) || other.location == location)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.entryFee, entryFee) || other.entryFee == entryFee)&&(identical(other.maxParticipants, maxParticipants) || other.maxParticipants == maxParticipants)&&(identical(other.status, status) || other.status == status)&&(identical(other.fishTypes, fishTypes) || other.fishTypes == fishTypes)&&(identical(other.rule, rule) || other.rule == rule)&&(identical(other.catchLimit, catchLimit) || other.catchLimit == catchLimit)&&(identical(other.prizeInfo, prizeInfo) || other.prizeInfo == prizeInfo)&&(identical(other.isPublic, isPublic) || other.isPublic == isPublic)&&(identical(other.allowGallery, allowGallery) || other.allowGallery == allowGallery)&&const DeepCollectionEquality().equals(other.introImageUrls, introImageUrls)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.participantsCount, participantsCount) || other.participantsCount == participantsCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,hostId,title,description,shortDescription,location,lat,lng,startTime,endTime,entryFee,maxParticipants,status,fishTypes,rule,catchLimit,prizeInfo,isPublic,allowGallery,const DeepCollectionEquality().hash(introImageUrls),createdAt,participantsCount]);

@override
String toString() {
  return 'League(id: $id, hostId: $hostId, title: $title, description: $description, shortDescription: $shortDescription, location: $location, lat: $lat, lng: $lng, startTime: $startTime, endTime: $endTime, entryFee: $entryFee, maxParticipants: $maxParticipants, status: $status, fishTypes: $fishTypes, rule: $rule, catchLimit: $catchLimit, prizeInfo: $prizeInfo, isPublic: $isPublic, allowGallery: $allowGallery, introImageUrls: $introImageUrls, createdAt: $createdAt, participantsCount: $participantsCount)';
}


}

/// @nodoc
abstract mixin class $LeagueCopyWith<$Res>  {
  factory $LeagueCopyWith(League value, $Res Function(League) _then) = _$LeagueCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'host_id') String hostId, String title, String? description,@JsonKey(name: 'short_description') String? shortDescription, String location, double? lat, double? lng,@JsonKey(name: 'start_time') DateTime startTime,@JsonKey(name: 'end_time') DateTime endTime,@JsonKey(name: 'entry_fee') int entryFee,@JsonKey(name: 'max_participants') int maxParticipants, String status,@JsonKey(name: 'fish_types') String fishTypes, String rule,@JsonKey(name: 'catch_limit') int catchLimit,@JsonKey(name: 'prize_info') String? prizeInfo,@JsonKey(name: 'is_public') bool isPublic,@JsonKey(name: 'allow_gallery') bool allowGallery,@JsonKey(name: 'intro_image_urls') List<String> introImageUrls,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(includeFromJson: false, includeToJson: false) int participantsCount
});




}
/// @nodoc
class _$LeagueCopyWithImpl<$Res>
    implements $LeagueCopyWith<$Res> {
  _$LeagueCopyWithImpl(this._self, this._then);

  final League _self;
  final $Res Function(League) _then;

/// Create a copy of League
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? hostId = null,Object? title = null,Object? description = freezed,Object? shortDescription = freezed,Object? location = null,Object? lat = freezed,Object? lng = freezed,Object? startTime = null,Object? endTime = null,Object? entryFee = null,Object? maxParticipants = null,Object? status = null,Object? fishTypes = null,Object? rule = null,Object? catchLimit = null,Object? prizeInfo = freezed,Object? isPublic = null,Object? allowGallery = null,Object? introImageUrls = null,Object? createdAt = null,Object? participantsCount = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,shortDescription: freezed == shortDescription ? _self.shortDescription : shortDescription // ignore: cast_nullable_to_non_nullable
as String?,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as DateTime,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as DateTime,entryFee: null == entryFee ? _self.entryFee : entryFee // ignore: cast_nullable_to_non_nullable
as int,maxParticipants: null == maxParticipants ? _self.maxParticipants : maxParticipants // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,fishTypes: null == fishTypes ? _self.fishTypes : fishTypes // ignore: cast_nullable_to_non_nullable
as String,rule: null == rule ? _self.rule : rule // ignore: cast_nullable_to_non_nullable
as String,catchLimit: null == catchLimit ? _self.catchLimit : catchLimit // ignore: cast_nullable_to_non_nullable
as int,prizeInfo: freezed == prizeInfo ? _self.prizeInfo : prizeInfo // ignore: cast_nullable_to_non_nullable
as String?,isPublic: null == isPublic ? _self.isPublic : isPublic // ignore: cast_nullable_to_non_nullable
as bool,allowGallery: null == allowGallery ? _self.allowGallery : allowGallery // ignore: cast_nullable_to_non_nullable
as bool,introImageUrls: null == introImageUrls ? _self.introImageUrls : introImageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,participantsCount: null == participantsCount ? _self.participantsCount : participantsCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [League].
extension LeaguePatterns on League {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _League value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _League() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _League value)  $default,){
final _that = this;
switch (_that) {
case _League():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _League value)?  $default,){
final _that = this;
switch (_that) {
case _League() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'host_id')  String hostId,  String title,  String? description, @JsonKey(name: 'short_description')  String? shortDescription,  String location,  double? lat,  double? lng, @JsonKey(name: 'start_time')  DateTime startTime, @JsonKey(name: 'end_time')  DateTime endTime, @JsonKey(name: 'entry_fee')  int entryFee, @JsonKey(name: 'max_participants')  int maxParticipants,  String status, @JsonKey(name: 'fish_types')  String fishTypes,  String rule, @JsonKey(name: 'catch_limit')  int catchLimit, @JsonKey(name: 'prize_info')  String? prizeInfo, @JsonKey(name: 'is_public')  bool isPublic, @JsonKey(name: 'allow_gallery')  bool allowGallery, @JsonKey(name: 'intro_image_urls')  List<String> introImageUrls, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(includeFromJson: false, includeToJson: false)  int participantsCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _League() when $default != null:
return $default(_that.id,_that.hostId,_that.title,_that.description,_that.shortDescription,_that.location,_that.lat,_that.lng,_that.startTime,_that.endTime,_that.entryFee,_that.maxParticipants,_that.status,_that.fishTypes,_that.rule,_that.catchLimit,_that.prizeInfo,_that.isPublic,_that.allowGallery,_that.introImageUrls,_that.createdAt,_that.participantsCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'host_id')  String hostId,  String title,  String? description, @JsonKey(name: 'short_description')  String? shortDescription,  String location,  double? lat,  double? lng, @JsonKey(name: 'start_time')  DateTime startTime, @JsonKey(name: 'end_time')  DateTime endTime, @JsonKey(name: 'entry_fee')  int entryFee, @JsonKey(name: 'max_participants')  int maxParticipants,  String status, @JsonKey(name: 'fish_types')  String fishTypes,  String rule, @JsonKey(name: 'catch_limit')  int catchLimit, @JsonKey(name: 'prize_info')  String? prizeInfo, @JsonKey(name: 'is_public')  bool isPublic, @JsonKey(name: 'allow_gallery')  bool allowGallery, @JsonKey(name: 'intro_image_urls')  List<String> introImageUrls, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(includeFromJson: false, includeToJson: false)  int participantsCount)  $default,) {final _that = this;
switch (_that) {
case _League():
return $default(_that.id,_that.hostId,_that.title,_that.description,_that.shortDescription,_that.location,_that.lat,_that.lng,_that.startTime,_that.endTime,_that.entryFee,_that.maxParticipants,_that.status,_that.fishTypes,_that.rule,_that.catchLimit,_that.prizeInfo,_that.isPublic,_that.allowGallery,_that.introImageUrls,_that.createdAt,_that.participantsCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'host_id')  String hostId,  String title,  String? description, @JsonKey(name: 'short_description')  String? shortDescription,  String location,  double? lat,  double? lng, @JsonKey(name: 'start_time')  DateTime startTime, @JsonKey(name: 'end_time')  DateTime endTime, @JsonKey(name: 'entry_fee')  int entryFee, @JsonKey(name: 'max_participants')  int maxParticipants,  String status, @JsonKey(name: 'fish_types')  String fishTypes,  String rule, @JsonKey(name: 'catch_limit')  int catchLimit, @JsonKey(name: 'prize_info')  String? prizeInfo, @JsonKey(name: 'is_public')  bool isPublic, @JsonKey(name: 'allow_gallery')  bool allowGallery, @JsonKey(name: 'intro_image_urls')  List<String> introImageUrls, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(includeFromJson: false, includeToJson: false)  int participantsCount)?  $default,) {final _that = this;
switch (_that) {
case _League() when $default != null:
return $default(_that.id,_that.hostId,_that.title,_that.description,_that.shortDescription,_that.location,_that.lat,_that.lng,_that.startTime,_that.endTime,_that.entryFee,_that.maxParticipants,_that.status,_that.fishTypes,_that.rule,_that.catchLimit,_that.prizeInfo,_that.isPublic,_that.allowGallery,_that.introImageUrls,_that.createdAt,_that.participantsCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _League implements League {
  const _League({required this.id, @JsonKey(name: 'host_id') required this.hostId, required this.title, this.description, @JsonKey(name: 'short_description') this.shortDescription, required this.location, this.lat, this.lng, @JsonKey(name: 'start_time') required this.startTime, @JsonKey(name: 'end_time') required this.endTime, @JsonKey(name: 'entry_fee') this.entryFee = 0, @JsonKey(name: 'max_participants') this.maxParticipants = 100, this.status = 'recruiting', @JsonKey(name: 'fish_types') this.fishTypes = '배스', this.rule = '최대어', @JsonKey(name: 'catch_limit') this.catchLimit = 1, @JsonKey(name: 'prize_info') this.prizeInfo, @JsonKey(name: 'is_public') this.isPublic = true, @JsonKey(name: 'allow_gallery') this.allowGallery = true, @JsonKey(name: 'intro_image_urls') final  List<String> introImageUrls = const [], @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(includeFromJson: false, includeToJson: false) this.participantsCount = 0}): _introImageUrls = introImageUrls;
  factory _League.fromJson(Map<String, dynamic> json) => _$LeagueFromJson(json);

@override final  String id;
@override@JsonKey(name: 'host_id') final  String hostId;
@override final  String title;
@override final  String? description;
@override@JsonKey(name: 'short_description') final  String? shortDescription;
@override final  String location;
@override final  double? lat;
@override final  double? lng;
@override@JsonKey(name: 'start_time') final  DateTime startTime;
@override@JsonKey(name: 'end_time') final  DateTime endTime;
@override@JsonKey(name: 'entry_fee') final  int entryFee;
@override@JsonKey(name: 'max_participants') final  int maxParticipants;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'fish_types') final  String fishTypes;
@override@JsonKey() final  String rule;
@override@JsonKey(name: 'catch_limit') final  int catchLimit;
@override@JsonKey(name: 'prize_info') final  String? prizeInfo;
@override@JsonKey(name: 'is_public') final  bool isPublic;
@override@JsonKey(name: 'allow_gallery') final  bool allowGallery;
 final  List<String> _introImageUrls;
@override@JsonKey(name: 'intro_image_urls') List<String> get introImageUrls {
  if (_introImageUrls is EqualUnmodifiableListView) return _introImageUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_introImageUrls);
}

@override@JsonKey(name: 'created_at') final  DateTime createdAt;
// 조인된 데이터
@override@JsonKey(includeFromJson: false, includeToJson: false) final  int participantsCount;

/// Create a copy of League
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LeagueCopyWith<_League> get copyWith => __$LeagueCopyWithImpl<_League>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LeagueToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _League&&(identical(other.id, id) || other.id == id)&&(identical(other.hostId, hostId) || other.hostId == hostId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.shortDescription, shortDescription) || other.shortDescription == shortDescription)&&(identical(other.location, location) || other.location == location)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.entryFee, entryFee) || other.entryFee == entryFee)&&(identical(other.maxParticipants, maxParticipants) || other.maxParticipants == maxParticipants)&&(identical(other.status, status) || other.status == status)&&(identical(other.fishTypes, fishTypes) || other.fishTypes == fishTypes)&&(identical(other.rule, rule) || other.rule == rule)&&(identical(other.catchLimit, catchLimit) || other.catchLimit == catchLimit)&&(identical(other.prizeInfo, prizeInfo) || other.prizeInfo == prizeInfo)&&(identical(other.isPublic, isPublic) || other.isPublic == isPublic)&&(identical(other.allowGallery, allowGallery) || other.allowGallery == allowGallery)&&const DeepCollectionEquality().equals(other._introImageUrls, _introImageUrls)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.participantsCount, participantsCount) || other.participantsCount == participantsCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,hostId,title,description,shortDescription,location,lat,lng,startTime,endTime,entryFee,maxParticipants,status,fishTypes,rule,catchLimit,prizeInfo,isPublic,allowGallery,const DeepCollectionEquality().hash(_introImageUrls),createdAt,participantsCount]);

@override
String toString() {
  return 'League(id: $id, hostId: $hostId, title: $title, description: $description, shortDescription: $shortDescription, location: $location, lat: $lat, lng: $lng, startTime: $startTime, endTime: $endTime, entryFee: $entryFee, maxParticipants: $maxParticipants, status: $status, fishTypes: $fishTypes, rule: $rule, catchLimit: $catchLimit, prizeInfo: $prizeInfo, isPublic: $isPublic, allowGallery: $allowGallery, introImageUrls: $introImageUrls, createdAt: $createdAt, participantsCount: $participantsCount)';
}


}

/// @nodoc
abstract mixin class _$LeagueCopyWith<$Res> implements $LeagueCopyWith<$Res> {
  factory _$LeagueCopyWith(_League value, $Res Function(_League) _then) = __$LeagueCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'host_id') String hostId, String title, String? description,@JsonKey(name: 'short_description') String? shortDescription, String location, double? lat, double? lng,@JsonKey(name: 'start_time') DateTime startTime,@JsonKey(name: 'end_time') DateTime endTime,@JsonKey(name: 'entry_fee') int entryFee,@JsonKey(name: 'max_participants') int maxParticipants, String status,@JsonKey(name: 'fish_types') String fishTypes, String rule,@JsonKey(name: 'catch_limit') int catchLimit,@JsonKey(name: 'prize_info') String? prizeInfo,@JsonKey(name: 'is_public') bool isPublic,@JsonKey(name: 'allow_gallery') bool allowGallery,@JsonKey(name: 'intro_image_urls') List<String> introImageUrls,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(includeFromJson: false, includeToJson: false) int participantsCount
});




}
/// @nodoc
class __$LeagueCopyWithImpl<$Res>
    implements _$LeagueCopyWith<$Res> {
  __$LeagueCopyWithImpl(this._self, this._then);

  final _League _self;
  final $Res Function(_League) _then;

/// Create a copy of League
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? hostId = null,Object? title = null,Object? description = freezed,Object? shortDescription = freezed,Object? location = null,Object? lat = freezed,Object? lng = freezed,Object? startTime = null,Object? endTime = null,Object? entryFee = null,Object? maxParticipants = null,Object? status = null,Object? fishTypes = null,Object? rule = null,Object? catchLimit = null,Object? prizeInfo = freezed,Object? isPublic = null,Object? allowGallery = null,Object? introImageUrls = null,Object? createdAt = null,Object? participantsCount = null,}) {
  return _then(_League(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,hostId: null == hostId ? _self.hostId : hostId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,shortDescription: freezed == shortDescription ? _self.shortDescription : shortDescription // ignore: cast_nullable_to_non_nullable
as String?,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,startTime: null == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as DateTime,endTime: null == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as DateTime,entryFee: null == entryFee ? _self.entryFee : entryFee // ignore: cast_nullable_to_non_nullable
as int,maxParticipants: null == maxParticipants ? _self.maxParticipants : maxParticipants // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,fishTypes: null == fishTypes ? _self.fishTypes : fishTypes // ignore: cast_nullable_to_non_nullable
as String,rule: null == rule ? _self.rule : rule // ignore: cast_nullable_to_non_nullable
as String,catchLimit: null == catchLimit ? _self.catchLimit : catchLimit // ignore: cast_nullable_to_non_nullable
as int,prizeInfo: freezed == prizeInfo ? _self.prizeInfo : prizeInfo // ignore: cast_nullable_to_non_nullable
as String?,isPublic: null == isPublic ? _self.isPublic : isPublic // ignore: cast_nullable_to_non_nullable
as bool,allowGallery: null == allowGallery ? _self.allowGallery : allowGallery // ignore: cast_nullable_to_non_nullable
as bool,introImageUrls: null == introImageUrls ? _self._introImageUrls : introImageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,participantsCount: null == participantsCount ? _self.participantsCount : participantsCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
