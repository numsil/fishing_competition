import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../data/league_repository.dart';
import 'catch_review_item.dart';

class CatchReviewTab extends ConsumerWidget {
  const CatchReviewTab({super.key, required this.leagueId});
  final String leagueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final postsAsync = ref.watch(leagueCatchesForReviewProvider(leagueId));

    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Text(
              '등록된 조과가 없습니다',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return CatchReviewItem(
              post: post,
              isDark: isDark,
              onHold: () async {
                try {
                  await ref.read(leagueRepositoryProvider).holdPost(post.id);
                  ref.invalidate(leagueCatchesForReviewProvider(leagueId));
                  ref.invalidate(leagueRankingProvider(leagueId));
                } catch (e) {
                  if (context.mounted) {
                    AppSnackBar.error(context, '보류 처리 실패: $e');
                  }
                }
              },
              onUnhold: () async {
                try {
                  await ref.read(leagueRepositoryProvider).unholdPost(post.id);
                  ref.invalidate(leagueCatchesForReviewProvider(leagueId));
                  ref.invalidate(leagueRankingProvider(leagueId));
                } catch (e) {
                  if (context.mounted) {
                    AppSnackBar.error(context, '보류 해지 실패: $e');
                  }
                }
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('불러오기 실패: $e')),
    );
  }
}
