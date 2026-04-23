import 'package:flutter/material.dart';
import '../../../league/presentation/screens/league_detail_screen.dart';

/// 나의 리그 상세 — LeagueDetailScreen으로 위임
class MyLeagueDetailScreen extends StatelessWidget {
  const MyLeagueDetailScreen({
    super.key,
    required this.leagueId,
    this.type, // 더 이상 사용하지 않음, 라우터 호환용으로만 유지
  });

  final String leagueId;
  final String? type;

  @override
  Widget build(BuildContext context) {
    return LeagueDetailScreen(leagueId: leagueId);
  }
}
