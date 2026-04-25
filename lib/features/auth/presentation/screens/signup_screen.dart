import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_svg.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../data/auth_repository.dart';
import '../../../../core/widgets/app_snack_bar.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final response = await ref.read(authRepositoryProvider).signUpWithEmail(
        _emailCtrl.text.trim(),
        _pwCtrl.text,
        _usernameCtrl.text.trim(),
      );

      if (!mounted) return;

      if (response.session != null) {
        // 이메일 확인 없이 바로 로그인됨
        context.go(AppRoutes.feed);
      } else {
        // 이메일 확인 필요
        _showEmailConfirmDialog();
      }
    } catch (e) {
      if (mounted) {
                AppSnackBar.error(context, _parseError(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _parseError(String error) {
    if (error.contains('already registered') || error.contains('already exists')) {
      return '이미 가입된 이메일입니다.';
    }
    if (error.contains('invalid email')) return '올바른 이메일 형식이 아닙니다.';
    if (error.contains('password')) return '비밀번호가 너무 약합니다. 6자 이상 입력해주세요.';
    return '회원가입에 실패했습니다. 다시 시도해주세요.';
  }

  Future<void> _showEmailConfirmDialog() async {
    await showConfirmDialog(
      context,
      title: '이메일 확인',
      content: '${_emailCtrl.text}으로 인증 메일을 발송했습니다.\n이메일을 확인한 후 로그인해주세요.',
      cancelText: null,
      confirmText: '로그인하러 가기',
      confirmColor: AppColors.navy,
    );
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final sub = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.go(AppRoutes.login),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: AppSvg(
                        AppIcons.fishingRod,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '회원가입',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'HUK에 오신 걸 환영합니다',
                      style: TextStyle(fontSize: 13, color: sub),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 닉네임
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(
                        hintText: '닉네임',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '닉네임을 입력해주세요';
                        if (v.trim().length < 2) return '2자 이상 입력해주세요';
                        if (v.trim().length > 20) return '20자 이하로 입력해주세요';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // 이메일
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: '이메일',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '이메일을 입력해주세요';
                        if (!v.contains('@') || !v.contains('.')) return '올바른 이메일 형식이 아닙니다';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // 비밀번호
                    TextFormField(
                      controller: _pwCtrl,
                      obscureText: _obscurePw,
                      decoration: InputDecoration(
                        hintText: '비밀번호 (6자 이상)',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePw ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePw = !_obscurePw),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '비밀번호를 입력해주세요';
                        if (v.length < 6) return '6자 이상 입력해주세요';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // 비밀번호 확인
                    TextFormField(
                      controller: _pwConfirmCtrl,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        hintText: '비밀번호 확인',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '비밀번호를 다시 입력해주세요';
                        if (v != _pwCtrl.text) return '비밀번호가 일치하지 않습니다';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _loading ? null : _signup,
                      child: _loading
                          ? SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            )
                          : const Text('가입하기'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('이미 계정이 있으신가요?  ', style: TextStyle(color: sub, fontSize: 13)),
                        GestureDetector(
                          onTap: () => context.go(AppRoutes.login),
                          child: Text(
                            '로그인',
                            style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
