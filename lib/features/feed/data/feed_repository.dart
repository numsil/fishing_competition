import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/image_compress.dart';
import '../../../core/utils/score_calculator.dart';
import '../../../core/utils/storage_cleanup.dart';
import 'post_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../verification/data/verification_repository.dart';

part 'feed_repository.g.dart';

const int kFeedPageSize = 20;

/// getPosts 반환값 — 포스트 목록 + 다음 페이지 커서.
typedef FeedPage = ({
  List<Post> posts,
  double? lastScore,
  DateTime? lastCreatedAt,
  String? lastId,
});

/// 업로드 시 사진/동영상 혼합 미디어 한 항목.
/// - image: [file]은 원본 이미지(압축은 repo에서 처리)
/// - video: [file]은 압축 완료된 mp4. [thumbnailBytes]는 썸네일 jpg 바이트.
class PickedMedia {
  final String type; // 'image' | 'video'
  final File file;
  final Uint8List? thumbnailBytes;
  final double? aspectRatio;

  const PickedMedia({
    required this.type,
    required this.file,
    this.thumbnailBytes,
    this.aspectRatio,
  });

  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';
}

class FeedRepository {
  final SupabaseClient _supabase;

  FeedRepository(this._supabase);

  /// 인기도 혼합 정렬 피드 (RPC). 커서 기반 페이지네이션.
  /// 점수 = 좋아요(0.4) + 댓글(0.3) + 최신성(0.3), 7일 감쇠.
  Future<FeedPage> getPosts({
    int limit = kFeedPageSize,
    double? beforeScore,
    DateTime? beforeCreatedAt,
    String? beforeId,
    List<String> blockedUserIds = const [],
  }) async {
    final params = <String, dynamic>{'p_limit': limit};
    if (beforeScore != null) params['p_before_score'] = beforeScore;
    if (beforeCreatedAt != null) {
      params['p_before_created_at'] = beforeCreatedAt.toUtc().toIso8601String();
    }
    if (beforeId != null) params['p_before_id'] = beforeId;
    if (blockedUserIds.isNotEmpty) params['p_blocked_user_ids'] = blockedUserIds;

    final response = await _supabase.rpc('get_scored_feed_posts', params: params);
    final rows = (response as List).cast<Map<String, dynamic>>();

    final posts = rows.map((data) {
      final post = Post.fromJson(data);
      return post.copyWith(
        username: data['username'] as String? ?? 'Unknown',
        userKey: data['user_key'] as String? ?? '',
        avatarUrl: data['avatar_url'] as String? ?? '',
        commentsCount: (data['comment_count'] as num?)?.toInt() ?? 0,
        likeCount: (data['like_count'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    // 현재 유저가 좋아요 누른 글 표시 (페이지당 1쿼리, N+1 없음)
    final likedIds = await _likedPostIds(posts.map((p) => p.id).toList());
    final hydrated = [
      for (final p in posts) p.copyWith(isLiked: likedIds.contains(p.id)),
    ];

    // 커서: 마지막 행의 feed_score + created_at + id
    double? lastScore;
    DateTime? lastCreatedAt;
    String? lastId;
    if (rows.isNotEmpty) {
      lastScore = (rows.last['feed_score'] as num?)?.toDouble();
      lastCreatedAt = hydrated.last.createdAt;
      lastId = hydrated.last.id;
    }

    return (
      posts: hydrated,
      lastScore: lastScore,
      lastCreatedAt: lastCreatedAt,
      lastId: lastId,
    );
  }

  /// 주어진 게시물들 중 현재 로그인 유저가 좋아요 누른 post_id 집합.
  Future<Set<String>> _likedPostIds(List<String> postIds) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null || postIds.isEmpty) return <String>{};
    final rows = await _supabase
        .from('post_likes')
        .select('post_id')
        .eq('user_id', uid)
        .inFilter('post_id', postIds);
    return rows.map((r) => r['post_id'] as String).toSet();
  }

  /// 좋아요 토글. [like]가 true면 추가, false면 취소.
  /// post_likes의 UNIQUE(post_id, user_id) 제약이 중복을 차단한다.
  Future<void> toggleLike(String postId, bool like) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    if (like) {
      await _supabase
          .from('post_likes')
          .upsert({'post_id': postId, 'user_id': uid},
              onConflict: 'post_id,user_id', ignoreDuplicates: true);
    } else {
      await _supabase
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
    }
  }

  /// 딥링크/외부 진입용 단건 조회.
  /// 삭제·심사반려 게시물은 null.
  Future<Post?> fetchPostById(String postId) async {
    final row = await _supabase
        .from('posts')
        .select('id, user_id, league_id, image_url, image_urls, media, aspect_ratio, video_url, youtube_url, caption, fish_type, length, weight, catch_count, is_lunker, is_personal_record, review_status, location, created_at, users(username, avatar_url, user_key), post_comments(count), post_likes(count)')
        .eq('id', postId)
        .or('is_deleted.is.null,is_deleted.eq.false')
        .maybeSingle();

    if (row == null) return null;

    final post = Post.fromJson(row);
    final usersData = row['users'];
    final String username = (usersData != null && usersData is Map)
        ? usersData['username'] ?? 'Unknown'
        : 'Unknown';
    final String avatarUrl = (usersData != null && usersData is Map)
        ? usersData['avatar_url'] ?? ''
        : '';
    final String userKey = (usersData != null && usersData is Map)
        ? usersData['user_key'] ?? ''
        : '';

    final commentsData = row['post_comments'];
    final int comments = (commentsData is List && commentsData.isNotEmpty)
        ? commentsData[0]['count'] ?? 0
        : 0;

    final likesData = row['post_likes'];
    final int likes = (likesData is List && likesData.isNotEmpty)
        ? likesData[0]['count'] ?? 0
        : 0;

    final likedIds = await _likedPostIds([postId]);

    return post.copyWith(
      username: username,
      userKey: userKey,
      avatarUrl: avatarUrl,
      commentsCount: comments,
      likeCount: likes,
      isLiked: likedIds.contains(postId),
    );
  }

  Future<void> addComment(String postId, String userId, String content) async {
    await _supabase.from('post_comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content': content,
    });
  }

  /// 댓글 삭제. RLS(auth.uid() = user_id)가 본인 댓글만 허용한다.
  Future<void> deleteComment(String commentId) async {
    await _supabase.from('post_comments').delete().eq('id', commentId);
  }

  /// 댓글 수정. RLS(auth.uid() = user_id)가 본인 댓글만 허용한다.
  Future<void> updateComment(String commentId, String content) async {
    await _supabase
        .from('post_comments')
        .update({'content': content})
        .eq('id', commentId);
  }

  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final response = await _supabase
        .from('post_comments')
        .select('id, user_id, content, created_at, users(username, avatar_url, user_key)')
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> deletePost(String postId) async {
    final row = await _supabase
        .from('posts')
        .select('image_url, image_urls, video_url, media')
        .eq('id', postId)
        .maybeSingle();

    await _supabase.from('posts').delete().eq('id', postId);

    if (row != null) {
      final imageUrls = (row['image_urls'] as List?)?.cast<String>();
      await removePostStorageFiles(
        _supabase,
        imageUrl: row['image_url'] as String?,
        imageUrls: imageUrls,
        videoUrl: row['video_url'] as String?,
        media: row['media'] as List?,
      );
    }
  }

  Future<void> updatePostMeta({
    required String postId,
    String? caption,
    String? location,
  }) async {
    await _supabase.from('posts').update({
      'caption': caption?.trim().isEmpty == true ? null : caption?.trim(),
      'location': location?.trim().isEmpty == true ? null : location?.trim(),
    }).eq('id', postId);
  }

  Future<void> updatePost({
    required String postId,
    List<File>? newImageFiles,  // null이면 기존 이미지 유지
    String? caption,
    String? location,
    double? length,
    double? weight,
  }) async {
    final updates = <String, dynamic>{
      'caption': caption?.trim().isEmpty == true ? null : caption?.trim(),
      'location': location?.trim().isEmpty == true ? null : location?.trim(),
      'length': length,
      'weight': weight,
      'is_lunker': length != null && length >= 50.0,
      'score': calculateFishScore(length),
    };

    String? oldImageUrl;
    List<String>? oldImageUrls;
    if (newImageFiles != null && newImageFiles.isNotEmpty) {
      // 교체 전 기존 이미지 URL 조회 (업로드 후 고아 파일 정리용, 필요한 2컬럼만)
      final prev = await _supabase
          .from('posts')
          .select('image_url, image_urls')
          .eq('id', postId)
          .maybeSingle();
      if (prev != null) {
        oldImageUrl = prev['image_url'] as String?;
        oldImageUrls = (prev['image_urls'] as List?)?.cast<String>();
      }
      final userId = _supabase.auth.currentUser?.id ?? '';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final urls = <String>[];
      for (int i = 0; i < newImageFiles.length; i++) {
        final compressed = await compressForUpload(newImageFiles[i]);
        final storagePath = 'posts/${userId}_${ts}_$i.jpg';
        await _supabase.storage.from('post_images').upload(
          storagePath,
          compressed,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
            cacheControl: '31536000',
          ),
        );
        urls.add(_supabase.storage.from('post_images').getPublicUrl(storagePath));
        // 업로드 후 로컬 임시파일 정리 (압축본 + picker 원본 복사본)
        try {
          await compressed.delete();
          await newImageFiles[i].delete();
        } catch (_) {}
      }
      updates['image_url'] = urls.first;
      updates['image_urls'] = urls;
    }

    await _supabase.from('posts').update(updates).eq('id', postId);

    // 교체된 옛 이미지를 best-effort로 정리 (새 파일과 경로·ts가 달라 충돌 없음)
    if (oldImageUrl != null ||
        (oldImageUrls != null && oldImageUrls.isNotEmpty)) {
      await removePostStorageFiles(
        _supabase,
        imageUrl: oldImageUrl,
        imageUrls: oldImageUrls,
      );
    }
  }

