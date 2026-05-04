// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VerificationRequest _$VerificationRequestFromJson(Map<String, dynamic> json) =>
    _VerificationRequest(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      submitterId: json['submitter_id'] as String,
      status: json['status'] as String,
      approveCount: (json['approve_count'] as num?)?.toInt() ?? 0,
      rejectCount: (json['reject_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
    );

Map<String, dynamic> _$VerificationRequestToJson(
  _VerificationRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'post_id': instance.postId,
  'submitter_id': instance.submitterId,
  'status': instance.status,
  'approve_count': instance.approveCount,
  'reject_count': instance.rejectCount,
  'created_at': instance.createdAt.toIso8601String(),
  'resolved_at': instance.resolvedAt?.toIso8601String(),
};
