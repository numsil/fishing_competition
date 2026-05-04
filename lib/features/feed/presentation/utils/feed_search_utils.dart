import '../../data/post_model.dart';

List<String> extractHashtags(String? caption) {
  if (caption == null || caption.isEmpty) return [];
  return caption
      .split(RegExp(r'\s+'))
      .where((w) => w.startsWith('#') && w.length > 1)
      .toList();
}

List<Post> filterPosts(List<Post> posts, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return posts;

  final isHashtagQuery = trimmed.startsWith('#');
  final q = trimmed.toLowerCase().replaceAll('#', '');

  return posts.where((p) {
    // If query starts with #, only match hashtags
    if (isHashtagQuery) {
      return extractHashtags(p.caption)
          .any((t) => t.toLowerCase().replaceAll('#', '').contains(q));
    }

    // Otherwise, match both username and hashtags
    if (p.username.toLowerCase().contains(q)) return true;
    return extractHashtags(p.caption)
        .any((t) => t.toLowerCase().replaceAll('#', '').contains(q));
  }).toList();
}
