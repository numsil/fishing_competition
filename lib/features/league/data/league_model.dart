// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'league_model.freezed.dart';
part 'league_model.g.dart';

@freezed
abstract class League with _$League {
  /// freezed 는 클래스에 getter 를 두려면 private 생성자를 요구한다.
  const League._();

  const factory League({
    required String id,
    @JsonKey(name: 'host_id') required String hostId,
    required String title,
    String? description,
    @JsonKey(name: 'short_description') String? shortDescription,
    required String location,
    double? lat,
    double? lng,
    @JsonKey(name: 'start_time') required DateTime startTime,
    @JsonKey(name: 'end_time') required DateTime endTime,
    @JsonKey(name: 'entry_fee') @Default(0) int entryFee,
    @JsonKey(name: 'max_participants') @Default(100) int maxParticipants,
    @Default('recruiting') String status,
    @JsonKey(name: 'fish_types') @Default('배스') String fishTypes,
    @Default('최대어') String rule,
    @JsonKey(name: 'catch_limit') @Default(1) int catchLimit,
    @JsonKey(name: 'prize_info') String? prizeInfo,
    @JsonKey(name: 'is_public') @Default(true) bool isPublic,
    @JsonKey(name: 'allow_gallery') @Default(true) bool allowGallery,
    @JsonKey(name: 'is_team_mode') @Default(false) bool isTeamMode,
    @JsonKey(name: 'team_assign_mode') @Default('host') String teamAssignMode,
    @JsonKey(name: 'team_capacity') @Default(0) int teamCapacity,
    @JsonKey(name: 'intro_image_urls') @Default([]) List<String> introImageUrls,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    // 조인된 데이터
    @JsonKey(includeFromJson: false, includeToJson: false) @Default(0) int participantsCount,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String hostUsername,
    @JsonKey(includeFromJson: false, includeToJson: false) String? hostAvatarUrl,
  }) = _League;

  factory League.fromJson(Map<String, dynamic> json) => _$LeagueFromJson(json);

  /// 참가자가 직접 팀을 고를 수 있는 리그인가.
  ///
  /// 팀전을 끄면 team_assign_mode 는 보존되므로(되돌릴 수 있게),
  /// isTeamMode 를 같이 봐야 개인전 리그에 배너가 뜨지 않는다.
  bool get isSelfPick => isTeamMode && teamAssignMode == 'self';
}
