// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_model.freezed.dart';
part 'post_model.g.dart';

@freezed
abstract class Post with _$Post {
  const factory Post({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'league_id') String? leagueId,
    @JsonKey(name: 'image_url') required String imageUrl,
    @JsonKey(name: 'image_urls') List<String>? imageUrls,
    @JsonKey(name: 'aspect_ratio') double? aspectRatio,
    @JsonKey(name: 'video_url') String? videoUrl,
    String? caption,
    @JsonKey(name: 'fish_type') @Default('배스') String fishType,
    double? length,
    @JsonKey(name: 'lure_type') String? lureType,
    double? depth,
    double? temperature,
    String? location,
    double? lat,
    double? lng,
    double? weight,
    @JsonKey(name: 'catch_count') @Default(1) int catchCount,
    @JsonKey(name: 'is_lunker') @Default(false) bool isLunker,
    @JsonKey(name: 'is_personal_record') @Default(false) bool isPersonalRecord,
    @Default(0) int score,
    @JsonKey(name: 'review_status') @Default('pending') String reviewStatus,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    // Joined user data (can be populated after fetch)
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('Unknown') String username,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default(0) int commentsCount,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String avatarUrl,
  }) = _Post;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
}