  /// 조과 앨범에서 선택한 여러 Post를 하나의 피드 포스트로 공유.
  /// 이미지는 재업로드 없이 기존 URL을 그대로 참조한다.
  Future<void> shareMultiplePostsToFeed({
    required List<Post> posts,
    String? caption,
    String? location,
    double? length,
    double? weight,
    String? leagueId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    if (posts.isEmpty) throw ArgumentError('posts must not be empty');
    final first = posts.first;
    // lure_type은 의도적으로 생략: 번들 공유는 여러 조과를 묶으므로 루어가 다를 수 있음
    await _supabase.from('posts').insert({
      'user_id': userId,
      'image_url': first.imageUrl,
      'image_urls': posts.map((p) => p.imageUrl).toList(),
      'aspect_ratio': first.aspectRatio,
      'caption': caption,
      'fish_type': first.fishType,
      'location': location,
      'league_id': leagueId,
      'is_personal_record': false,
      'is_deleted': false,
      'length': length,
      'weight': weight,
      'catch_count': posts.length,
      'is_lunker': length != null && length >= 50.0,
      'score': calculateFishScore(length),
    });
  }

  // 리그 조과 / 개인 기록을 일반 피드에 공유
  Future<void> sharePostToFeed(Post post) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    await _supabase.from('posts').insert({
      'user_id': userId,
      'image_url': post.imageUrl,
      'image_urls': post.imageUrls,
      'aspect_ratio': post.aspectRatio,
      'caption': post.caption,
      'fish_type': post.fishType,
      'lure_type': post.lureType,
      'location': post.location,
      'league_id': null,
      'is_personal_record': false,
      'length': post.length,
      'weight': post.weight,
      'catch_count': post.catchCount,
      'is_lunker': post.isLunker,
    });
  }

