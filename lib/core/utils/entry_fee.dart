import 'package:intl/intl.dart';

// 참가비 표기를 만드는 유일한 자리.
//
// 화면마다 따로 포맷하면 같은 리그가 화면에 따라 다르게 보인다.
// 실제로 대회 관리 화면만 `fee ~/ 1000` 으로 찍어서 20,000원이 "20천원"
// 으로, 15,500원이 "15천원" 으로 보였다.

final _won = NumberFormat('#,###');

/// 참가비 표기. 0원은 [freeLabel], 나머지는 `20,000원`.
///
/// [freeLabel] 은 화면마다 다르다 (리그 목록 카드는 `무료 참가`).
/// 그 차이 때문에 포맷까지 각자 들고 가면 표기가 갈라진다.
String formatEntryFee(int fee, {String freeLabel = '무료'}) =>
    fee == 0 ? freeLabel : '${_won.format(fee)}원';
