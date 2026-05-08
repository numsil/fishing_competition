import 'package:supabase_flutter/supabase_flutter.dart';

/// Storage public URL에서 path 추출.
///
/// URL 형식:
///   https://{project}.supabase.co/storage/v1/object/public/{bucket}/{path}
String? extractStoragePath(String? url, String bucket) {
  if (url == null || url.isEmpty) return null;
  final marker = '/storage/v1/object/public/$bucket/';
  final idx = url.indexOf(marker);
  if (idx == -1) return null;
  try {
    return Uri.decodeComponent(url.substring(idx + marker.length));
  } catch (_) {
    return null;
  }
}

/// post의 image/video Storage 파일을 best-effort로 제거.
///
/// - 실패해도 throw하지 않음 (DB 삭제와 분리되어 있어 청소 누락은 audit으로 보정)
/// - image_url + image_urls + video_url 전부 정리
Future<void> removePostStorageFiles(
  SupabaseClient supabase, {
  String? imageUrl,
  List<String>? imageUrls,
  String? videoUrl,
}) async {
  final imagePaths = <String>{};

  final single = extractStoragePath(imageUrl, 'post_images');
  if (single != null) imagePaths.add(single);

  if (imageUrls != null) {
    for (final u in imageUrls) {
      final p = extractStoragePath(u, 'post_images');
      if (p != null) imagePaths.add(p);
    }
  }

  if (imagePaths.isNotEmpty) {
    try {
      await supabase.storage.from('post_images').remove(imagePaths.toList());
    } catch (_) {/* swallow */}
  }

  final videoPath = extractStoragePath(videoUrl, 'post_videos');
  if (videoPath != null) {
    try {
      await supabase.storage.from('post_videos').remove([videoPath]);
    } catch (_) {/* swallow */}
  }
}

/// 리그 인트로 이미지를 best-effort로 제거.
Future<void> removeLeagueIntroFiles(
  SupabaseClient supabase,
  List<String>? introImageUrls,
) async {
  if (introImageUrls == null || introImageUrls.isEmpty) return;
  final paths = <String>{};
  for (final u in introImageUrls) {
    final p = extractStoragePath(u, 'league_images');
    if (p != null) paths.add(p);
  }
  if (paths.isEmpty) return;
  try {
    await supabase.storage.from('league_images').remove(paths.toList());
  } catch (_) {/* swallow */}
}
