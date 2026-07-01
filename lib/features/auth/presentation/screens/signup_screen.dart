import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_svg.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../legal/data/legal_versions.dart';
import '../../data/auth_repository.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';

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
  final _rrnFrontCtrl = TextEditingController(); // 생년월일 6자리
  final _rrnBackCtrl = TextEditingController(); // 성별 코드 1자리
  final _rrnBackFocus = FocusNode();
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  DateTime? _birthDate;
  String? _gender; // 'M' or 'F'
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeAge = false;
  bool _agreeMarketing = false;

  bool get _agreeAll =>
      _agreeTerms && _agreePrivacy && _agreeAge && _agreeMarketing;
  bool get _requiredAgreed => _agreeTerms && _agreePrivacy && _agreeAge;

  void _setAgreeAll(bool? v) {
    final next = v ?? false;
    setState(() {
      _agreeTerms = next;
      _agreePrivacy = next;
      _agreeAge = next;
      _agreeMarketing = next;
    });
  }

  /// 주민번호 앞 7자리 파싱.
  /// 반환: (birth, gender 'M'|'F') 또는 null (형식 오류).
  /// 코드: 1·5(남 19xx), 2·6(여 19xx), 3·7(남 20xx), 4·8(여 20xx)
  ({DateTime birth, String gender})? _parseRrn(String s) {
    if (s.length != 7) return null;
    if (!RegExp(r'^\d{7}$').hasMatch(s)) return null;
    final yy = int.parse(s.substring(0, 2));
    final mm = int.parse(s.substring(2, 4));
    final dd = int.parse(s.substring(4, 6));
    final code = int.parse(s.substring(6, 7));

    int year;
    String gender;
    switch (code) {
      case 1:
      case 5:
        year = 1900 + yy;
        gender = 'M';
        break;
      case 2:
      case 6:
        year = 1900 + yy;
        gender = 'F';
        break;
      case 3:
      case 7:
        year = 2000 + yy;
        gender = 'M';
        break;
      case 4:
      case 8:
        year = 2000 + yy;
        gender = 'F';
        break;
      default:
        return null;
    }

    if (mm < 1 || mm > 12) return null;
    if (dd < 1 || dd > 31) return null;
    final birth = DateTime(year, mm, dd);
    if (birth.year != year || birth.month != mm || birth.day != dd) {
      return null; // 2월 30일 같은 비정상 날짜
    }
    if (birth.isAfter(DateTime.now())) return null;
    return (birth: birth, gender: gender);
  }

  void _onRrnChanged() {
    final combined = '${_rrnFrontCtrl.text}${_rrnBackCtrl.text}';
    // 앞 6자리 채워지면 자동으로 뒷자리로 포커스 이동
    if (_rrnFrontCtrl.text.length == 6 && !_rrnBackFocus.hasFocus) {
      _rrnBackFocus.requestFocus();
    }
    final parsed = _parseRrn(combined);
    setState(() {
      if (parsed != null) {
        _birthDate = parsed.birth;
        _gender = parsed.gender;
      } else {
        _birthDate = null;
        _gender = null;
      }
    });
  }

  bool _isUnder14(DateTime birth) {
    final now = DateTime.now();
    final age = now.year -
        birth.year -
        ((now.month < birth.month ||
                (now.month == birth.month && now.day < birth.day))
            ? 1
            : 0);
    return age < 14;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    _usernameCtrl.dispose();
    _rrnFrontCtrl.dispose();
    _rrnBackCtrl.dispose();
    _rrnBackFocus.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null || _gender == null) {
      AppSnackBar.warning(context, '올바른 생년월일·성별 코드가 아닙니다');
      return;
    }
    if (_isUnder14(_birthDate!)) {
      AppSnackBar.error(context, '만 14세 미만은 가입할 수 없습니다');
      return;
    }
    if (!_requiredAgreed) {
      AppSnackBar.warning(context, '필수 약관에 동의해주세요');
      return;
    }
    setState(() => _loading = true);

    try {
      final response = await ref.read(authRepositoryProvider).signUpWithEmail(
        _emailCtrl.text.trim(),
        _pwCtrl.text,
        _usernameCtrl.text.trim(),
        birthDate: _birthDate!,
        gender: _gender!,
        marketingAgreed: _agreeMarketing,
        termsVersion: LegalVersions.terms,
        privacyVersion: LegalVersions.privacy,
        marketingVersion: LegalVersions.marketing,
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
    final sub = context.isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft,
              size: 24, color: context.isDark ? Colors.white : Colors.black),
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
                    AppSvg(
                      'assets/images/nak_logo.svg',
                      width: 96,
                      color: context.accentColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '회원가입',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nakstar에 오신 걸 환영합니다',
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
                      autofillHints: const [AutofillHints.nickname],
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
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
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
                      autofillHints: const [AutofillHints.newPassword],
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
                      autofillHints: const [AutofillHints.newPassword],
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
                    const SizedBox(height: 12),
                    // 주민번호 앞 7자리 (생년월일 6 + 성별 1)
                    Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: TextFormField(
                            controller: _rrnFrontCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => _onRrnChanged(),
                            decoration: const InputDecoration(
                              hintText: '901223',
                              prefixIcon:
                                  Icon(Icons.badge_outlined, size: 20),
                              counterText: '',
                            ),
                            validator: (v) {
                              if ((v ?? '').length != 6) return '6자리';
                              return null;
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '-',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: sub,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: TextFormField(
                            controller: _rrnBackCtrl,
                            focusNode: _rrnBackFocus,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => _onRrnChanged(),
                            decoration: const InputDecoration(
                              hintText: '1',
                              counterText: '',
                            ),
                            validator: (v) {
                              if ((v ?? '').isEmpty) return ' ';
                              return null;
                            },
                          ),
                        ),
                        // 뒤 6자리 마스킹 표시 (입력 X, 시각적 표시만)
                        const SizedBox(width: 6),
                        Text(
                          '••••••',
                          style: TextStyle(
                            fontSize: 16,
                            letterSpacing: 2,
                            color: sub,
                          ),
                        ),
                      ],
                    ),
                    // 7자리 다 입력했는데 파싱 실패한 경우에만 에러 표시
                    if (_rrnFrontCtrl.text.length == 6 &&
                        _rrnBackCtrl.text.length == 1 &&
                        _birthDate == null) ...[
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          '올바른 생년월일·성별 코드가 아닙니다',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _ConsentSection(
                      agreeAll: _agreeAll,
                      agreeTerms: _agreeTerms,
                      agreePrivacy: _agreePrivacy,
                      agreeAge: _agreeAge,
                      agreeMarketing: _agreeMarketing,
                      onAgreeAll: _setAgreeAll,
                      onAgreeTerms: (v) =>
                          setState(() => _agreeTerms = v ?? false),
                      onAgreePrivacy: (v) =>
                          setState(() => _agreePrivacy = v ?? false),
                      onAgreeAge: (v) =>
                          setState(() => _agreeAge = v ?? false),
                      onAgreeMarketing: (v) =>
                          setState(() => _agreeMarketing = v ?? false),
                      onTapTerms: () => context.push(AppRoutes.terms),
                      onTapPrivacy: () => context.push(AppRoutes.privacy),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: '가입하기',
                      onPressed: _loading ? null : _signup,
                      loading: _loading,
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
                            style: TextStyle(color: context.accentColor, fontWeight: FontWeight.w700, fontSize: 13),
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

class _ConsentSection extends StatelessWidget {
  const _ConsentSection({
    required this.agreeAll,
    required this.agreeTerms,
    required this.agreePrivacy,
    required this.agreeAge,
    required this.agreeMarketing,
    required this.onAgreeAll,
    required this.onAgreeTerms,
    required this.onAgreePrivacy,
    required this.onAgreeAge,
    required this.onAgreeMarketing,
    required this.onTapTerms,
    required this.onTapPrivacy,
  });

  final bool agreeAll;
  final bool agreeTerms;
  final bool agreePrivacy;
  final bool agreeAge;
  final bool agreeMarketing;
  final ValueChanged<bool?> onAgreeAll;
  final ValueChanged<bool?> onAgreeTerms;
  final ValueChanged<bool?> onAgreePrivacy;
  final ValueChanged<bool?> onAgreeAge;
  final ValueChanged<bool?> onAgreeMarketing;
  final VoidCallback onTapTerms;
  final VoidCallback onTapPrivacy;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final divColor =
        isDark ? AppColors.darkSurface2 : AppColors.lightDivider;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: divColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _ConsentRow(
            value: agreeAll,
            onChanged: onAgreeAll,
            label: '전체 동의',
            bold: true,
          ),
          Divider(height: 1, color: divColor),
          _ConsentRow(
            value: agreeAge,
            onChanged: onAgreeAge,
            label: '[필수] 만 14세 이상입니다',
          ),
          Divider(height: 1, color: divColor, indent: 12, endIndent: 12),
          _ConsentRow(
            value: agreeTerms,
            onChanged: onAgreeTerms,
            label: '[필수] 서비스 이용약관 동의',
            trailingLabel: '보기',
            onTrailingTap: onTapTerms,
          ),
          Divider(height: 1, color: divColor, indent: 12, endIndent: 12),
          _ConsentRow(
            value: agreePrivacy,
            onChanged: onAgreePrivacy,
            label: '[필수] 개인정보 수집·이용 동의',
            trailingLabel: '보기',
            onTrailingTap: onTapPrivacy,
          ),
          Divider(height: 1, color: divColor, indent: 12, endIndent: 12),
          _ConsentRow(
            value: agreeMarketing,
            onChanged: onAgreeMarketing,
            label: '[선택] 마케팅 정보 수신 동의',
          ),
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.label,
    this.bold = false,
    this.trailingLabel,
    this.onTrailingTap,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;
  final bool bold;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            if (trailingLabel != null)
              TextButton(
                onPressed: onTrailingTap,
                style: TextButton.styleFrom(
                  minimumSize: const Size(40, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  trailingLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.accentColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
