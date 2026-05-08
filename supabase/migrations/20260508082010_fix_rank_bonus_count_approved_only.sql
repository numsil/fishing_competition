-- 보너스 계산 시 v_count를 전체 participants가 아닌
-- status='approved'인 실제 참가자만 카운트하도록 수정.
-- 거절(rejected)·대기(pending) 상태가 보너스 규모에 영향주던 버그 수정.

CREATE OR REPLACE FUNCTION public.save_league_rank_bonuses(p_league_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
  DECLARE
    v_count int;
    v_base  int;
    v_now   timestamptz := NOW();
  BEGIN
    SELECT COUNT(*)::int INTO v_count
    FROM league_participants
    WHERE league_id = p_league_id
      AND status = 'approved';

    IF v_count = 0 THEN RETURN; END IF;

    v_base := CASE
      WHEN v_count <= 6  THEN 10
      WHEN v_count <= 12 THEN 24
      WHEN v_count <= 19 THEN 40
      ELSE 60
    END;

    WITH ranks AS (
      SELECT
        r.user_id,
        ROW_NUMBER() OVER (
          ORDER BY r.total_score DESC, r.total_count DESC, r.best_score DESC
        ) AS rk
      FROM get_league_ranking(p_league_id) r
    ),
    bonuses AS (
      SELECT
        r.user_id,
        ROUND(v_count * v_base * CASE
          WHEN r.rk = 1  THEN 1.00
          WHEN r.rk = 2  THEN 0.60
          WHEN r.rk = 3  THEN 0.40
          WHEN r.rk <= 5  THEN 0.20
          WHEN r.rk <= 10 THEN 0.10
          ELSE 0.05
        END)::int AS bonus
      FROM ranks r
    )
    UPDATE league_participants lp
    SET rank_bonus          = b.bonus,
        rank_bonus_earned_at = v_now
    FROM bonuses b
    WHERE lp.league_id = p_league_id
      AND lp.user_id   = b.user_id
      AND b.bonus > 0;
  END;
$$;
