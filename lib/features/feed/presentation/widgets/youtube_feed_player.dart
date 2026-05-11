import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../../core/utils/youtube_url_parser.dart';

/// 피드 카드 안에서 유튜브 영상을 보여주는 위젯.
/// - 처음에는 썸네일 + ▶ (가벼움)
/// - 탭하면 인라인 재생 + 기본 컨트롤 (자동 숨김)
/// - 풀스크린 버튼은 → YouTube 앱(or 브라우저)에서 열기
///   (인라인 fullscreen 은 부모 위젯트리에 막혀 제대로 안 됨)
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
          // 시작하자마자 컨트롤 보이게 → 사용자가 ±10s/풀스크린 발견 가능
          controlsVisibleAtStart: true,
          hideControls: false,
        ),
      );
    });
  }

  Future<void> _openInYoutubeApp() async {
    final id = extractYoutubeId(widget.youtubeUrl);
    if (id == null) return;
    // 일반 YouTube URL을 외부 launch → iOS/Android 모두 YouTube 앱이
    // Universal Link 로 가로채서 열어줌. 앱 없으면 자동으로 브라우저로.
    final uri = Uri.parse('https://www.youtube.com/watch?v=$id');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (ctrl != null) {
      return YoutubePlayer(
        controller: ctrl,
        showVideoProgressIndicator: true,
        aspectRatio: isYoutubeShortsUrl(widget.youtubeUrl) ? 9 / 16 : 16 / 9,
        progressColors: const ProgressBarColors(
          playedColor: Color(0xFFFF0000),
          handleColor: Color(0xFFFF0000),
        ),
        // 영상 끝나면 패키지 기본 동작이 무한 스피너로 멈춰서,
        // 처음으로 되감고 일시정지 → 재생 버튼이 다시 나타나서 다시 누르면 처음부터 재생.
        onEnded: (_) {
          ctrl.seekTo(Duration.zero);
          ctrl.pause();
        },
        bottomActions: [
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.replay_5, color: Colors.white, size: 22),
            onPressed: () {
              final pos = ctrl.value.position;
              final t = pos - const Duration(seconds: 5);
              ctrl.seekTo(t.isNegative ? Duration.zero : t);
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.forward_5, color: Colors.white, size: 22),
            onPressed: () {
              ctrl.seekTo(ctrl.value.position + const Duration(seconds: 5));
            },
          ),
          const SizedBox(width: 4),
          CurrentPosition(),
          const SizedBox(width: 4),
          ProgressBar(
            isExpanded: true,
            colors: const ProgressBarColors(
              playedColor: Color(0xFFFF0000),
              handleColor: Color(0xFFFF0000),
            ),
          ),
          RemainingDuration(),
          // 인라인 풀스크린 대신 YouTube 앱으로 보내기 (휴대폰 전체 화면 = YT 앱이 가장 깔끔)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.open_in_new, color: Colors.white, size: 20),
            tooltip: 'YouTube 앱에서 보기',
            onPressed: _openInYoutubeApp,
          ),
        ],
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
