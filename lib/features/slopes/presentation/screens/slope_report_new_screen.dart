import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/slope_report_repository.dart';

/// 새 슬로프 제보 — 목록에 없는 슬로프 위치를 알려주는 폼.
class SlopeReportNewScreen extends ConsumerStatefulWidget {
  const SlopeReportNewScreen({super.key});

  @override
  ConsumerState<SlopeReportNewScreen> createState() =>
      _SlopeReportNewScreenState();
}

class _SlopeReportNewScreenState extends ConsumerState<SlopeReportNewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(slopeReportRepositoryProvider).submitNewSlope(
            name: _nameController.text,
            address: _addressController.text,
            content: _contentController.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      AppSnackBar.success(context, '제보가 접수되었습니다. 감사합니다!');
    } on NotAuthenticatedException {
      if (!mounted) return;
      AppSnackBar.error(context, '로그인이 필요합니다');
      setState(() => _submitting = false);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, '제보 접수 실패: $e');
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('새 슬로프 제보',
            style: AppTextStyles.heading3.copyWith(color: textColor)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                '목록에 없는 슬로프를 알려주세요. 확인 후 등록됩니다.',
                style: AppTextStyles.caption.copyWith(color: subColor),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _nameController,
                label: '슬로프 이름/위치',
                hint: '예: 당진 대호지면 적서리 슬로프',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '이름/위치를 입력해주세요' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _addressController,
                label: '주소 또는 위치 설명',
                hint: '예: 충청남도 당진시 대호지면 적서리 1680',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '주소나 위치 설명을 입력해주세요' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _contentController,
                label: '상세 내용 (선택)',
                hint: '진입로, 주차, 수계, 특이사항 등',
                maxLines: 4,
                minLines: 3,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: '제보하기',
                loading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
