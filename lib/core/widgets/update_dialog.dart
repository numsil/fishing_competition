import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_update_service.dart';
import '../theme/app_colors.dart';
import '../extensions/theme_extensions.dart';

Future<void> showUpdateDialog(
  BuildContext context,
  AppVersionInfo info,
  AppUpdateService service,
) {
  return showDialog(
    context: context,
    barrierDismissible: !info.forceUpdate,
    builder: (_) => _UpdateDialog(info: info, service: service),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info, required this.service});
  final AppVersionInfo info;
  final AppUpdateService service;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  bool _downloading = false;
  String? _error;

  Future<void> _startUpdate() async {
    if (Platform.isAndroid) {
      final url = widget.info.apkUrl;
      if (url == null) {
        setState(() => _error = 'APK 다운로드 URL이 없습니다.');
        return;
      }
      setState(() {
        _downloading = true;
        _error = null;
        _progress = 0;
      });
      try {
        await widget.service.downloadAndInstall(
          url,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
        // 설치 시작 후 기존 앱 종료 → 설치 완료 후 새 버전으로 재시작됨
        SystemNavigator.pop();
      } catch (_) {
        if (mounted) {
          setState(() {
            _downloading = false;
            _error = '다운로드 실패. 네트워크를 확인 후 다시 시도해 주세요.';
          });
        }
      }
    } else {
      final url = widget.info.iosUrl;
      if (url == null) {
        setState(() => _error = 'iOS 업데이트 URL이 없습니다. 관리자에게 문의해 주세요.');
        return;
      }
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final sub = isDark ? AppColors.darkTextSub : AppColors.lightTextSub;
    final divider = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    const accent = AppColors.neonGreen;

    return PopScope(
      canPop: !widget.info.forceUpdate && !_downloading,
      child: Dialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: accent,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '새 버전 출시 🎉',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'v${widget.info.version}',
                style: TextStyle(
                  fontSize: 13,
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              // 임시 디버그: 빌드 번호 확인용
              Text(
                '현재 build: ${widget.info.currentBuildNumber} → 신규 build: ${widget.info.buildNumber}',
                style: TextStyle(fontSize: 11, color: sub),
              ),
              if (widget.info.releaseNotes != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface2
                        : AppColors.lightBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.info.releaseNotes!,
                    style: TextStyle(
                      fontSize: 13,
                      color: sub,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              if (_downloading) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: divider,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(accent),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _progress != null
                      ? '다운로드 중... ${(_progress! * 100).toStringAsFixed(0)}%'
                      : '준비 중...',
                  style: TextStyle(fontSize: 12, color: sub),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              Divider(color: divider, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!widget.info.forceUpdate && !_downloading) ...[
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: sub,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: divider),
                          ),
                        ),
                        child: const Text(
                          '나중에',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (!_downloading)
                    Expanded(
                      child: TextButton(
                        onPressed: _startUpdate,
                        style: TextButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '업데이트',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
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
