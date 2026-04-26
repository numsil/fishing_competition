// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'league_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_League _$LeagueFromJson(Map<String, dynamic> json) => _League(
  id: json['id'] as String,
  hostId: json['host_id'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  shortDescription: json['short_description'] as String?,
  location: json['location'] as String,
  lat: (json['lat'] as num?)?.toDouble(),
  lng: (json['lng'] as num?)?.toDouble(),
  startTime: DateTime.parse(json['start_time'] as String),
  endTime: DateTime.parse(json['end_time'] as String),
  entryFee: (json['entry_fee'] as num?)?.toInt() ?? 0,
  maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 100,
  status: json['status'] as String? ?? 'recruiting',
  fishTypes: json['fish_types'] as String? ?? '배스',
  rule: json['rule'] as String? ?? '최대어',
  catchLimit: (json['catch_limit'] as num?)?.toInt() ?? 1,
  prizeInfo: json['prize_info'] as String?,
  isPublic: json['is_public'] as bool? ?? true,
  allowGallery: json['allow_gallery'] as bool? ?? true,
  introImageUrls:
      (json['intro_image_urls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$LeagueToJson(_League instance) => <String, dynamic>{
  'id': instance.id,
  'host_id': instance.hostId,
  'title': instance.title,
  'description': instance.description,
  'short_description': instance.shortDescription,
  'location': instance.location,
  'lat': instance.lat,
  'lng': instance.lng,
  'start_time': instance.startTime.toIso8601String(),
  'end_time': instance.endTime.toIso8601String(),
  'entry_fee': instance.entryFee,
  'max_participants': instance.maxParticipants,
  'status': instance.status,
  'fish_types': instance.fishTypes,
  'rule': instance.rule,
  'catch_limit': instance.catchLimit,
  'prize_info': instance.prizeInfo,
  'is_public': instance.isPublic,
  'allow_gallery': instance.allowGallery,
  'intro_image_urls': instance.introImageUrls,
  'created_at': instance.createdAt.toIso8601String(),
};