  Future<void> createPost({
    required String userId,
    File? imageFile,           // 단일 이미지 (리그 조과 등 하위 호환)
    List<File>? imageFiles,   // 다중 이미지 (피드 업로드)
    File? videoFile,
    Uint8List? videoThumbnailBytes,
    List<PickedMedia>? mediaFiles, // 사진/동영상 혼합 (신규 피드 업로드)
    String? youtubeUrl,        // 유튜브 링크 게시물
    String? youtubeThumbnailUrl, // 유튜브 썸네일 (image_url 로 저장)
    double? aspectRatio,
    String? caption,
    String fishType = '배스',
    String? lureType,
    String? location,
    double? lat,
    double? lng,
    String? leagueId,
    double? length,
    double? weight,
    int catchCount = 1,
    bool isPersonalRecord = false,
    int imageMaxDimension = 1440, // 이미지 긴 변 상한 (리그/개인 조과는 1280 전달)
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    String imageUrl;
    String? videoUrl;
    List<String>? imageUrls;
    List<Map<String, dynamic>>? mediaJson; // posts.media (jsonb)

    if (youtubeUrl != null && youtubeUrl.isNotEmpty) {
      // 유튜브 모드: 업로드 없이 썸네일 URL 만 image_url 에 저장
      imageUrl = youtubeThumbnailUrl ?? '';
    } else if (mediaFiles != null && mediaFiles.isNotEmpty) {
      // 혼합 미디어 모드: 순서대로 업로드 후 media jsonb + legacy 필드 둘 다 채움
      final media = <Map<String, dynamic>>[];
      final imgUrls = <String>[];
      String? firstVideoUrl;
      String? firstThumbOrImageUrl;
      for (int i = 0; i < mediaFiles.length; i++) {
        final m = mediaFiles[i];
        if (m.isImage) {
          final compressed = await compressForUpload(m.file, maxDimension: imageMaxDimension);
          final storagePath = 'posts/${userId}_${ts}_$i.jpg';
          await _supabase.storage.from('post_images').upload(
            storagePath,
            compressed,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
              cacheControl: '31536000',
            ),
          );
          final url = _supabase.storage.from('post_images').getPublicUrl(storagePath);
          imgUrls.add(url);
          // 업로드 후 로컬 임시파일 정리 (압축본 + picker 원본 복사본)
          try {
            await compressed.delete();
            await m.file.delete();
          } catch (_) {}
          media.add({
            'type': 'image',
            'url': url,
            if (m.aspectRatio != null) 'aspect_ratio': m.aspectRatio,
          });
          firstThumbOrImageUrl ??= url;
        } else {
          // video
          String? thumbUrl;
          if (m.thumbnailBytes != null) {
            final thumbPath = 'posts/${userId}_${ts}_${i}_thumb.jpg';
            await _supabase.storage.from('post_images').uploadBinary(
              thumbPath,
              m.thumbnailBytes!,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
                cacheControl: '31536000',
              ),
            );
            thumbUrl = _supabase.storage.from('post_images').getPublicUrl(thumbPath);
          }
          final videoPath = 'posts/${userId}_${ts}_$i.mp4';
          await _supabase.storage.from('post_videos').upload(
            videoPath,
            m.file,
            fileOptions: const FileOptions(
              contentType: 'video/mp4',
              upsert: false,
              cacheControl: '31536000',
            ),
          );
          final url = _supabase.storage.from('post_videos').getPublicUrl(videoPath);
          firstVideoUrl ??= url;
          firstThumbOrImageUrl ??= thumbUrl;
          media.add({
            'type': 'video',
            'url': url,
            if (thumbUrl != null) 'thumbnail_url': thumbUrl,
            if (m.aspectRatio != null) 'aspect_ratio': m.aspectRatio,
          });
        }
      }
      mediaJson = media;
      // legacy 호환: image_url(NOT NULL)에는 첫 미디어의 (이미지|동영상 썸네일) URL
      imageUrl = firstThumbOrImageUrl ?? '';
      // legacy: image_urls는 사진들만, video_url은 첫 동영상
      imageUrls = imgUrls.isNotEmpty ? imgUrls : null;
      videoUrl = firstVideoUrl;
    } else if (videoFile != null) {
      if (videoThumbnailBytes != null) {
        final thumbPath = 'posts/${userId}_${ts}_thumb.jpg';
        await _supabase.storage.from('post_images').uploadBinary(
          thumbPath,
          videoThumbnailBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
            cacheControl: '31536000',
          ),
        );
        imageUrl = _supabase.storage.from('post_images').getPublicUrl(thumbPath);
      } else {
        imageUrl = '';
      }

