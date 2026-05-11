import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/auth_repository.dart';

/// 2단계: OTP + 새 비밀번호 입력.
/// 성공 시 자동 로그인 상태가 되어 피드로 이동.
class PasswordChangeOtpScreen extends ConsumerStatefulWidget {
  const PasswordChangeOtpScreen({super.key, required this.email});
  final String email;

  @override
  ConsumerState<PasswordChangeOtpScreen> createState() =>
      _PasswordChangeOtpScreenState();
}

class _PasswordChangeOtpScreenState
    extends ConsumerState<PasswordChangeOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  // OTP 가 한번 인증되면 다음 시도부터는 updateUser 만 호출 (OTP 재사용 방지).
  bool _otpVerified = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final repo = ref.read(authRepositoryProvider);
    try {
      // 1단계: OTP 검증 (이미 검증됐으면 스킵 — 같은 OTP 재사용 시 실패하기 때문)
      if (!_otpVerified) {
        try {
          await repo.verifyPasswordOtp(
            email: widget.email,
            token: _otpCtrl.text.trim(),
          );
          _otpVerified = true;
        } catch (e) {
          if (!mounted) return;
          final msg = e.toString();
          if (msg.contains('blocked')) {
            context.go(AppRoutes.login);
            return;
          }
          AppSnackBar.error(context, '인증 코드가 잘못되었거나 만료되었습니다');
          return;
        }
      }

      // 2단계: 비번 업데이트 — 실패해도 _otpVerified 유지하므로 OTP 재발급 불필요
      try {
        await repo.changePasswordWithSession(_pwCtrl.text);
      } on AuthException catch (e) {
        if (!mounted) return;
        final m = e.message.toLowerCase();
        // Supabase same_password (422): "New password should be different from the old password"
        if (e.statusCode == '422' ||
            m.contains('different from the old') ||
            m.contains('same as the old') ||
            m.contains('same_password')) {
          AppSnackBar.error(context, '기존 비밀번호와 동일한 비밀번호로는 변경할 수 없습니다');
        } else {
          AppSnackBar.error(context, '비밀번호 변경에 실패했습니다');
        }
        return;
      }

      if (!mounted) return;
      AppSnackBar.success(context, '비밀번호가 변경되었습니다');
      context.go(AppRoutes.feed);
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
        title: const Text('비밀번호 변경',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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
                  '${widget.email} 으로 인증 코드를 발송했습니다.\n메일에 적힌 코드를 입력해주세요.\n(가입된 이메일이 아니면 메일이 발송되지 않습니다)',
                  style: TextStyle(fontSize: 13, color: sub, height: 1.5),
                ),
                const SizedBox(height: 24),
                // OTP (Supabase 설정에 따라 6~8자리)
                Text(
                  '인증 코드',
                  style: TextStyle(
                    fontSize: 12,
                    color: sub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 8,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w700,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    hintText: '- - - - - - - -',
                    counterText: '',
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.length < 6 || s.length > 8) {
                      return '인증 코드를 정확히 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // 새 비밀번호
                TextFormField(
                  controller: _pwCtrl,
                  obscureText: _obscurePw,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    hintText: '새 비밀번호 (6자 이상)',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePw
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePw = !_obscurePw),
                    ),
                  ),
                  validator: (v) {
                    if ((v ?? '').isEmpty) return '비밀번호를 입력해주세요';
                    if (v!.length < 6) return '6자 이상 입력해주세요';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // 비밀번호 확인
                TextFormField(
                  controller: _pwConfirmCtrl,
                  obscureText: _obscureConfirm,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    hintText: '새 비밀번호 확인',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if ((v ?? '').isEmpty) return '비밀번호를 다시 입력해주세요';
                    if (v != _pwCtrl.text) return '비밀번호가 일치하지 않습니다';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                AppButton(
                  label: '비밀번호 변경',
                  onPressed: _loading ? null : _submit,
                  loading: _loading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
