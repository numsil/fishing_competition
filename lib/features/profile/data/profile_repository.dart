import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../feed/data/post_model.dart';

part 'profile_repository.g.dart';

class UserProfile {
  final String id;
  final String email;
  final String username;
  final String? avatarUrl;
  final double mannerTemperature;
  final bool isLunkerClub;
  final int postCount;
  final int lunkerCount;
  final double? maxFishLength;

  UserProfile({
    required this.id,
    required this.email,
    required this.username,
    this.avatarUrl,
    required this.mannerTemperature,
    required this.isLunkerClub,
    this.postCount = 0,
    this.lunkerCount = 0,
    this.maxFishLength,
  });
}

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository(this._supabase);

  Future<UserProfile> getMyProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    // Get user data
    final userRes = await _supabase.from('users').select().eq('id', userId).single();

    // Get posts stats (일반 피드 게시물만: 리그·개인기록 제외)
    final postsRes = await _supabase
        .from('posts')
        .select('length, is_lunker')
        .eq('user_id', userId)
        .isFilter('league_id', null)
        .eq('is_personal_record', false);
    
    int postCount = postsRes.length;
    int lunkerCount = 0;
    double? maxLen;

    for (var post in postsRes) {
      if (post['is_lunker'] == true) lunkerCount++;
      if (post['length'] != null) {
        final double len = (post['length'] as num).toDouble();
        if (maxLen == null || len > maxLen) {
          maxLen = len;
        }
      }
    }

    return UserProfile(
      id: userRes['id'],
      email: userRes['email'],
      username: userRes['username'],
      avatarUrl: userRes['avatar_url'],
      mannerTemperature: (userRes['manner_temperature'] as num).toDouble(),
      isLunkerClub: userRes['is_lunker_club'] ?? false,
      postCount: postCount,
      lunkerCount: lunkerCount,
      maxFishLength: maxLen,
    );
  }

  Future<String> uploadAvatar(File imageFile) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final ext = imageFile.path.split('.').last.toLowerCase();
    final storagePath = '$userId/avatar.$ext';

    await _supabase.storage.from('avatars').upload(
      storagePath,
      imageFile,
      fileOptions: FileOptions(
        contentType: 'image/$ext',
        upsert: true,
      ),
    );

    final url = _supabase.storage.from('avatars').getPublicUrl(storagePath);

    await _supabase
        .from('users')
        .update({'avatar_url': url})
        .eq('id', userId);

    return url;
  }

  Future<List<Post>> getMyPosts() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final response = await _supabase
        .from('posts')
        .select()
        .eq('user_id', userId)
        .isFilter('league_id', null)
        .eq('is_personal_record', false)
        .order('created_at', ascending: false);

    return response.map((data) => Post.fromJson(data)).toList();
  }

  Future<List<Post>> getMyPersonalRecords() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final response = await _supabase
        .from('posts')
        .select()
        .eq('user_id', userId)
        .isFilter('league_id', null)
        .eq('is_personal_record', true)
        .order('created_at', ascending: false);

    return response.map((data) => Post.fromJson(data)).toList();
  }
}

@riverpod
ProfileRepository profileRepository(ProfileRepositoryRef ref) {
  return ProfileRepository(Supabase.instance.client);
}

@riverpod
Future<UserProfile> myProfile(MyProfileRef ref) {
  return ref.watch(profileRepositoryProvider).getMyProfile();
}

@riverpod
Future<List<Post>> myPosts(MyPostsRef ref) {
  return ref.watch(profileRepositoryProvider).getMyPosts();
}

@riverpod
Future<List<Post>> myPersonalRecords(MyPersonalRecordsRef ref) {
  return ref.watch(profileRepositoryProvider).getMyPersonalRecords();
}
