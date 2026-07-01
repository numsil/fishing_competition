import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../../core/widgets/menu_item.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../auth/presentation/utils/withdraw_flow.dart';
import '../../data/profile_repository.dart';
import 'package:go_router/go_router.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key, required this.profile});
  final UserProfile profile;

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _userKeyCtrl;

  bool _loading = false;
  bool _uploadingAvatar = false;

  // user_key 중복 체크 상태
  bool? _userKeyAvailable; // null = 미확인, true = 사용가능, false = 사용불가
  bool _checkingUserKey = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.profile.username);
    _userKeyCtrl = TextEditingController(text: widget.profile.userKey);
    _userKeyCtrl.addListener(_onUserKeyChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameCtrl.dispose();
    _userKeyCtrl.dispose();
    super.dispose();
  }

  void _onUserKeyChanged() {
    final value = _userKeyCtrl.text.trim();
    _debounce?.cancel();

    if (value == widget.profile.userKey) {
      setState(() => _userKeyAvailable = true);
      return;
    }

    if (value.length < 2) {
      setState(() => _userKeyAvailable = null);
      return;
    }

    setState(() {
      _checkingUserKey = true;
      _userKeyAvailable = null;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final available =
          await ref.read(profileRepositoryProvider).isUserKeyAvailable(value);
      if (mounted) {
        setState(() {
          _userKeyAvailable = available;
          _checkingUserKey = false;
        });
      }
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    final choice = await showAppActionSheet<ImageSource>(
      context,
      items: [
        AppMenuItem(
          icon: LucideIcons.camera,
          label: '카메라로 촬영',
          showIcon: true,
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        AppMenuItem(
          icon: LucideIcons.image,
          label: '갤러리에서 선택',
          showIcon: true,
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
      ],
    );

    if (choice == null) return;

    final picked = await ImagePicker().pickImage(
      source: choice,
      imageQuality: 85,
      maxWidth: 400,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(File(picked.path));
      ref.invalidate(myProfileProvider);
      if (mounted) AppSnackBar.success(context, '프로필 사진이 업데이트되었습니다!');
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '업로드 실패: $e');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    final username = _usernameCtrl.text.trim();
    final userKey = _userKeyCtrl.text.trim();

    if (username.isEmpty) {
      AppSnackBar.error(context, '닉네임을 입력해주세요');
      return;
    }
    if (username.length < 2) {
      AppSnackBar.error(context, '닉네임은 2자 이상 입력해주세요');
      return;
    }
    if (userKey.length < 2) {
      AppSnackBar.error(context, '고유 이름은 2자 이상 입력해주세요');
      return;
    }
    if (_userKeyAvailable == false) {
      AppSnackBar.error(context, '이미 사용중인 고유 이름입니다');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            username: username != widget.profile.username ? username : null,
            userKey: userKey != widget.profile.userKey ? userKey : null,
          );
      ref.invalidate(myProfileProvider);
      if (mounted) {
        AppSnackBar.success(context, '프로필이 업데이트되었습니다!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub =
        context.isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA);
    final profile = ref.watch(myProfileProvider).valueOrNull ?? widget.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 수정',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '저장',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: context.accentColor,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 사진
            Center(
              child: GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color:
                              context.accentColor.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _uploadingAvatar
                            ? Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: context.accentColor,
                                ),
                              )
                            : profile.avatarUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: profile.avatarUrl!,
                                    fit: BoxFit.cover,
                                    width: 96,
                                    height: 96,
                                  )
                                : Container(
                                    color: context.isDark
                                        ? AppColors.darkSurface2
                                        : const Color(0xFFF0F0F0),
                                    child: Center(
                                      child: Text(
                                        profile.username.isNotEmpty
                                            ? profile.username[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: context.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.isDark
                                ? AppColors.darkBg
                                : Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: context.isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),

            // 가입 이메일 (수정 불가)
            _Label(text: '가입 이메일'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: context.isDark
                    ? AppColors.darkSurface
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.isDark
                      ? AppColors.darkSurface2
                      : AppColors.lightDivider,
                ),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.mail, size: 18, color: sub),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.profile.email ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text('가입 시 사용한 이메일이며 변경할 수 없습니다.',
                style: TextStyle(fontSize: 11, color: sub)),
            const SizedBox(height: 24),

            // 닉네임
            _Label(text: '닉네임'),
            const SizedBox(height: 8),
            AppTextField(
              controller: _usernameCtrl,
              maxLength: 20,
              hint: '닉네임 입력',
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
            ),
            const SizedBox(height: 4),
            Text('피드, 랭킹 등에 표시되는 이름입니다. 중복 가능합니다.',
                style: TextStyle(fontSize: 11, color: sub)),
            const SizedBox(height: 24),

            // 고유 이름 (user_key)
            _Label(text: '고유 이름'),
            const SizedBox(height: 8),
            AppTextField(
              controller: _userKeyCtrl,
              maxLength: 20,
              hint: '고유 이름 입력',
              prefixIcon: const Icon(LucideIcons.atSign, size: 18),
              suffixIcon: _buildUserKeySuffix(),
            ),

            const SizedBox(height: 4),
            _buildUserKeyStatus(sub),

            const SizedBox(height: 40),
            Divider(
              height: 1,
              color: context.isDark
                  ? AppColors.darkSurface2
                  : AppColors.lightDivider,
            ),
            const SizedBox(height: 8),
            _BottomMenuItem(
              icon: Icons.description_outlined,
              label: '서비스 이용약관',
              onTap: () => context.push(AppRoutes.terms),
            ),
            _BottomMenuItem(
              icon: Icons.privacy_tip_outlined,
              label: '개인정보처리방침',
              onTap: () => context.push(AppRoutes.privacy),
            ),

            // 위험 영역: 약관·개인정보와 충분히 분리
            const SizedBox(height: 56),
            Center(
              child: TextButton(
                onPressed: () => showWithdrawFlow(context, ref),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  '회원 탈퇴',
                  style: TextStyle(
                    fontSize: 12,
                    color: sub,
                    decoration: TextDecoration.underline,
                    decorationColor: sub,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildUserKeySuffix() {
    if (_checkingUserKey) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_userKeyAvailable == true) {
      return const Icon(Icons.check_circle_rounded,
          color: Colors.green, size: 20);
    }
    if (_userKeyAvailable == false) {
      return const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20);
    }
    return const SizedBox.shrink();
  }

  Widget _buildUserKeyStatus(Color sub) {
    if (_userKeyAvailable == true &&
        _userKeyCtrl.text.trim() != widget.profile.userKey) {
      return Text('사용 가능한 고유 이름입니다.',
          style: const TextStyle(fontSize: 11, color: Colors.green));
    }
    if (_userKeyAvailable == false) {
      return Text('이미 사용중인 고유 이름입니다.',
          style: const TextStyle(fontSize: 11, color: AppColors.error));
    }
    return Text('@고유이름은 프로필에 표시되는 고유 식별자입니다.',
        style: TextStyle(fontSize: 11, color: sub));
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    );
  }
}

class _BottomMenuItem extends StatelessWidget {
  const _BottomMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.isDark ? Colors.white70 : Colors.black87;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight,
                size: 16,
                color: context.isDark ? Colors.white38 : Colors.black38),
          ],
        ),
      ),
    );
  }
}
