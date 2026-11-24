import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text_field.dart';

/// 팀 이름을 받는 다이얼로그. 취소하면 `null`.
///
/// 호스트의 팀 관리 화면과 참가자의 `팀 만들기` 가 같은 입력을 쓴다.
/// 두 곳이 각자 들고 있으면 길이 제한(20자)이나 공백 처리가 갈라지고,
/// 그 차이가 서버 제약(`league_teams_name_not_blank`, RPC 의
/// `TEAM_NAME_TOO_LONG`) 과 어긋나는 쪽만 실패한다.
Future<String?> promptTeamName(
  BuildContext context, {
  required String title,
  String initial = '',
}) async {
  final ctrl = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: AppTextField(
        controller: ctrl,
        hint: '팀 이름',
        maxLength: 20,
        autofocus: true,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        TextButton(
          onPressed: () {
            final v = ctrl.text.trim();
            // 공백만 입력하면 서버가 거부한다. 닫지 않고 그대로 둔다.
            if (v.isEmpty) return;
            Navigator.pop(ctx, v);
          },
          child: const Text('확인'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return result;
}
