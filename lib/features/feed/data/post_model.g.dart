// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Post _$PostFromJson(Map<String, dynamic> json) => _Post(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  leagueId: json['league_id'] as String?,
  imageUrl: json['image_url'] as String,
  caption: json['caption'] as String?,
  fishType: json['fish_type'] as String? ?? '배스',
  length: (json['length'] as num?)?.toDouble(),
  lureType: json['lure_type'] as String?,
  depth: (json['depth'] as num?)?.toDouble(),
  temperature: (json['temperature'] as num?)?.toDouble(),
  location: json['location'] as String?,
  lat: (json['lat'] as num?)?.toDouble(),
  lng: (json['lng'] as num?)?.toDouble(),
  weight: (json['weight'] as num?)?.toDouble(),
  catchCount: (json['catch_count'] as num?)?.toInt() ?? 1,
  isLunker: json['is_lunker'] as bool? ?? false,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$PostToJson(_Post instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'league_id': instance.leagueId,
  'image_url': instance.imageUrl,
  'caption': instance.caption,
  'fish_type': instance.fishType,
  'length': instance.length,
  'lure_type': instance.lureType,
  'depth': instance.depth,
  'temperature': instance.temperature,
  'location': instance.location,
  'lat': instance.lat,
  'lng': instance.lng,
  'weight': instance.weight,
  'catch_count': instance.catchCount,
  'is_lunker': instance.isLunker,
  'created_at': instance.createdAt.toIso8601String(),
};
