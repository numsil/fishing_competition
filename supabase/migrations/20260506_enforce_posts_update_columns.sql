-- ============================================================
-- posts UPDATE 권한 컬럼 단위 강제
--
-- 문제: 기존 RLS 정책의 WITH CHECK가 너무 관대
--   - "league host can update review_status" → WITH CHECK (true)
--     → 호스트가 다른 참가자의 length, score 등을 임의로 변경 가능 (점수 조작)
--   - 본인은 review_status도 수정 가능 → 인증 시스템 우회 가능
--
-- 해결: BEFORE UPDATE 트리거로 비즈니스 룰 강제
--   - 본인(owner): review_status는 변경 불가, 그 외 컬럼은 자유
--   - 호스트/admin/verifier: review_status만 변경 가능
-- ============================================================

CREATE OR REPLACE FUNCTION enforce_posts_update_columns()
RETURNS TRIGGER AS $$
DECLARE
  is_owner BOOLEAN := (auth.uid() = OLD.user_id);
BEGIN
  -- 본인 게시물 수정: review_status 변경 차단 (인증 시스템 우회 방지)
  IF is_owner THEN
    IF NEW.review_status IS DISTINCT FROM OLD.review_status THEN
      RAISE EXCEPTION 'Post owner cannot change review_status (USE_VERIFICATION_FLOW)';
    END IF;
    RETURN NEW;
  END IF;

  -- 비-소유자 (호스트, admin, verifier 등): review_status만 변경 허용
  IF NEW.user_id            IS DISTINCT FROM OLD.user_id            THEN RAISE EXCEPTION 'Cannot change user_id'; END IF;
  IF NEW.league_id          IS DISTINCT FROM OLD.league_id          THEN RAISE EXCEPTION 'Cannot change league_id'; END IF;
  IF NEW.image_url          IS DISTINCT FROM OLD.image_url          THEN RAISE EXCEPTION 'Only post owner can change image_url'; END IF;
  IF NEW.image_urls         IS DISTINCT FROM OLD.image_urls         THEN RAISE EXCEPTION 'Only post owner can change image_urls'; END IF;
  IF NEW.video_url          IS DISTINCT FROM OLD.video_url          THEN RAISE EXCEPTION 'Only post owner can change video_url'; END IF;
  IF NEW.caption            IS DISTINCT FROM OLD.caption            THEN RAISE EXCEPTION 'Only post owner can change caption'; END IF;
  IF NEW.location           IS DISTINCT FROM OLD.location           THEN RAISE EXCEPTION 'Only post owner can change location'; END IF;
  IF NEW.lat                IS DISTINCT FROM OLD.lat                THEN RAISE EXCEPTION 'Only post owner can change lat'; END IF;
  IF NEW.lng                IS DISTINCT FROM OLD.lng                THEN RAISE EXCEPTION 'Only post owner can change lng'; END IF;
  IF NEW.fish_type          IS DISTINCT FROM OLD.fish_type          THEN RAISE EXCEPTION 'Only post owner can change fish_type'; END IF;
  IF NEW.lure_type          IS DISTINCT FROM OLD.lure_type          THEN RAISE EXCEPTION 'Only post owner can change lure_type'; END IF;
  IF NEW.length             IS DISTINCT FROM OLD.length             THEN RAISE EXCEPTION 'Only post owner can change length'; END IF;
  IF NEW.weight             IS DISTINCT FROM OLD.weight             THEN RAISE EXCEPTION 'Only post owner can change weight'; END IF;
  IF NEW.catch_count        IS DISTINCT FROM OLD.catch_count        THEN RAISE EXCEPTION 'Only post owner can change catch_count'; END IF;
  IF NEW.is_lunker          IS DISTINCT FROM OLD.is_lunker          THEN RAISE EXCEPTION 'Only post owner can change is_lunker'; END IF;
  IF NEW.is_personal_record IS DISTINCT FROM OLD.is_personal_record THEN RAISE EXCEPTION 'Cannot change is_personal_record'; END IF;
  IF NEW.score              IS DISTINCT FROM OLD.score              THEN RAISE EXCEPTION 'Only post owner can change score'; END IF;
  IF NEW.aspect_ratio       IS DISTINCT FROM OLD.aspect_ratio       THEN RAISE EXCEPTION 'Only post owner can change aspect_ratio'; END IF;

  -- review_status는 RLS 정책으로 권한 검증 (admin/host/verifier만 통과)
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS posts_enforce_update_columns ON posts;

CREATE TRIGGER posts_enforce_update_columns
BEFORE UPDATE ON posts
FOR EACH ROW
EXECUTE FUNCTION enforce_posts_update_columns();
