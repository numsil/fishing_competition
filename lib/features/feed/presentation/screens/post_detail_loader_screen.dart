import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/feed_repository.dart';
import '../../data/post_model.dart';
import 'post_detail_screen.dart';

/// 딥링크용 게시물 진입 화면.
/// `/post/:id` 로 들어왔을 때 Post 객체가 없으므로 ID로 fetch한 뒤
/// PostDetailScreen 으로 위임한다.
class PostDetailLoaderScreen extends ConsumerStatefulWidget {
  const PostDetailLoaderScreen({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<PostDetailLoaderScreen> createState() =>
      _PostDetailLoaderScreenState();
}

class _PostDetailLoaderScreenState
    extends ConsumerState<PostDetailLoaderScreen> {
  late Future<Post?> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(feedRepositoryProvider).fetchPostById(widget.postId);
  }

  void _goHome() {
    if (!mounted) return;
    context.go(AppRoutes.feed);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Post?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.darkBg,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || snap.data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            AppSnackBar.info(context, '존재하지 않거나 삭제된 게시물입니다.');
            _goHome();
          });
          return const Scaffold(
            backgroundColor: AppColors.darkBg,
            body: SizedBox.shrink(),
          );
        }
        return PostDetailScreen(post: snap.data!);
      },
    );
  }
}
