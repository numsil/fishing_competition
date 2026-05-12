-- 일별 DAU/WAU/MAU 스냅샷.
-- last_seen_at 단일 컬럼으론 과거 일별 활성 유저 수를 못 구하므로,
-- 매일 한 번씩 그 시점의 (DAU, WAU, MAU) 를 기록해둔다.

CREATE TABLE public.daily_active_snapshots (
  snapshot_date date PRIMARY KEY,
  total_users int NOT NULL,
  dau int NOT NULL,         -- 24h 내 last_seen_at
  wau int NOT NULL,         -- 7일 내
  mau int NOT NULL,         -- 30일 내
  new_signups int NOT NULL, -- 해당일 신규 가입
  posts_today int NOT NULL, -- 해당일 작성 게시물 수
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.daily_active_snapshots ENABLE ROW LEVEL SECURITY;

-- 누구나 SELECT 가능 (집계 데이터, 민감 정보 없음). 어드민이 service_role로 INSERT.
CREATE POLICY "snapshots_select_all"
  ON public.daily_active_snapshots FOR SELECT
  USING (true);

-- 집계 함수: 호출 시점 기준 KPI 1행 INSERT (멱등 — 같은 날 두번 호출하면 갱신).
CREATE OR REPLACE FUNCTION public.record_daily_snapshot()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'UTC')::date;
  v_total int;
  v_dau int;
  v_wau int;
  v_mau int;
  v_new int;
  v_posts int;
BEGIN
  SELECT COUNT(*) INTO v_total
    FROM users WHERE is_deleted = false AND role = 'user';

  SELECT COUNT(*) INTO v_dau
    FROM users
    WHERE is_deleted = false
      AND last_seen_at >= now() - interval '24 hours';

  SELECT COUNT(*) INTO v_wau
    FROM users
    WHERE is_deleted = false
      AND last_seen_at >= now() - interval '7 days';

  SELECT COUNT(*) INTO v_mau
    FROM users
    WHERE is_deleted = false
      AND last_seen_at >= now() - interval '30 days';

  SELECT COUNT(*) INTO v_new
    FROM users
    WHERE is_deleted = false AND role = 'user'
      AND created_at >= v_today
      AND created_at <  v_today + 1;

  SELECT COUNT(*) INTO v_posts
    FROM posts
    WHERE COALESCE(is_deleted, false) = false
      AND created_at >= v_today
      AND created_at <  v_today + 1;

  INSERT INTO public.daily_active_snapshots
    (snapshot_date, total_users, dau, wau, mau, new_signups, posts_today)
    VALUES (v_today, v_total, v_dau, v_wau, v_mau, v_new, v_posts)
    ON CONFLICT (snapshot_date) DO UPDATE
      SET total_users = EXCLUDED.total_users,
          dau = EXCLUDED.dau,
          wau = EXCLUDED.wau,
          mau = EXCLUDED.mau,
          new_signups = EXCLUDED.new_signups,
          posts_today = EXCLUDED.posts_today;
END;
$$;

-- 첫 시드 (오늘 1행 기록)
SELECT public.record_daily_snapshot();

-- pg_cron: 매일 UTC 23:55 (한국 08:55) 에 자동 기록.
-- 자정 직전이라 그날의 모든 데이터를 포함.
SELECT cron.schedule(
  'record_daily_snapshot_job',
  '55 23 * * *',
  $$ SELECT public.record_daily_snapshot(); $$
);
