import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/verification_model.dart';
import '../../data/verification_repository.dart';
import 'verification_detail_screen.dart';

class VerificationTab extends ConsumerWidget {
  const VerificationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDark;
    final accent = context.accentColor;
    final sub = isDark ? const Color(0xFF888888) : const Color(0xFF999999);

    final pendingAsync = ref.watch(myPendingVerificationsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myPendingVerificationsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(children: [
            const Text('심사 대기',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(width: 8),
            pendingAsync.when(
              data: (list) => list.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${list.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800),
                      ),
                    )
                  : const SizedBox(),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ]),
          const SizedBox(height: 12),
          pendingAsync.when(
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                        child: Text('대기 중인 심사가 없습니다',
                            style: TextStyle(color: sub, fontSize: 13))),
                  )
                : Column(
                    children: list
                        .map((req) => _VerifCard(
                              request: req,
                              isDark: isDark,
                              accent: accent,
                              sub: sub,
                              onTap: () => _openDetail(context, req, ref),
                            ))
                        .toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('오류: $e', style: TextStyle(color: sub))),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(
      BuildContext context, VerificationRequest req, WidgetRef ref) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VerificationDetailScreen(request: req)),
    );
    if (result == true) {
      ref.invalidate(myPendingVerificationsProvider);
    }
  }
}

class _VerifCard extends StatelessWidget {
  const _VerifCard({
    required this.request,
    required this.isDark,
    required this.accent,
    required this.sub,
    required this.onTap,
  });
  final VerificationRequest request;
  final bool isDark;
  final Color accent, sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final req = request;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          padding: const EdgeInsets.all(12),
          radius: 14,
          borderColor: accent.withValues(alpha: 0.4),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: req.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: req.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xFFF0F0F0)),
                      )
                    : Container(
                        color: isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF0F0F0),
                        child: Icon(LucideIcons.image, color: sub, size: 20),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(req.submitterName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '${req.fishType}${req.length != null ? ' · ${req.length!.toStringAsFixed(1)}cm' : ''}',
                    style: TextStyle(fontSize: 12, color: sub),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('심사하기',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent)),
            ),
          ]),
        ),
      ),
    );
  }
}
