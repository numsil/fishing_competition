// 팀 정원 판정. `leagues.team_capacity` 가 `0` 이면 무제한이다.
//
// 이 파일의 규칙은 마이그레이션
// `20261123140000_league_team_assign_mode.sql` 의 RPC 검증과 1:1 로
// 대응한다. 한쪽만 고치면 UI 가 허용한 조작이 서버에서 거부된다.

/// 더 들어갈 수 없는가.
bool isTeamFull({required int capacity, required int memberCount}) =>
    capacity > 0 && memberCount >= capacity;

/// 정원보다 이미 많은가. 호스트가 정원을 낮춘 경우에만 생긴다.
bool isOverCapacity({required int capacity, required int memberCount}) =>
    capacity > 0 && memberCount > capacity;

/// 남은 자리. 무제한이면 `-1`.
///
/// 초과 상태에서 음수를 돌려주면 "-3자리 남음" 같은 문구가 나오므로 0 으로 깎는다.
int remainingSlots({required int capacity, required int memberCount}) {
  if (capacity <= 0) return -1;
  final left = capacity - memberCount;
  return left > 0 ? left : 0;
}

/// 카드·목록에 쓰는 인원 표시.
String capacityLabel({required int capacity, required int memberCount}) =>
    capacity <= 0 ? '$memberCount명' : '$memberCount / $capacity';

/// 라운드로빈 셔플이 정원 안에 들어가는가.
///
/// 균등 분배이므로 총 자리수만 맞으면 어떤 팀도 정원을 넘지 않는다.
bool shuffleFitsCapacity({
  required int approvedCount,
  required int teamCount,
  required int capacity,
}) {
  if (capacity <= 0) return true;
  return approvedCount <= teamCount * capacity;
}

/// 일괄 배정이 정원 규칙을 지키는가 — **적용 후 상태** 기준.
///
/// [before] / [incoming] 모두 `userId → teamId?` 이고 `null` 은 미배정이다.
/// [incoming] 에 없는 사람은 [before] 값을 유지한다 (키가 없는 것과
/// 값이 null 인 것은 다르다 — 후자는 "미배정으로 보내라"는 명시적 지시다).
///
/// 위반 조건은 단순히 "정원 초과"가 아니라
/// **"적용 후 초과 AND 이 배정이 그 팀을 더 나쁘게 만들었다"** 다.
///
/// 비교가 `>=` 가 아니라 `>` 인 것이 핵심이다. 정원을 낮춰 여러 팀이 동시에
/// 초과한 상태에서는, 한 팀에서 사람을 빼는 배정이 **손대지 않아 적용 전 =
/// 적용 후인 다른 초과 팀**에 걸려 거부된다. 그러면 호스트가 초과 상태를
/// 복구할 수단이 없어진다. (prod 실측으로 잡은 버그)
bool assignmentsFitCapacity({
  required Map<String, String?> before,
  required Map<String, String?> incoming,
  required int capacity,
}) {
  if (capacity <= 0) return true;

  final beforeCounts = <String, int>{};
  final afterCounts = <String, int>{};

  for (final entry in before.entries) {
    final was = entry.value;
    if (was != null) {
      beforeCounts[was] = (beforeCounts[was] ?? 0) + 1;
    }
    final now = incoming.containsKey(entry.key) ? incoming[entry.key] : was;
    if (now != null) {
      afterCounts[now] = (afterCounts[now] ?? 0) + 1;
    }
  }

  for (final entry in afterCounts.entries) {
    final after = entry.value;
    if (after <= capacity) continue;
    if (after > (beforeCounts[entry.key] ?? 0)) return false;
  }
  return true;
}
