// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'marketplace_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MarketplaceItem {

 String get id;@JsonKey(name: 'user_id') String get userId; String get title; String? get description; int get price;@JsonKey(name: 'image_urls') List<String> get imageUrls; String get category; String get status;// selling, reserved, sold
 String? get location;@JsonKey(name: 'created_at') DateTime get createdAt;// joined user data
@JsonKey(includeFromJson: false, includeToJson: false) String get username;@JsonKey(includeFromJson: false, includeToJson: false) String get userKey;@JsonKey(includeFromJson: false, includeToJson: false) String get avatarUrl;
/// Create a copy of MarketplaceItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MarketplaceItemCopyWith<MarketplaceItem> get copyWith => _$MarketplaceItemCopyWithImpl<MarketplaceItem>(this as MarketplaceItem, _$identity);

  /// Serializes this MarketplaceItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MarketplaceItem&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.price, price) || other.price == price)&&const DeepCollectionEquality().equals(other.imageUrls, imageUrls)&&(identical(other.category, category) || other.category == category)&&(identical(other.status, status) || other.status == status)&&(identical(other.location, location) || other.location == location)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.username, username) || other.username == username)&&(identical(other.userKey, userKey) || other.userKey == userKey)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,title,description,price,const DeepCollectionEquality().hash(imageUrls),category,status,location,createdAt,username,userKey,avatarUrl);

