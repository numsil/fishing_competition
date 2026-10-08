import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';

/// 슬로프 화면 접근 가드.
///
/// 피드의 진입 아이콘을 숨겨도 딥링크나 이전 세션의 라우트 복원으로 들어올 수
/// 있으므로 화면 자체에서도 권한을 확인한다. 권한이 없으면 기능의 존재를
/// 드러내지 않도록 "슬로프" 를 언급하지 않고 일반적인 문구만 보여준다.
/// 데이터는 DB 쪽 RLS(has_slope_access)가 별도로 막는다.
class SlopeAccessGuard extends ConsumerWidget {
  const SlopeAccessGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(canUseSlopesProvider);

    return access.when(
      data: (allowed) => allowed ? child : const _NotAvailable(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const _NotAvailable(),
    );
  }
}

class _NotAvailable extends StatelessWidget {
  const _NotAvailable();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            '페이지를 찾을 수 없습니다',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
