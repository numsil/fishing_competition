// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'verification_model.freezed.dart';
part 'verification_model.g.dart';

@freezed
abstract class VerificationRequest with _$VerificationRequest {
  const factory VerificationRequest({
    required String id,
    @JsonKey(name: 'post_id') required String postId,
    @JsonKey(name: 'submitter_id') required String submitterId,
    required String status,
    @JsonKey(name: 'approve_count') @Default(0) int approveCount,
    @JsonKey(name: 'reject_count') @Default(0) int rejectCount,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'resolved_at') DateTime? resolvedAt,
    // joined fields - not serialized from DB
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String imageUrl,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String submitterName,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String submitterAvatar,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('배스') String fishType,
    @JsonKey(includeFromJson: false, includeToJson: false) double? length,
    @JsonKey(includeFromJson: false, includeToJson: false) double? weight,
    @JsonKey(includeFromJson: false, includeToJson: false) String? location,
    @JsonKey(includeFromJson: false, includeToJson: false) String? myVote,
  }) = _VerificationRequest;

  factory VerificationRequest.fromJson(Map<String, dynamic> json) =>
      _$VerificationRequestFromJson(json);
}
