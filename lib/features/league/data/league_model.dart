// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'league_model.freezed.dart';
part 'league_model.g.dart';

@freezed
abstract class League with _$League {
  const factory League({
    required String id,
    @JsonKey(name: 'host_id') required String hostId,
    required String title,
    String? description,
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
    @JsonKey(name: 'created_at') required DateTime createdAt,
    // 조인된 데이터
    @JsonKey(includeFromJson: false, includeToJson: false) @Default(0) int participantsCount,
  }) = _League;

  factory League.fromJson(Map<String, dynamic> json) => _$LeagueFromJson(json);
}
