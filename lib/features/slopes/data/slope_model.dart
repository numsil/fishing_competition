/// 슬로프(카약/보트 진수 지점) 정보
class Slope {
  final String id;
  final String name;
  final String address;
  final String sido; // 시/도 (지역 카테고리)
  final String sigungu; // 시/군/구
  final String waterBody; // 수계 (예: 대호만, 낙동강)

  const Slope({
    required this.id,
    required this.name,
    required this.address,
    required this.sido,
    required this.sigungu,
    required this.waterBody,
  });

  factory Slope.fromJson(Map<String, dynamic> json) => Slope(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        sido: json['sido'] as String,
        sigungu: json['sigungu'] as String,
        waterBody: json['waterBody'] as String? ?? '',
      );
}
