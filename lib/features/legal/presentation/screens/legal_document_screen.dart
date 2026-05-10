import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';

enum LegalDocType { terms, privacy }

class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen({super.key, required this.type});

  final LegalDocType type;

  String get _title {
    switch (type) {
      case LegalDocType.terms:
        return '서비스 이용약관';
      case LegalDocType.privacy:
        return '개인정보처리방침';
    }
  }

  String get _body {
    // TODO: 실제 약관/개인정보처리방침 본문으로 교체
    // 본문이 준비되면 assets/legal/terms.md, privacy.md 로 옮기고 여기서 로드
    switch (type) {
      case LegalDocType.terms:
        return '''(본문 준비 중)

본 약관 본문은 출시 전 법무 검토 후 최종본으로 교체됩니다.

문의: support@nakstar.app''';
      case LegalDocType.privacy:
        return '''(본문 준비 중)

본 개인정보처리방침 본문은 출시 전 최종본으로 교체됩니다.

수집 항목 (예정):
• 필수: 이메일, 닉네임, 비밀번호, 생년월일
• 선택: 프로필 사진, 위치(조과 기록 시)

이용 목적:
• 회원 식별 및 서비스 제공
• 부정 이용 방지

보유 기간: 회원 탈퇴 시까지

문의: support@nakstar.app''';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(_title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Text(
          _body,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ),
    );
  }
}
