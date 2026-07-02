// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'marketplace_model.freezed.dart';
part 'marketplace_model.g.dart';

@freezed
abstract class MarketplaceItem with _$MarketplaceItem {
  const factory MarketplaceItem({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required String title,
    String? description,
    required int price,
    @JsonKey(name: 'image_urls') @Default([]) List<String> imageUrls,
    @Default('기타') String category,
    @Default('selling') String status, // selling, reserved, sold
    @JsonKey(name: 'trade_type') @Default('sell') String tradeType, // sell=팝니다, buy=삽니다
    String? location,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'bumped_at') DateTime? bumpedAt, // 끌어올리기 정렬 기준(없으면 createdAt)
    // joined user data
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String username,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String userKey,
    @JsonKey(includeFromJson: false, includeToJson: false) @Default('') String avatarUrl,
  }) = _MarketplaceItem;

  factory MarketplaceItem.fromJson(Map<String, dynamic> json) =>
      _$MarketplaceItemFromJson(json);
}

extension MarketplaceItemX on MarketplaceItem {
  bool get isBuy => tradeType == 'buy';

  /// 카드 태그 라벨. 팝니다: 판매중/예약중/판매완료, 삽니다: 구매중/예약중/구매완료
  String get statusLabel {
    if (isBuy) {
      switch (status) {
        case 'reserved': return '예약중';
        case 'sold': return '구매완료';
        default: return '구매중';
      }
    }
    switch (status) {
      case 'reserved': return '예약중';
      case 'sold': return '판매완료';
      default: return '판매중';
    }
  }

  bool get isSelling => status == 'selling';

  String get formattedPrice =>
      '${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원';
}
