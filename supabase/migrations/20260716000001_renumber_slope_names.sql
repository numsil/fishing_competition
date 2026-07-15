-- 슬로프 이름 순번 정리 (현재 DB 값 기준).
-- 앞선 20260716000000 이 고정 번호를 하드코딩했는데 prod에 없는 ID(UPDATE 0)들 때문에
-- 같은 지역 순번에 구멍이 생김. 지금 실제 존재하는 row 기준으로 정리한다.
-- 원칙: 같은 지역 여러 개 → -1,-2,-3 순서대로 / 하나뿐이면 번호 제거.
-- 적서리는 사용자 선택 A: 'S059 적서리 대호대교'는 별개 유지, 나머지 둘을 -1,-2 로.
-- 이름(name)만 수정, 주소(address)는 그대로.

BEGIN;

-- 순번 구멍 메우기
UPDATE public.slopes SET name = '당진 고대면 당진포리-3' WHERE id = 's050'; -- was -4
UPDATE public.slopes SET name = '당진 대호지면 적서리-1'   WHERE id = 's061'; -- was -3
UPDATE public.slopes SET name = '당진 대호지면 적서리-2'   WHERE id = 's063'; -- was -5

-- 외톨이 번호 제거 (지역에 하나뿐)
UPDATE public.slopes SET name = '나주 다도면 궁원리'   WHERE id = 's087'; -- was -1
UPDATE public.slopes SET name = '당진 대호지면 대촌길' WHERE id = 's054'; -- was -1
UPDATE public.slopes SET name = '당진 대호지면 사성리' WHERE id = 's057'; -- was -1
UPDATE public.slopes SET name = '예천 풍양면 효갈리'   WHERE id = 's010'; -- was -2
UPDATE public.slopes SET name = '평택 포승읍 홍원리'   WHERE id = 's096'; -- was -1

COMMIT;
