import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/auth_repository.dart';

/// 회원 탈퇴 확인 다이얼로그 → soft-delete → 로그인 화면 이동.
/// profile_screen 설정 시트, profile_edit 하단 등에서 공통 사용.
Future<void> showWithdrawFlow(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('회원 탈퇴'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '탈퇴 시 다음 사항을 확인해주세요.\n\n'
            '• 작성하신 게시물·조과 기록은 즉시 비공개 처리됩니다\n'
            '• 동일 이메일로 재가입할 수 없습니다\n'
            '• 탈퇴 후 30일간 복구 문의가 가능합니다 (support@nakstar.app)\n\n'
            '계속하려면 아래에 "탈퇴"를 입력해주세요.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '탈퇴',
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, __) => TextButton(
            onPressed: value.text.trim() == '탈퇴'
                ? () => Navigator.pop(ctx, true)
                : null,
            child: const Text('탈퇴',
                style: TextStyle(color: AppColors.error)),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  if (!context.mounted) return;

  try {
    // navigate 먼저: signOut으로 myProfile 재빌드 시 에러 화면 회피
    context.go(AppRoutes.login);
    await ref.read(authRepositoryProvider).withdraw();
  } catch (_) {
    if (context.mounted) {
      AppSnackBar.error(context, '탈퇴 처리에 실패했습니다');
    }
  }
}
