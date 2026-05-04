import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/verification_model.dart';
import '../../data/verification_repository.dart';

class VerificationDetailScreen extends ConsumerStatefulWidget {
  const VerificationDetailScreen({super.key, required this.request});
  final VerificationRequest request;

  @override
  ConsumerState<VerificationDetailScreen> createState() =>
      _VerificationDetailScreenState();
}

class _VerificationDetailScreenState
    extends ConsumerState<VerificationDetailScreen> {
  bool _loading = false;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _vote(String vote) async {
    setState(() => _loading = true);
    try {
      final uid = _userId;
      if (uid == null) {
        AppSnackBar.error(context, '로그인이 필요합니다');
        return;
      }
      await ref
          .read(verificationRepositoryProvider)
          .submitVote(widget.request.id, uid, vote);
      ref.invalidate(myPendingVerificationsProvider);
      ref.invalidate(myVerificationHistoryProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '처리 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final isDark = context.isDark;
    final accent = context.accentColor;
    final sub = isDark ? const Color(0xFF888888) : const Color(0xFF999999);
    final alreadyVoted = req.myVote != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '인증 심사',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: CachedNetworkImage(
                imageUrl: req.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: isDark
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFF5F5F5),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: isDark
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFF5F5F5),
                  child: Icon(LucideIcons.imageOff, color: sub),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: req.submitterAvatar.isNotEmpty
                            ? CachedNetworkImageProvider(req.submitterAvatar)
                            : null,
                        child: req.submitterAvatar.isEmpty
                            ? Text(
                                req.submitterName.isNotEmpty
                                    ? req.submitterName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 14),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        req.submitterName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _InfoRow(
                    icon: LucideIcons.fish,
                    label: '어종',
                    value: req.fishType,
                    accent: accent,
                  ),
                  if (req.length != null)
                    _InfoRow(
                      icon: LucideIcons.ruler,
                      label: '길이',
                      value: '${req.length!.toStringAsFixed(1)} cm',
                      accent: accent,
                    ),
                  if (req.weight != null)
                    _InfoRow(
                      icon: LucideIcons.scale,
                      label: '무게',
                      value: '${req.weight!.toStringAsFixed(2)} kg',
                      accent: accent,
                    ),
                  if (req.location != null && req.location!.isNotEmpty)
                    _InfoRow(
                      icon: LucideIcons.mapPin,
                      label: '위치',
                      value: req.location!,
                      accent: accent,
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(LucideIcons.users, size: 14, color: sub),
                      const SizedBox(width: 6),
                      Text(
                        '${req.approveCount + req.rejectCount}명 응답 · 승인 ${req.approveCount} / 거부 ${req.rejectCount}',
                        style: TextStyle(fontSize: 12, color: sub),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  if (alreadyVoted)
                    Center(
                      child: Text(
                        req.myVote == 'approve' ? '✅ 승인 완료' : '❌ 거부 완료',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: req.myVote == 'approve'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : () => _vote('reject'),
                            icon: const Icon(LucideIcons.x, size: 18),
                            label: const Text('거부'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _loading ? null : () => _vote('approve'),
                            icon: const Icon(LucideIcons.check, size: 18),
                            label: const Text('승인'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
