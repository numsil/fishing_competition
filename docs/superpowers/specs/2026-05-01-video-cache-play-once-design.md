# Video Cache + Play-Once 설계

## 목표

Supabase Cached Egress 최소화 + Instagram 스타일 play-once UX 적용

## 배경

- 현재 `VideoPlayerController.networkUrl()`을 사용해 탭할 때마다 Supabase에서 재스트리밍
- `setLooping(true)`로 무한 반복 재생 중
- `flutter_cache_manager`는 `cached_network_image` 의존성으로 이미 존재
- 영상 압축은 업로드 시 `VideoQuality.MediumQuality`로 이미 적용 중

## 변경 범위

`lib/features/feed/presentation/widgets/feed_video_player.dart` 1개 파일만 수정

## 1. 영상 캐싱

### 현재
```dart
VideoPlayerController.networkUrl(Uri.parse(videoUrl))
```
매 탭마다 Supabase Storage에서 새로 스트리밍 → egress 발생

### 변경
```dart
final file = await DefaultCacheManager().getSingleFile(videoUrl);
VideoPlayerController.file(file)
```

- 첫 재생: Supabase에서 다운로드 + 기기 로컬 캐시 저장
- 이후 재생(재탭, replay): 캐시 파일 로드 → Supabase egress 0
- 캐시 유효기간: `flutter_cache_manager` 기본값 (7일)
- 새 패키지 추가 없음

## 2. Play-Once + Replay 버튼

### 상태 추가
```dart
bool _hasEnded = false;
```

### 동작 정의

| 상황 | 동작 |
|------|------|
| 첫 탭 | 캐시 다운로드 후 재생 |
| 영상 종료 | 마지막 프레임 freeze + 중앙 replay 버튼 표시 |
| replay 버튼 탭 | seekTo(0) + play() + _hasEnded = false |
| 스크롤 아웃 (재생 중) | pause (기존 동작 유지) |
| 스크롤 복귀 (재생 중이었음) | 이어서 재생 (기존 동작 유지) |
| 스크롤 복귀 (영상 끝난 상태) | replay 버튼 유지, 자동 재생 안 함 |

### 루프 제거
`setLooping(true)` → `setLooping(false)`

### Replay UI
- 현재 play 버튼과 동일한 스타일 (검정 반투명 원형 배경)
- 아이콘: `Icons.replay_rounded`
- 위치: 화면 중앙
- `_hasEnded == true`일 때만 표시, play 버튼 대신 렌더링

### 종료 감지
컨트롤러 리스너에서:
```dart
if (!value.isPlaying && value.position >= value.duration && value.duration > Duration.zero) {
  setState(() => _hasEnded = true);
}
```

### _wasPlayingBeforeHide 수정
스크롤 복귀 시 `_hasEnded`가 true면 자동 재생하지 않음:
```dart
if (_wasPlayingBeforeHide && !_hasEnded && !_controller!.value.isPlaying) {
  _controller!.play();
}
```

## 예상 효과

- 동일 영상 두 번째 재생부터 Supabase egress 0
- 루프 제거로 불필요한 재생 횟수 감소
- 캐시 저장으로 오프라인/저속 환경에서도 재생 가능
