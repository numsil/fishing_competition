import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 피드 화면의 하위 탭 인덱스 (0 = 조과 피드, 1 = 중고거래).
/// 하단 홈 버튼 토글과 피드 화면의 TabController를 동기화하는 데 쓴다.
final feedSubTabProvider = StateProvider<int>((ref) => 0);
