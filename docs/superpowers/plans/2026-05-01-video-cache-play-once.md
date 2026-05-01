# Video Cache + Play-Once Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Supabase egress 최소화를 위해 영상을 기기에 캐시하고, Instagram 스타일 play-once + replay 버튼을 적용한다.

**Architecture:** `DefaultCacheManager().getSingleFile()`로 영상을 로컬 캐시에 저장한 뒤 `VideoPlayerController.file()`로 재생. `setLooping(false)` + `_hasEnded` 상태로 영상 종료를 감지해 replay 버튼을 표시한다.

**Tech Stack:** Flutter, video_player ^2.9.2, flutter_cache_manager (이미 transitive dependency로 존재)

---

## File Map

| 파일 | 변경 유형 | 내용 |
|------|-----------|------|
| `lib/features/feed/presentation/widgets/feed_video_player.dart` | Modify | 캐싱, play-once, replay 버튼 전체 적용 |

---

## Task 1: import 추가 및 상태 필드 선언

**Files:**
- Modify: `lib/features/feed/presentation/widgets/feed_video_player.dart`

- [ ] **Step 1: 파일 상단에 flutter_cache_manager import 추가**

`feed_video_player.dart` 상단 import 블록에 아래 줄을 추가한다:

```dart
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
```

- [ ] **Step 2: `_FeedVideoPlayerState`에 상태 필드 2개 추가**

기존 필드들 아래에 추가한다:

```dart
bool _hasEnded = false;
bool _isLoading = false;
```

최종 상태 필드 블록:

```dart
VideoPlayerController? _controller;
bool _initialized = false;
bool _wasPlayingBeforeHide = false;
bool _isSeeking = false;
bool _hasEnded = false;
bool _isLoading = false;
```

- [ ] **Step 3: 커밋**

```bash
git add lib/features/feed/presentation/widgets/feed_video_player.dart
git commit -m "feat: video cache + play-once 상태 필드 및 import 추가"
```

---

## Task 2: 컨트롤러 리스너를 별도 메서드로 분리 및 종료 감지 추가

**Files:**
- Modify: `lib/features/feed/presentation/widgets/feed_video_player.dart:55`

- [ ] **Step 1: `_onControllerUpdate` 메서드 추가**

`_toggleMute()` 메서드 위에 아래 메서드를 추가한다:

```dart
void _onControllerUpdate() {
  if (!mounted || _controller == null) return;
  final value = _controller!.value;
  if (!_hasEnded &&
      !value.isPlaying &&
      value.duration > Duration.zero &&
      value.position >= value.duration) {
    setState(() => _hasEnded = true);
  } else {
    setState(() {});
  }
}
```

- [ ] **Step 2: 커밋**

```bash
git add lib/features/feed/presentation/widgets/feed_video_player.dart
git commit -m "feat: 영상 종료 감지 리스너 메서드 추가"
```

---

## Task 3: `_togglePlay` 캐시 기반으로 교체

**Files:**
- Modify: `lib/features/feed/presentation/widgets/feed_video_player.dart:47`

- [ ] **Step 1: `_togglePlay` 메서드 전체를 아래로 교체**

기존 `_togglePlay` 메서드를 찾아 전체를 다음으로 교체한다:

```dart
Future<void> _togglePlay() async {
  if (_isLoading) return;

  if (_controller == null) {
    setState(() => _isLoading = true);
    try {
      final isMuted = ref.read(videoMutedProvider);
      final file = await DefaultCacheManager().getSingleFile(widget.post.videoUrl!);
      final ctrl = VideoPlayerController.file(file);
      await ctrl.initialize();
      ctrl.setLooping(false);
      ctrl.setVolume(isMuted ? 0.0 : 1.0);
      await ctrl.play();
      ctrl.addListener(_onControllerUpdate);
      setState(() {
        _controller = ctrl;
        _initialized = true;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
    return;
  }

  if (_controller!.value.isPlaying) {
    _wasPlayingBeforeHide = false;
    await _controller!.pause();
  } else {
    await _controller!.play();
  }
  setState(() {});
}
```

- [ ] **Step 2: `_replay` 메서드 추가**

`_togglePlay` 바로 아래에 추가한다:

```dart
Future<void> _replay() async {
  if (_controller == null) return;
  setState(() => _hasEnded = false);
  await _controller!.seekTo(Duration.zero);
  await _controller!.play();
}
```