      final videoPath = 'posts/${userId}_$ts.mp4';
      await _supabase.storage.from('post_videos').upload(
        videoPath,
        videoFile,
        fileOptions: const FileOptions(
          contentType: 'video/mp4',
          upsert: false,
          cacheControl: '31536000',
        ),
      );
      videoUrl = _supabase.storage.from('post_videos').getPublicUrl(videoPath);
    } else if (imageFiles != null && imageFiles.isNotEmpty) {
      final urls = <String>[];
      for (int i = 0; i < imageFiles.length; i++) {
        final compressed = await compressForUpload(imageFiles[i], maxDimension: imageMaxDimension);
        final storagePath = 'posts/${userId}_${ts}_$i.jpg';
        await _supabase.storage.from('post_images').upload(
          storagePath,
          compressed,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
            cacheControl: '31536000',
          ),
        );
        urls.add(_supabase.storage.from('post_images').getPublicUrl(storagePath));
        // 업로드 후 로컬 임시파일 정리 (압축본 + picker 원본 복사본)
        try {
          await compressed.delete();
          await imageFiles[i].delete();
        } catch (_) {}
      }
      imageUrl = urls.first;
      imageUrls = urls;
    } else if (imageFile != null) {
      final compressed = await compressForUpload(imageFile, maxDimension: imageMaxDimension);
      final storagePath = 'posts/${userId}_$ts.jpg';
      await _supabase.storage.from('post_images').upload(
        storagePath,
        compressed,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: false,
          cacheControl: '31536000',
        ),
      );
      imageUrl = _supabase.storage.from('post_images').getPublicUrl(storagePath);
      // 업로드 후 로컬 임시파일 정리 (압축본 + picker 원본 복사본)
      try {
        await compressed.delete();
        await imageFile.delete();
      } catch (_) {}
    } else {
      throw Exception('이미지 또는 동영상을 선택해주세요');
    }

    final inserted = await _supabase.from('posts').insert({
      'user_id': userId,
      'image_url': imageUrl,
      'image_urls': imageUrls,
      'media': mediaJson,
      'aspect_ratio': aspectRatio,
      'video_url': videoUrl,
      'youtube_url': youtubeUrl,
      'caption': caption,
      'fish_type': fishType,
      'lure_type': lureType,
      'location': location,
      'lat': lat,
      'lng': lng,
      'league_id': leagueId,
      'is_personal_record': isPersonalRecord,
      'is_deleted': false,
      'length': length,
      'weight': weight,
      'catch_count': catchCount,
      'is_lunker': length != null && length >= 50.0,
      'score': calculateFishScore(length),
      // review_status는 DB 트리거(enforce_initial_review_status)가 강제 설정
    }).select('id').single();

    // 개인기록만 인증 요청 생성
    if (isPersonalRecord) {
      final verificationRepo = VerificationRepository(_supabase);
      await verificationRepo.createVerificationRequest(
        inserted['id'] as String,
        userId,
      );
    }
  }
}

