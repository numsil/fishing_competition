import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../core/utils/youtube_url_parser.dart';

/// 피드 카드 안에서 유튜브 영상을 보여주는 위젯.
/// - 처음에는 썸네일 + 재생 버튼만 (가벼움)
/// - 탭하면 YoutubePlayer 로 교체 + autoplay
/// - 자동재생은 사용자가 의도적으로 누른 것만 (스크롤 자동재생 X)
class YoutubeFeedPlayer extends StatefulWidget {
  const YoutubeFeedPlayer({super.key, required this.youtubeUrl, required this.thumbnailUrl});
  final String youtubeUrl;
  final String thumbnailUrl;

  @override
  State<YoutubeFeedPlayer> createState() => _YoutubeFeedPlayerState();
}

class _YoutubeFeedPlayerState extends State<YoutubeFeedPlayer> {
  YoutubePlayerController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _start() {
    final id = extractYoutubeId(widget.youtubeUrl);
    if (id == null) return;
    setState(() {
      _controller = YoutubePlayerController(
        initialVideoId: id,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (ctrl != null) {
      // YoutubePlayerBuilder 로 감싸야 전체화면 버튼이 실제로 풀스크린으로 전환됨.
      // (안 감싸면 단순히 화면 회전만 되고 전체화면 안 됨)
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: ctrl,
          showVideoProgressIndicator: true,
          aspectRatio: isYoutubeShortsUrl(widget.youtubeUrl) ? 9 / 16 : 16 / 9,
          // 기본 컨트롤 + 10초 점프 버튼 + 풀스크린.
          bottomActions: [
            const SizedBox(width: 12),
            CurrentPosition(),
            const SizedBox(width: 6),
            ProgressBar(
              isExpanded: true,
              colors: const ProgressBarColors(
                playedColor: Color(0xFFFF0000),
                handleColor: Color(0xFFFF0000),
              ),
            ),
            RemainingDuration(),
            IconButton(
              icon: const Icon(Icons.replay_10, color: Colors.white),
              onPressed: () {
                final pos = ctrl.value.position;
                final target = pos - const Duration(seconds: 10);
                ctrl.seekTo(target.isNegative ? Duration.zero : target);
              },
            ),
            IconButton(
              icon: const Icon(Icons.forward_10, color: Colors.white),
              onPressed: () {
                final pos = ctrl.value.position;
                ctrl.seekTo(pos + const Duration(seconds: 10));
              },
            ),
            const FullScreenButton(),
          ],
        ),
        builder: (context, player) => player,
      );
    }

    return GestureDetector(
      onTap: _start,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: widget.thumbnailUrl,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(color: Colors.black),
          ),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.play, color: Colors.white, size: 28),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'YouTube',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
