import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'slope_model.dart';

part 'slopes_repository.g.dart';

/// 번들 에셋(assets/data/slopes.json)에서 슬로프 목록을 로드한다.
/// 테스트 버전: 추후 Supabase 테이블로 이전 예정.
class SlopesRepository {
  Future<List<Slope>> getSlopes() async {
    final raw = await rootBundle.loadString('assets/data/slopes.json');
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => Slope.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

@riverpod
SlopesRepository slopesRepository(SlopesRepositoryRef ref) {
  return SlopesRepository();
}

@riverpod
Future<List<Slope>> slopes(SlopesRef ref) {
  ref.keepAlive(); // 정적 에셋이므로 세션 내 유지
  return ref.watch(slopesRepositoryProvider).getSlopes();
}