@riverpod
FeedRepository feedRepository(FeedRepositoryRef ref) {
  return FeedRepository(Supabase.instance.client);
}

@riverpod
class FeedPosts extends _$FeedPosts {
  bool _hasMore = true;
  bool _loading = false;

  // 페이지네이션 커서 (RPC 복합 커서)
  double? _lastScore;
  DateTime? _lastCreatedAt;
  String? _lastId;

  bool get hasMore => _hasMore;

  @override
  Future<List<Post>> build() async {
    _hasMore = true;
    _loading = false;
    _lastScore = null;
    _lastCreatedAt = null;
    _lastId = null;
    final link = ref.keepAlive();
    Timer(const Duration(minutes: 5), link.close);
    final blocked = await ref.read(authRepositoryProvider).getBlockedUserIds();
    final page = await ref.watch(feedRepositoryProvider).getPosts(
          limit: kFeedPageSize,
          blockedUserIds: blocked,
        );
    _lastScore = page.lastScore;
    _lastCreatedAt = page.lastCreatedAt;
    _lastId = page.lastId;
    _hasMore = page.posts.length >= kFeedPageSize;
    return page.posts;
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;
    _loading = true;
    try {
      final blocked = await ref.read(authRepositoryProvider).getBlockedUserIds();
      final page = await ref.read(feedRepositoryProvider).getPosts(
            limit: kFeedPageSize,
            beforeScore: _lastScore,
            beforeCreatedAt: _lastCreatedAt,
            beforeId: _lastId,
            blockedUserIds: blocked,
          );
      _lastScore = page.lastScore;
      _lastCreatedAt = page.lastCreatedAt;
      _lastId = page.lastId;
      _hasMore = page.posts.length >= kFeedPageSize;
      if (page.posts.isNotEmpty) {
        state = AsyncData([...current, ...page.posts]);
      }
    } finally {
      _loading = false;
    }
  }

  /// 좋아요 토글 — 낙관적 업데이트(즉시 반영 → 서버 반영 → 실패 시 롤백).
  Future<void> toggleLike(String postId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final target = current[idx];
    final newLiked = !target.isLiked;
    final newCount =
        newLiked ? target.likeCount + 1 : (target.likeCount > 0 ? target.likeCount - 1 : 0);

    final optimistic = [...current];
    optimistic[idx] = target.copyWith(isLiked: newLiked, likeCount: newCount);
    state = AsyncData(optimistic);

    try {
      await ref.read(feedRepositoryProvider).toggleLike(postId, newLiked);
    } catch (_) {
      // 롤백: id로 다시 찾아 원래 값 복원
      final rb = state.valueOrNull;
      if (rb == null) return;
      final i = rb.indexWhere((p) => p.id == postId);
      if (i == -1) return;
      final reverted = [...rb];
      reverted[i] = reverted[i].copyWith(isLiked: target.isLiked, likeCount: target.likeCount);
      state = AsyncData(reverted);
    }
  }
}
