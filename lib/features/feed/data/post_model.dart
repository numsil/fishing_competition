// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'post_model.freezed.dart';
part 'post_model.g.dart';

@freezed
abstract class MediaItem with _$MediaItem {
  const factory MediaItem({
    required String type, // 'image' | 'video'
    required String url,
    @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
    @JsonKey(name: 'aspect_ratio') double? aspectRatio,
  }) = _MediaItem;

  factory MediaItem.fromJson(Map<String, dynamic> json) => _$MediaItemFromJson(json);
}

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
    @JsonKey(name: 'youtube_url') String? youtubeUrl,
    List<MediaItem>? media,
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

extension PostMediaX on Post {
  /// 표시용 미디어 리스트. media 컬럼이 있으면 그대로, 없으면 legacy 필드로부터 재구성.
  /// YouTube/광고 등 외부 URL은 포함하지 않는다.
  List<MediaItem> get effectiveMedia {
    if (media != null && media!.isNotEmpty) return media!;
    final list = <MediaItem>[];
    if (videoUrl != null && videoUrl!.isNotEmpty) {
      list.add(MediaItem(
        type: 'video',
        url: videoUrl!,
        thumbnailUrl: imageUrl,
        aspectRatio: aspectRatio,
      ));
    } else if (imageUrls != null && imageUrls!.isNotEmpty) {
      for (final u in imageUrls!) {
        list.add(MediaItem(type: 'image', url: u, aspectRatio: aspectRatio));
      }
    } else if (imageUrl.isNotEmpty) {
      list.add(MediaItem(type: 'image', url: imageUrl, aspectRatio: aspectRatio));
    }
    return list;
  }
}
