/// 상대 시간을 한국어로 표시.
/// - <1분: 방금
/// - <1시간: N분 전
/// - <24시간: N시간 전
/// - <30일: N일 전
/// - <12개월(=360일): N개월 전
/// - 그 외: N년 전
String formatTimeAgo(DateTime time, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(time);
  if (diff.inSeconds < 60) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 30) return '${diff.inDays}일 전';
  if (diff.inDays < 360) return '${diff.inDays ~/ 30}개월 전';
  return '${diff.inDays ~/ 365}년 전';
}
