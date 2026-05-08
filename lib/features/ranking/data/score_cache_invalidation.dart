import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/data/profile_repository.dart';
import 'ranking_repository.dart';

/// 점수가 바뀌는 이벤트(조과 등록/삭제, 보류/해제, 리그 종료 등) 직후 호출.
/// 시즌 랭킹과 프로필 점수 캐시를 비워서 다음 화면 진입 시 즉시 갱신되게 한다.
void invalidateScoreCaches(WidgetRef ref) {
  ref.invalidate(leagueScoreRankingProvider);
  ref.invalidate(personalScoreRankingProvider);
  ref.invalidate(myProfileProvider);
  ref.invalidate(userProfileProvider);
}
