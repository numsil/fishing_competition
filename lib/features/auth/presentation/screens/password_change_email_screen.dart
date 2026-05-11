import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/auth_repository.dart';

/// 1단계: 이메일 입력 → OTP 발송.
/// 로그인 상태면 이메일 자동 채움 + 잠금 (다른 사람 계정 비번 변경 방지).
class PasswordChangeEmailScreen extends ConsumerStatefulWidget {
  const PasswordChangeEmailScreen({super.key});

  @override
  ConsumerState<PasswordChangeEmailScreen> createState() =>
      _PasswordChangeEmailScreenState();
}

class _PasswordChangeEmailScreenState
    extends ConsumerState<PasswordChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    final me = ref.read(currentUserProvider);
    if (me?.email != null) {
      _emailCtrl.text = me!.email!;
      _isLoggedIn = true;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).requestPasswordOtp(email);
      if (!mounted) return;
      context.push(AppRoutes.passwordChangeOtp, extra: email);
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '메일 발송에 실패했습니다');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final sub = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(_isLoggedIn ? '비밀번호 변경' : '비밀번호 찾기',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoggedIn
                      ? '아래 이메일로 인증 코드를 발송합니다.'
                      : '가입 시 사용한 이메일을 입력하세요.\n가입된 이메일이 아닐 경우 코드가 발송되지 않습니다.',
                  style: TextStyle(fontSize: 13, color: sub, height: 1.5),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoggedIn,
                  decoration: InputDecoration(
                    hintText: '이메일',
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                    helperText: _isLoggedIn ? '가입 이메일 (변경 불가)' : null,
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return '이메일을 입력해주세요';
                    if (!s.contains('@') || !s.contains('.')) {
                      return '올바른 이메일 형식이 아닙니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                AppButton(
                  label: '인증 코드 받기',
                  onPressed: _loading ? null : _sendOtp,
                  loading: _loading,
                ),
                const SizedBox(height: 16),
                Text(
                  '· 인증 코드는 1시간 동안 유효합니다.\n'
                  '· 메일이 도착하지 않으면 스팸함 또는 가입 여부를 확인해주세요.',
                  style: TextStyle(fontSize: 11, color: sub, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