@override
String toString() {
  return 'MarketplaceItem(id: $id, userId: $userId, title: $title, description: $description, price: $price, imageUrls: $imageUrls, category: $category, status: $status, location: $location, createdAt: $createdAt, username: $username, userKey: $userKey, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class $MarketplaceItemCopyWith<$Res>  {
  factory $MarketplaceItemCopyWith(MarketplaceItem value, $Res Function(MarketplaceItem) _then) = _$MarketplaceItemCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId, String title, String? description, int price,@JsonKey(name: 'image_urls') List<String> imageUrls, String category, String status, String? location,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(includeFromJson: false, includeToJson: false) String username,@JsonKey(includeFromJson: false, includeToJson: false) String userKey,@JsonKey(includeFromJson: false, includeToJson: false) String avatarUrl
});




}
/// @nodoc
class _$MarketplaceItemCopyWithImpl<$Res>
    implements $MarketplaceItemCopyWith<$Res> {
  _$MarketplaceItemCopyWithImpl(this._self, this._then);

  final MarketplaceItem _self;
  final $Res Function(MarketplaceItem) _then;

/// Create a copy of MarketplaceItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? title = null,Object? description = freezed,Object? price = null,Object? imageUrls = null,Object? category = null,Object? status = null,Object? location = freezed,Object? createdAt = null,Object? username = null,Object? userKey = null,Object? avatarUrl = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as int,imageUrls: null == imageUrls ? _self.imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,userKey: null == userKey ? _self.userKey : userKey // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: null == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MarketplaceItem].
extension MarketplaceItemPatterns on MarketplaceItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MarketplaceItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MarketplaceItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MarketplaceItem value)  $default,){
final _that = this;
switch (_that) {
case _MarketplaceItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MarketplaceItem value)?  $default,){
final _that = this;
switch (_that) {
case _MarketplaceItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId,  String title,  String? description,  int price, @JsonKey(name: 'image_urls')  List<String> imageUrls,  String category,  String status,  String? location, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(includeFromJson: false, includeToJson: false)  String username, @JsonKey(includeFromJson: false, includeToJson: false)  String userKey, @JsonKey(includeFromJson: false, includeToJson: false)  String avatarUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MarketplaceItem() when $default != null:
return $default(_that.id,_that.userId,_that.title,_that.description,_that.price,_that.imageUrls,_that.category,_that.status,_that.location,_that.createdAt,_that.username,_that.userKey,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId,  String title,  String? description,  int price, @JsonKey(name: 'image_urls')  List<String> imageUrls,  String category,  String status,  String? location, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(includeFromJson: false, includeToJson: false)  String username, @JsonKey(includeFromJson: false, includeToJson: false)  String userKey, @JsonKey(includeFromJson: false, includeToJson: false)  String avatarUrl)  $default,) {final _that = this;
switch (_that) {
case _MarketplaceItem():
return $default(_that.id,_that.userId,_that.title,_that.description,_that.price,_that.imageUrls,_that.category,_that.status,_that.location,_that.createdAt,_that.username,_that.userKey,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId,  String title,  String? description,  int price, @JsonKey(name: 'image_urls')  List<String> imageUrls,  String category,  String status,  String? location, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(includeFromJson: false, includeToJson: false)  String username, @JsonKey(includeFromJson: false, includeToJson: false)  String userKey, @JsonKey(includeFromJson: false, includeToJson: false)  String avatarUrl)?  $default,) {final _that = this;
switch (_that) {
case _MarketplaceItem() when $default != null:
return $default(_that.id,_that.userId,_that.title,_that.description,_that.price,_that.imageUrls,_that.category,_that.status,_that.location,_that.createdAt,_that.username,_that.userKey,_that.avatarUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MarketplaceItem implements MarketplaceItem {
  const _MarketplaceItem({required this.id, @JsonKey(name: 'user_id') required this.userId, required this.title, this.description, required this.price, @JsonKey(name: 'image_urls') final  List<String> imageUrls = const [], this.category = '기타', this.status = 'selling', this.location, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(includeFromJson: false, includeToJson: false) this.username = '', @JsonKey(includeFromJson: false, includeToJson: false) this.userKey = '', @JsonKey(includeFromJson: false, includeToJson: false) this.avatarUrl = ''}): _imageUrls = imageUrls;
  factory _MarketplaceItem.fromJson(Map<String, dynamic> json) => _$MarketplaceItemFromJson(json);

@override final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override final  String title;
@override final  String? description;
@override final  int price;
 final  List<String> _imageUrls;
@override@JsonKey(name: 'image_urls') List<String> get imageUrls {
  if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_imageUrls);
}

@override@JsonKey() final  String category;
@override@JsonKey() final  String status;
// selling, reserved, sold
@override final  String? location;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
// joined user data
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String username;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String userKey;
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String avatarUrl;

/// Create a copy of MarketplaceItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MarketplaceItemCopyWith<_MarketplaceItem> get copyWith => __$MarketplaceItemCopyWithImpl<_MarketplaceItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MarketplaceItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MarketplaceItem&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.price, price) || other.price == price)&&const DeepCollectionEquality().equals(other._imageUrls, _imageUrls)&&(identical(other.category, category) || other.category == category)&&(identical(other.status, status) || other.status == status)&&(identical(other.location, location) || other.location == location)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.username, username) || other.username == username)&&(identical(other.userKey, userKey) || other.userKey == userKey)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,title,description,price,const DeepCollectionEquality().hash(_imageUrls),category,status,location,createdAt,username,userKey,avatarUrl);

@override
String toString() {
  return 'MarketplaceItem(id: $id, userId: $userId, title: $title, description: $description, price: $price, imageUrls: $imageUrls, category: $category, status: $status, location: $location, createdAt: $createdAt, username: $username, userKey: $userKey, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class _$MarketplaceItemCopyWith<$Res> implements $MarketplaceItemCopyWith<$Res> {
  factory _$MarketplaceItemCopyWith(_MarketplaceItem value, $Res Function(_MarketplaceItem) _then) = __$MarketplaceItemCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId, String title, String? description, int price,@JsonKey(name: 'image_urls') List<String> imageUrls, String category, String status, String? location,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(includeFromJson: false, includeToJson: false) String username,@JsonKey(includeFromJson: false, includeToJson: false) String userKey,@JsonKey(includeFromJson: false, includeToJson: false) String avatarUrl
});




}
/// @nodoc
class __$MarketplaceItemCopyWithImpl<$Res>
    implements _$MarketplaceItemCopyWith<$Res> {
  __$MarketplaceItemCopyWithImpl(this._self, this._then);

  final _MarketplaceItem _self;
  final $Res Function(_MarketplaceItem) _then;

/// Create a copy of MarketplaceItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? title = null,Object? description = freezed,Object? price = null,Object? imageUrls = null,Object? category = null,Object? status = null,Object? location = freezed,Object? createdAt = null,Object? username = null,Object? userKey = null,Object? avatarUrl = null,}) {
  return _then(_MarketplaceItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as int,imageUrls: null == imageUrls ? _self._imageUrls : imageUrls // ignore: cast_nullable_to_non_nullable
as List<String>,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,location: freezed == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,userKey: null == userKey ? _self.userKey : userKey // ignore: cast_nullable_to_non_nullable
as String,avatarUrl: null == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
