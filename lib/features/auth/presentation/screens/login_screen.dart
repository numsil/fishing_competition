import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_svg.dart';
import '../../data/auth_repository.dart';
import '../../../../core/widgets/app_snack_bar.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(
        _emailCtrl.text,
        _pwCtrl.text,
      );
      if (mounted) {
        context.go(AppRoutes.feed);
      }
    } catch (e) {
      if (mounted) {
                AppSnackBar.error(context, '로그인 실패: 이메일과 비밀번호를 확인해주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonGreen : AppColors.navy;
    final sub = isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 64),
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/huk_logo.png',
                      width: 110,
                      height: 110,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '우리 동네 낚시 리그 & 조과 SNS',
                      style: TextStyle(fontSize: 13, color: sub),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: '이메일',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      validator: (v) {
                        if (v?.isEmpty == true) return '이메일을 입력해주세요';
                        if (!v!.contains('@')) return '올바른 이메일 형식이 아닙니다';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pwCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: '비밀번호',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v?.isEmpty == true) return '비밀번호를 입력해주세요';
                        if (v!.length < 6) return '6자 이상 입력해주세요';
                        return null;
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text('비밀번호 찾기', style: TextStyle(color: sub, fontSize: 12)),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            )
                          : const Text('로그인'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Divider(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('OR', style: TextStyle(fontSize: 11, color: sub)),
                        ),
                        Expanded(child: Divider(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => context.go(AppRoutes.feed),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEE500),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('카카오로 시작하기', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('계정이 없으신가요?  ', style: TextStyle(color: sub, fontSize: 13)),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.signup),
                    child: Text('회원가입', style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
