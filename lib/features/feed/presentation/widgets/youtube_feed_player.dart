import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../../core/utils/youtube_url_parser.dart';

/// 피드 카드 안에서 유튜브 영상을 보여주는 위젯.
/// - 처음에는 썸네일 + 재생 버튼만 (가벼움)
/// - 탭하면 YoutubePlayerScaffold 로 교체 + autoplay
/// - 카드별로 컨트롤러를 따로 들고 있어서 한 번에 하나만 재생되도록 신경쓰진 않음
///   (스크롤 중 자동재생은 안 하므로 사용자가 의도적으로 누른 것만 재생됨)
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
    _controller?.close();
    super.dispose();
  }

  void _start() {
    final id = extractYoutubeId(widget.youtubeUrl);
    if (id == null) return;
    setState(() {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: false,
          strictRelatedVideos: true,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (ctrl != null) {
      return YoutubePlayer(controller: ctrl, aspectRatio: 16 / 9);
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
          // 어둡게 깔고 가운데 재생 버튼
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
          // 좌하단 YouTube 라벨
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
