-- ============================================================
-- 보안 패치: 점수 조작 / 부정 제출 방지
-- Supabase Dashboard > SQL Editor 에서 실행
-- ============================================================

-- ── 1. length 범위 제약 (0 < length ≤ 200cm) ────────────────
ALTER TABLE posts
  DROP CONSTRAINT IF EXISTS chk_posts_length;

ALTER TABLE posts
  ADD CONSTRAINT chk_posts_length
  CHECK (length IS NULL OR (length > 0 AND length <= 200));


-- ── 2. score 서버 자동 계산 트리거 ──────────────────────────
-- 클라이언트가 어떤 score 값을 보내도 서버에서 덮어씀
CREATE OR REPLACE FUNCTION calc_post_score()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.score := CASE
    WHEN NEW.length IS NULL OR NEW.length <= 30 THEN 0
    WHEN NEW.length >= 60 THEN ROUND(POW(NEW.length, 2.5) / 800 * 10)
    WHEN NEW.length >= 55 THEN ROUND(POW(NEW.length, 2.5) / 800 * 7)
    WHEN NEW.length >= 50 THEN ROUND(POW(NEW.length, 2.5) / 800 * 5)
    WHEN NEW.length >= 45 THEN ROUND(POW(NEW.length, 2.5) / 800 * 3)
    WHEN NEW.length >= 40 THEN ROUND(POW(NEW.length, 2.5) / 800 * 2)
    ELSE                       ROUND(POW(NEW.length, 2.5) / 800 * 1.5)
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_calc_post_score ON posts;
CREATE TRIGGER trg_calc_post_score
  BEFORE INSERT OR UPDATE OF length ON posts
  FOR EACH ROW EXECUTE FUNCTION calc_post_score();


-- ── 3. posts INSERT 정책 강화 ────────────────────────────────
-- 기존: auth.role() = 'authenticated' 만 체크 (user_id 위조, 비참가 리그 제출 가능)
-- 변경: ① 본인 게시물만, ② 리그 제출 시 승인된 참가자만

DROP POLICY IF EXISTS "Authenticated users can create posts." ON posts;

CREATE POLICY "Authenticated users can create posts." ON posts
  FOR INSERT WITH CHECK (
    auth.uid() = user_id
    AND (
      league_id IS NULL
      OR EXISTS (
        SELECT 1 FROM league_participants
        WHERE league_participants.league_id = posts.league_id
          AND league_participants.user_id   = auth.uid()
          AND league_participants.status    = 'approved'
      )
    )
  );


-- ── 4. rank_bonus 범위 검증 트리거 ───────────────────────────
-- 호스트가 API 직접 호출로 임의의 rank_bonus 값을 설정하는 것을 차단
-- 공식: n * base * multiplier (rank 1 최대값 이하여야 함)
CREATE OR REPLACE FUNCTION validate_rank_bonus_update()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_n    INT;
  v_base INT;
  v_max  INT;
BEGIN
  -- 값이 바뀌지 않거나 0으로 리셋할 때는 통과
  IF NEW.rank_bonus = OLD.rank_bonus OR NEW.rank_bonus = 0 THEN
    RETURN NEW;
  END IF;

  -- 리그 승인 참가자 수 조회
  SELECT COUNT(*) INTO v_n
  FROM league_participants
  WHERE league_id = NEW.league_id
    AND status = 'approved';

  v_base := CASE
    WHEN v_n <= 6  THEN 10
    WHEN v_n <= 12 THEN 24
    WHEN v_n <= 19 THEN 40
    ELSE 60
  END;

  -- 최대 허용값 = n * base * 1.0 (rank 1, multiplier 100%)
  v_max := CEIL(v_n::NUMERIC * v_base * 1.0);

  IF NEW.rank_bonus > v_max THEN
    RAISE EXCEPTION
      'rank_bonus % exceeds allowed maximum % (participants=%, base=%)',
      NEW.rank_bonus, v_max, v_n, v_base;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_rank_bonus ON league_participants;
CREATE TRIGGER trg_validate_rank_bonus
  BEFORE UPDATE OF rank_bonus ON league_participants
  FOR EACH ROW EXECUTE FUNCTION validate_rank_bonus_update();


-- ── 5. posts UPDATE 정책 추가 ────────────────────────────────
-- 기존에 posts UPDATE 정책이 없어서 본인도 수정 불가능했음.
-- caption, lure_type 등 일반 필드 수정은 허용하되
-- score 는 트리거가 관리하므로 클라이언트에서 건드려도 무해함.
DROP POLICY IF EXISTS "Users can update own posts." ON posts;
CREATE POLICY "Users can update own posts." ON posts
  FOR UPDATE USING (auth.uid() = user_id);
