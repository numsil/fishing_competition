// 순위 규칙에서 "몇 마리 기준" 선택지를 판단하는 순수 함수.
//
// `합산 길이 + 1마리` 는 `최대어` 와 글자 그대로 같은 규칙이다 — 순위 RPC 는
// `마릿수`/`무게` 외에는 전부 "길이, 상위 N마리 합산" 으로 계산하고, 화면도
// catchLimit == 1 이면 양쪽 다 `최대어` 로 표기한다. 같은 결과를 내는 선택지가
// 둘이면 호스트는 둘이 다르다고 믿는다. 그래서 `합산 길이` 에서는 1마리를
// 고를 수 없게 한다.
//
// `무게` 는 남겨둔다. `최대무게` 칩이 없어서 `무게 + 1마리` 가 그 규칙으로 가는
// 유일한 길이다.

/// `합산 길이` 에서 `1마리` 칩을 그릴지.
///
/// [storedLimit] 은 **저장된** 리그의 catchLimit (생성 모드는 `null`).
/// 이미 그 조합으로 저장된 리그는 칩을 그대로 보여준다 — 숨기면 수정 화면을
/// 열고 저장만 눌러도 규칙이 조용히 바뀐다.
bool showSingleCatchChip({required String rule, required int? storedLimit}) =>
    rule != '합산 길이' || storedLimit == 1;

/// 룰 칩을 눌렀을 때 catchLimit 이 가져야 할 값.
int catchLimitAfterRuleChange({required String rule, required int current}) {
  // 마릿수는 제한이 의미 없고, 최대어는 정의상 1마리다.
  if (rule == '마릿수') return 0;
  if (rule == '최대어') return 1;
  // 1 은 최대어와 중복, 0(전체)은 마릿수에서 넘어온 값이다.
  if (rule == '합산 길이') return (current == 0 || current == 1) ? 3 : current;
  return current == 0 ? 1 : current;
}

/// `직접 입력` 으로 받을 수 있는 최소 마릿수.
///
/// 칩만 숨기면 직접 입력에 `1` 을 쳐서 같은 중복 조합으로 들어갈 수 있다.
int minCatchLimit({required String rule}) => rule == '합산 길이' ? 2 : 1;
