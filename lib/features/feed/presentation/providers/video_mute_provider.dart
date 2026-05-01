import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'video_mute_provider.g.dart';

@riverpod
class VideoMuted extends _$VideoMuted {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setMuted(bool value) => state = value;
}
