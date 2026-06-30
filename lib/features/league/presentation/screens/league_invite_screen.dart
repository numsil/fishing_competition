import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/league_invite_repository.dart';

class LeagueInviteScreen extends ConsumerStatefulWidget {
  const LeagueInviteScreen({
    super.key,
    required this.leagueId,
    required this.leagueTitle,
    required this.inviterUsername,
  });

  final String leagueId;
  final String leagueTitle;
  final String inviterUsername;

  @override
  ConsumerState<LeagueInviteScreen> createState() => _LeagueInviteScreenState();
}

class _LeagueInviteScreenState extends ConsumerState<LeagueInviteScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  bool _inviting = false;
  bool _searched = false;
  LeagueInviteUserHit? _hit;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searched = false;
      _hit = null;
    });
    try {
      final hit = await ref
          .read(leagueInviteRepositoryProvider)
          .findUserByKey(_searchCtrl.text);
      if (mounted) setState(() => _hit = hit);
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '검색 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
          _searched = true;
        });
      }
    }
  }

  Future<void> _onInvite(LeagueInviteUserHit hit) async {
    setState(() => _inviting = true);
    try {
      await ref.read(leagueInviteRepositoryProvider).inviteUser(
            leagueId: widget.leagueId,
            leagueTitle: widget.leagueTitle,
            inviteeId: hit.id,
            inviterUsername: widget.inviterUsername,
          );
      ref.invalidate(sentLeagueInvitesProvider(widget.leagueId));
      if (mounted) {
        AppSnackBar.success(context, '@${hit.userKey}님께 초대를 보냈어요');
        setState(() {
          _hit = null;
          _searched = false;
          _searchCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _humanizeError(e));
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  Future<void> _onCancel(LeagueInvite inv) async {
    try {
      await ref.read(leagueInviteRepositoryProvider).cancelInvite(inv.id);
      ref.invalidate(sentLeagueInvitesProvider(widget.leagueId));
      if (mounted) AppSnackBar.info(context, '초대를 취소했어요');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, _humanizeError(e));
    }
  }

  String _humanizeError(Object e) {
    final s = e.toString();
    // PostgrestException 메시지 안에 한글이 들어있으면 그대로 노출
    final m = RegExp(r'message:\s*([^,}]+)').firstMatch(s);
    if (m != null) return m.group(1)!.trim();
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final sentAsync = ref.watch(sentLeagueInvitesProvider(widget.leagueId));

    return Scaffold(
      appBar: AppBar(title: const Text('유저 초대')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sentLeagueInvitesProvider(widget.leagueId));
          await ref.read(sentLeagueInvitesProvider(widget.leagueId).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // 안내
            Text(
              "@고유 이름으로 초대할 유저를 찾을 수 있어요.\n초대받은 사람만 비공개 리그에 참여할 수 있어요.",
              style: TextStyle(fontSize: 12, color: sub, height: 1.5),
            ),
            const SizedBox(height: 16),

            // 검색
            AppTextField(
              controller: _searchCtrl,
              hint: '고유 이름 (예: jun_fish)',
              prefixIcon: const Icon(LucideIcons.atSign, size: 18),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _onSearch(),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: '검색',
              icon: LucideIcons.search,
              loading: _searching,
              onPressed: _searching ? null : _onSearch,
            ),
            const SizedBox(height: 20),

            // 검색 결과
            if (_searched && !_searching)
              _hit == null
                  ? _NotFound()
                  : _UserHitCard(
                      hit: _hit!,
                      onInvite: _inviting ? null : () => _onInvite(_hit!),
                      inviting: _inviting,
                    ),

            const SizedBox(height: 28),
            Text(
              '보낸 초대',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),

            sentAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('불러오기 실패: $e',
                    style: TextStyle(color: AppColors.error, fontSize: 12)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: EmptyState(
                      icon: LucideIcons.mailOpen,
                      message: '보낸 초대가 없어요',
                      subColor: sub,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final inv in list)
                      _SentInviteTile(
                        invite: inv,
                        isDark: isDark,
                        onCancel: () => _onCancel(inv),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// 검색 결과 카드
// ──────────────────────────────────────────
class _UserHitCard extends StatelessWidget {
  const _UserHitCard({
    required this.hit,
    required this.onInvite,
    required this.inviting,
  });
  final LeagueInviteUserHit hit;
  final VoidCallback? onInvite;
  final bool inviting;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final border = isDark ? AppColors.darkSurface2 : AppColors.lightDivider;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: 14,
      borderColor: border,
      child: Row(
        children: [
          UserAvatar(
            username: hit.username,
            avatarUrl: hit.avatarUrl,
            radius: 22,
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hit.username,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@${hit.userKey}',
                  style: TextStyle(fontSize: 12, color: sub),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: AppButton(
              label: '초대',
              size: AppButtonSize.sm,
              loading: inviting,
              onPressed: onInvite,
              fullWidth: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: 14,
      borderColor: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
      child: Row(
        children: [
          Icon(LucideIcons.userX, size: 18, color: sub),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '해당 고유 이름의 유저를 찾을 수 없어요.',
              style: TextStyle(fontSize: 13, color: sub),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// 보낸 초대 타일
// ──────────────────────────────────────────
class _SentInviteTile extends StatelessWidget {
  const _SentInviteTile({
    required this.invite,
    required this.isDark,
    required this.onCancel,
  });
  final LeagueInvite invite;
  final bool isDark;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        radius: 12,
        borderColor: isDark ? AppColors.darkSurface2 : AppColors.lightDivider,
        child: Row(
        children: [
          UserAvatar(
            username: invite.inviteeUsername ?? '?',
            avatarUrl: invite.inviteeAvatarUrl,
            radius: 18,
            isDark: isDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.inviteeUsername ?? '알 수 없음',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@${invite.inviteeUserKey ?? ''}',
                  style: TextStyle(fontSize: 11, color: sub),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('취소', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      ),
    );
  }
}
