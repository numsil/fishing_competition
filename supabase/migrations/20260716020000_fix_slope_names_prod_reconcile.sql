-- 슬로프 이름 교정 (prod 실데이터 기준 재정렬)
-- prod slopes(86행)가 seed 마이그레이션(104행)과 달라, 20260716000000_clean_slope_names
-- 적용 후 번호에 빈칸이 생겼다(예: 적서리-1·-3·-5). 실제 prod 행 기준으로 그룹을
-- 다시 묶어 -1,-2… 연속 부여하고, 단독 항목은 번호 제거. s012 잔존 "슬로프"도 제거.
-- ※ prod 전용 교정 (fresh seed DB에는 clean_slope_names 결과가 이미 올바름).

UPDATE public.slopes SET name = '예천 풍양면 효갈리' WHERE id = 's010';
UPDATE public.slopes SET name = '밸리피싱' WHERE id = 's012';
UPDATE public.slopes SET name = '당진 고대면 당진포리-3' WHERE id = 's050';
UPDATE public.slopes SET name = '당진 대호지면 대촌길' WHERE id = 's054';
UPDATE public.slopes SET name = '당진 대호지면 사성리' WHERE id = 's057';
UPDATE public.slopes SET name = '당진 대호지면 적서리-2' WHERE id = 's061';
UPDATE public.slopes SET name = '당진 대호지면 적서리-3' WHERE id = 's063';
UPDATE public.slopes SET name = '당진 석문면 초락도리' WHERE id = 's066';
UPDATE public.slopes SET name = '나주 다도면 궁원리' WHERE id = 's087';
UPDATE public.slopes SET name = '평택 포승읍 홍원리' WHERE id = 's096';
