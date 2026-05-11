/// 피드 광고 모델.
class AdFeed {
  const AdFeed({
    required this.id,
    required this.title,
    this.body,
    this.imageUrl,
    this.imageUrls = const [],
    this.videoUrl,
    this.thumbnailUrl,
    this.aspectRatio = 1.0,
    required this.linkUrl,
  });

  final String id;
  final String title;
  final String? body;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? videoUrl;
  final String? thumbnailUrl;
  final double aspectRatio;
  final String linkUrl;

  bool get hasVideo => (videoUrl?.isNotEmpty ?? false);
  bool get hasCarousel => imageUrls.isNotEmpty;
  bool get hasImage => (imageUrl?.isNotEmpty ?? false) || hasCarousel;

  factory AdFeed.fromJson(Map<String, dynamic> json) {
    final urlsRaw = json['image_urls'];
    final urls = (urlsRaw is List)
        ? urlsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    return AdFeed(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      imageUrl: json['image_url'] as String?,
      imageUrls: urls,
      videoUrl: json['video_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      aspectRatio: (json['aspect_ratio'] as num?)?.toDouble() ?? 1.0,
      linkUrl: json['link_url'] as String? ?? '',
    );
  }
}
