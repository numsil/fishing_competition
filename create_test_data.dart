import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  try {
    final envVars = await File('.env').readAsString();
    final envMap = <String, String>{};
    for (var line in envVars.split('\n')) {
      if (line.contains('=')) {
        final parts = line.split('=');
        envMap[parts[0].trim()] = parts.sublist(1).join('=').trim();
      }
    }
    
    // Pass a dummy storage to prevent null check errors
    final supabase = SupabaseClient(
      envMap['SUPABASE_URL']!,
      envMap['SUPABASE_ANON_KEY']!,
    );

    print('Logging in test user...');
    final authRes = await supabase.auth.signInWithPassword(
      email: 'test@fishinggram.com',
      password: 'password123',
    );
    final userId = authRes.user!.id;
    print('Logged in: $userId');

    final checkUser = await supabase.from('users').select().eq('id', userId);
    if (checkUser.isEmpty) {
      await supabase.from('users').insert({
        'id': userId,
        'email': 'test@fishinggram.com',
        'username': '초보앵글러',
      });
      print('Profile created in users table.');
    }

    print('Inserting leagues...');
    final leaguesData = [
      {
        'host_id': userId,
        'title': '2026 충주호 배스 오픈',
        'location': '충북 충주시',
        'start_time': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        'end_time': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
        'entry_fee': 50000,
        'max_participants': 30,
        'status': 'recruiting',
        'description': '최대어 기준',
      },
      {
        'host_id': userId,
        'title': '소양강 쏘가리 챔피언십',
        'location': '강원 춘천시',
        'start_time': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'end_time': DateTime.now().add(const Duration(days: 8)).toIso8601String(),
        'entry_fee': 30000,
        'max_participants': 20,
        'status': 'recruiting',
        'description': '마릿수 기준',
      }
    ];

    for (var l in leaguesData) {
      await supabase.from('leagues').insert(l);
    }

    print('Inserting posts...');
    final postsData = [
      {
        'user_id': userId,
        'image_url': 'https://images.unsplash.com/photo-1599839619722-39751411ea63?q=80&w=600&auto=format&fit=crop',
        'caption': '주말 아침 피딩타임에 올린 첫 수! 역시 탑워터에 반응이 좋네요.',
        'fish_type': '배스',
        'length': 48.5,
        'lure_type': '탑워터',
        'location': '청평호',
        'is_lunker': false,
      },
      {
        'user_id': userId,
        'image_url': 'https://images.unsplash.com/photo-1544365558-35aa4afcf11f?q=80&w=600&auto=format&fit=crop',
        'caption': '드디어 런커 달성했습니다 ㅠㅠ 5자 넘기는게 이렇게 힘들 줄이야',
        'fish_type': '배스',
        'length': 52.0,
        'lure_type': '프리리그',
        'location': '안동호',
        'is_lunker': true,
      },
      {
        'user_id': userId,
        'image_url': 'https://images.unsplash.com/photo-1506804886640-399fb580e6c2?q=80&w=600&auto=format&fit=crop',
        'caption': '새벽짬낚 조과입니다. 꾹꾹거리는 손맛이 예술이네요ㅎㅎ',
        'fish_type': '배스',
        'length': 35.0,
        'lure_type': '스피너베이트',
        'location': '팔당댐',
        'is_lunker': false,
      }
    ];

    for (var p in postsData) {
      await supabase.from('posts').insert(p);
    }

    print('✅ Test data creation complete!');

  } catch (e) {
    print('❌ Error: $e');
  }
}
