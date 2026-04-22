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
    String? caption,
    @JsonKey(name: 'fish_type') @Default('배스') String fishType,
    double? length,
    @JsonKey(name: 'lure_type') String? lureType,
    double? depth,
    double? temperature,
    String? location,
    double? lat,
    double? lng,
    @JsonKey(name: 'is_lunker') @Default(false) bool isLunker,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    // Joined user data (can be populated after fetch)
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('Unknown') String username,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default(0) int likesCount,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default(0) int commentsCount,
  }) = _Post;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
}
