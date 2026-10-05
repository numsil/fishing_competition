/// 슬로프(카약/보트 진수 지점) 정보
class Slope {
  final String id;
  final String name;
  final String address;
  final String sido; // 시/도 (지역 카테고리)
  final String sigungu; // 시/군/구
  final String waterBody; // 수계 (예: 대호만, 낙동강)
  final double? lat;
  final double? lng;
  final String? thumbUrl; // 위성 썸네일 URL (없으면 내장 에셋 폴백)

  const Slope({
    required this.id,
    required this.name,
    required this.address,
    required this.sido,
    required this.sigungu,
    required this.waterBody,
    this.lat,
    this.lng,
    this.thumbUrl,
  });

  /// 목록/지도 표시용 이름 — 반복되는 '슬로프' 단어 제거 (앞 공백까지 함께).
  /// DB 원본(name)은 그대로 유지. 제거 후 빈 문자열이면 원본 사용.
  String get displayName {
    final stripped = name.replaceAll(RegExp(r'\s*슬로프'), '').trim();
    return stripped.isEmpty ? name : stripped;
  }

  /// 내장 위성 썸네일 경로 (기존 104개용 폴백)
  String get thumbAsset => 'assets/images/slopes/$id.jpg';

  /// 원격 썸네일 사용 가능 여부
  bool get hasRemoteThumb => thumbUrl != null && thumbUrl!.isNotEmpty;

  bool get hasCoordinates => lat != null && lng != null;

  /// Supabase 행(snake_case) → 모델
  factory Slope.fromMap(Map<String, dynamic> m) => Slope(
        id: m['id'] as String,
        name: m['name'] as String,
        address: m['address'] as String,
        sido: m['sido'] as String? ?? '',
        sigungu: m['sigungu'] as String? ?? '',
        waterBody: m['water_body'] as String? ?? '',
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        thumbUrl: m['thumb_url'] as String?,
      );

  /// 모델 → Supabase 행(snake_case) (INSERT/UPDATE용)
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'sido': sido,
        'sigungu': sigungu,
        'water_body': waterBody,
        'lat': lat,
        'lng': lng,
        'thumb_url': thumbUrl,
      };

  Slope copyWith({
    String? id,
    String? name,
    String? address,
    String? sido,
    String? sigungu,
    String? waterBody,
    double? lat,
    double? lng,
    String? thumbUrl,
  }) =>
      Slope(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        sido: sido ?? this.sido,
        sigungu: sigungu ?? this.sigungu,
        waterBody: waterBody ?? this.waterBody,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        thumbUrl: thumbUrl ?? this.thumbUrl,
      );
}