- [ ] **Step 3: 커밋**

```bash
git add lib/features/feed/presentation/widgets/feed_video_player.dart
git commit -m "feat: 영상 캐시 로드 및 replay 메서드 추가"
```

---

## Task 4: `_onVisibilityChanged` — 영상 끝난 상태에서 자동 재생 방지

**Files:**
- Modify: `lib/features/feed/presentation/widgets/feed_video_player.dart:29`

- [ ] **Step 1: `_onVisibilityChanged` 메서드의 resume 조건에 `_hasEnded` 체크 추가**

기존 코드:
```dart
if (_wasPlayingBeforeHide && !_controller!.value.isPlaying) {
  _wasPlayingBeforeHide = false;
  _controller!.setVolume(ref.read(videoMutedProvider) ? 0.0 : 1.0);
  _controller!.play();
  if (mounted) setState(() {});
}
```

변경 후:
```dart
if (_wasPlayingBeforeHide && !_hasEnded && !_controller!.value.isPlaying) {
  _wasPlayingBeforeHide = false;
  _controller!.setVolume(ref.read(videoMutedProvider) ? 0.0 : 1.0);
  _controller!.play();
  if (mounted) setState(() {});
}
```

- [ ] **Step 2: 커밋**

```bash
git add lib/features/feed/presentation/widgets/feed_video_player.dart
git commit -m "feat: 영상 종료 후 스크롤 복귀 시 자동 재생 방지"
```

---

## Task 5: UI — 로딩 스피너, play 버튼 조건 수정, replay 버튼 추가

**Files:**
- Modify: `lib/features/feed/presentation/widgets/feed_video_player.dart` (build 메서드)

- [ ] **Step 1: 전체 탭 영역 GestureDetector — 영상 끝난 상태에서 탭 비활성화**

기존:
```dart
GestureDetector(
  onTap: _togglePlay,
  child: Container(color: Colors.transparent),
),
```

변경 후:
```dart
GestureDetector(
  onTap: _hasEnded ? null : _togglePlay,
  child: Container(color: Colors.transparent),
),
```

- [ ] **Step 2: play 버튼 조건 수정 — 영상 끝났을 때 숨김**

기존:
```dart
if (!isPlaying)
  Center(
    child: GestureDetector(
      onTap: _togglePlay,
      ...Icons.play_arrow_rounded...
    ),
  ),
```

변경 후:
```dart
if (!isPlaying && !_hasEnded)
  Center(
    child: GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
      ),
    ),
  ),
```

- [ ] **Step 3: replay 버튼 추가 — play 버튼 바로 아래에 삽입**

```dart
if (_hasEnded)
  Center(
    child: GestureDetector(
      onTap: _replay,
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.replay_rounded, color: Colors.white, size: 38),
      ),
    ),
  ),
```

- [ ] **Step 4: 로딩 스피너 추가 — replay 버튼 아래에 삽입**

```dart
if (_isLoading)
  const Center(
    child: CircularProgressIndicator(
      color: Colors.white,
      strokeWidth: 2,
    ),
  ),
```

- [ ] **Step 5: 커밋**

```bash
git add lib/features/feed/presentation/widgets/feed_video_player.dart
git commit -m "feat: replay 버튼 및 로딩 스피너 UI 추가"
```

---

## Task 6: 수동 검증

- [ ] **Step 1: 앱 빌드**

```bash
flutter run
```

- [ ] **Step 2: 시나리오별 확인**

| 시나리오 | 기대 결과 |
|----------|-----------|
| 영상 탭 → 재생 | 첫 재생: 짧은 로딩 후 재생 시작 |
| 동일 영상 재탭 | 즉시 재생 (캐시에서 로드) |
| 영상 끝까지 재생 | 마지막 프레임 freeze + 중앙 replay 버튼 표시 |
| replay 버튼 탭 | 처음부터 재생, replay 버튼 사라짐 |
| 재생 중 스크롤 아웃 → 복귀 | 이어서 재생 |
| 영상 끝난 후 스크롤 아웃 → 복귀 | replay 버튼 유지, 자동 재생 없음 |
| 음소거 토글 | 기존과 동일하게 동작 |
| 시크바 조작 | 기존과 동일하게 동작 |

- [ ] **Step 3: 최종 커밋**

```bash
git add .
git commit -m "feat: 영상 캐시 + play-once + replay 버튼 완성"
```
