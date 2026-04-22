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
  location: json['location'] as String,
  lat: (json['lat'] as num?)?.toDouble(),
  lng: (json['lng'] as num?)?.toDouble(),
  startTime: DateTime.parse(json['start_time'] as String),
  endTime: DateTime.parse(json['end_time'] as String),
  entryFee: (json['entry_fee'] as num?)?.toInt() ?? 0,
  maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 100,
  status: json['status'] as String? ?? 'recruiting',
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$LeagueToJson(_League instance) => <String, dynamic>{
  'id': instance.id,
  'host_id': instance.hostId,
  'title': instance.title,
  'description': instance.description,
  'location': instance.location,
  'lat': instance.lat,
  'lng': instance.lng,
  'start_time': instance.startTime.toIso8601String(),
  'end_time': instance.endTime.toIso8601String(),
  'entry_fee': instance.entryFee,
  'max_participants': instance.maxParticipants,
  'status': instance.status,
  'created_at': instance.createdAt.toIso8601String(),
};
