import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/league_repository.dart';
import '../../data/league_team_model.dart';
import '../../data/team_capacity.dart';

/// 참가자가 자기 팀을 고르는 화면. 자율 선택 리그에서만 진입한다.
///
/// 호스트도 참가자라면 똑같이 쓸 수 있다 — 자기 팀을 고르는 것이고,
/// 남을 배정하는 건 팀 관리 화면이다.
class LeagueMyTeamScreen extends ConsumerStatefulWidget {
  const LeagueMyTeamScreen({super.key, required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<LeagueMyTeamScreen> createState() => _LeagueMyTeamScreenState();
}

class _LeagueMyTeamScreenState extends ConsumerState<LeagueMyTeamScreen> {
  final _search = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick(String? teamId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(leagueRepositoryProvider).setMyLeagueTeam(
            leagueId: widget.leagueId,
            teamId: teamId,
          );
      ref.invalidate(leagueTeamsProvider(widget.leagueId));
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      // 목록이 바뀌어 꽉 찬 팀을 눌렀을 수 있으니 다시 받는다.
      ref.invalidate(leagueTeamsProvider(widget.leagueId));
      if (mounted) AppSnackBar.error(context, _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object e) {
    final s = e.toString();
    // UI 가 꽉 찬 팀을 미리 비활성화하므로, 이 에러가 실제로 뜨는 경우는
    // 다른 사람이 먼저 들어간 경합뿐이다.
    if (s.contains('TEAM_FULL')) return '방금 정원이 찼습니다. 다른 팀을 골라주세요.';
    if (s.contains('SELF_PICK_DISABLED')) return '이 리그는 호스트가 팀을 배정합니다.';
    if (s.contains('NOT_PARTICIPANT')) return '이 리그의 참가자가 아닙니다.';
    if (s.contains('TEAM_NOT_IN_LEAGUE')) {
      return '팀 정보가 바뀌었습니다. 새로고침 해주세요.';
    }
    if (s.contains('AUTH_REQUIRED') || s.contains('LEAGUE_NOT_FOUND')) {
      return '다시 시도해주세요.';
    }
    return '처리에 실패했습니다: $e';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accent = context.accentColor;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;

    final leagueAsync = ref.watch(leagueDetailProvider(widget.leagueId));
    final teamsAsync = ref.watch(leagueTeamsProvider(widget.leagueId));
    final rankingAsync = ref.watch(leagueRankingProvider(widget.leagueId));
    final myUserId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('내 팀 선택')),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('팀 정보를 불러오지 못했습니다: $e')),
        data: (teams) {
          final capacity = leagueAsync.valueOrNull?.teamCapacity ?? 0;
          final ranking = rankingAsync.valueOrNull ?? const <LeagueRankEntry>[];
          final entryByUserId = {for (final e in ranking) e.userId: e};

          LeagueTeam? myTeam;
          if (myUserId != null) {
            for (final t in teams) {
              if (t.memberUserIds.contains(myUserId)) {
                myTeam = t;
                break;
              }
            }
          }

          final q = _search.text.trim().toLowerCase();
          final shown = q.isEmpty
              ? teams
              : teams
                  .where((t) => t.name.toLowerCase().contains(q))
                  .toList(growable: false);

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(
                '고르면 바로 반영됩니다. 리그 중에도 바꿀 수 있고, 등록한 조과는 따라옵니다.',
                style: AppTextStyles.caption.copyWith(color: sub, height: 1.55),
              ),
            ),
            if (teams.length >= 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: AppTextField(
                  controller: _search,
                  hint: '팀 이름으로 찾기',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            if (teams.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.users, size: 48, color: sub),
                        const SizedBox(height: 12),
                        Text('아직 팀이 없습니다',
                            style:
                                AppTextStyles.body.copyWith(color: sub)),
                        const SizedBox(height: 6),
                        Text('호스트가 팀을 만들면 선택할 수 있습니다.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption
                                .copyWith(color: sub, height: 1.5)),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final t = shown[i];
                    final count = t.memberUserIds.length;
                    final isMine = t.id == myTeam?.id;
                    // 내 팀은 내가 이미 한 자리를 차지하고 있으므로 꽉 차 보여도
                    // 비활성으로 두면 안 된다 (RPC 도 본인을 빼고 세어 통과한다).
                    final full = !isMine &&
                        isTeamFull(capacity: capacity, memberCount: count);
                    final left =
                        remainingSlots(capacity: capacity, memberCount: count);

                    return Opacity(
                      opacity: full ? 0.45 : 1,
                      child: AppCard(
                        variant: AppCardVariant.surface,
                        radius: 14,
                        borderColor: isMine ? accent : divColor,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: EdgeInsets.zero,
                        child: InkWell(
                          onTap: (full || _busy || isMine)
                              ? null
                              : () => _pick(t.id),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                    color: AppColors.teamColor(t.color),
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.heading4),
                                    const SizedBox(height: 3),
                                    Text(
                                      _subtitle(
                                        isMine: isMine,
                                        full: full,
                                        count: count,
                                        capacity: capacity,
                                        left: left,
                                      ),
                                      style: AppTextStyles.caption.copyWith(
                                        color: isMine
                                            ? accent
                                            : (full ? AppColors.warning : sub),
                                        fontWeight: (isMine || full)
                                            ? FontWeight.w700
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _Avatars(
                                userIds: t.memberUserIds,
                                entries: entryByUserId,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 6),
                              if (isMine)
                                Icon(LucideIcons.check, size: 20, color: accent)
                              else if (full)
                                Icon(LucideIcons.lock, size: 17, color: sub)
                              else
                                Icon(LucideIcons.chevronRight,
                                    size: 18, color: sub),
                            ]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (myTeam != null)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(children: [
                    AppButton(
                      label: '팀에서 나가기',
                      variant: AppButtonVariant.outline,
                      onPressed: _busy ? null : () => _pick(null),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '나가면 미배정이 되고 내 조과는 팀 점수에서 빠집니다',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption
                          .copyWith(color: sub, height: 1.5),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }

  String _subtitle({
    required bool isMine,
    required bool full,
    required int count,
    required int capacity,
    required int left,
  }) {
    final label = capacityLabel(capacity: capacity, memberCount: count);
    if (isMine) return '현재 내 팀 · $label';
    if (full) return '$label · 정원 마감';
    if (count == 0) return '$label · 아직 비어 있음';
    if (left < 0) return label;
    return '$label · $left자리 남음';
  }
}

/// 팀 멤버 아바타 최대 3개 + 나머지 수.
class _Avatars extends StatelessWidget {
  const _Avatars({
    required this.userIds,
    required this.entries,
    required this.isDark,
  });

  final List<String> userIds;
  final Map<String, LeagueRankEntry> entries;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final known = [
      for (final uid in userIds)
        if (entries[uid] != null) entries[uid]!,
    ];
    if (known.isEmpty) return const SizedBox.shrink();
    final head = known.take(3).toList(growable: false);
    final rest = known.length - head.length;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final e in head)
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: UserAvatar(
              username: e.username,
              avatarUrl: e.avatarUrl,
              radius: 12,
              isDark: isDark),
        ),
      if (rest > 0)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child:
              Text('+$rest', style: AppTextStyles.caption.copyWith(color: sub)),
        ),
    ]);
  }
}
