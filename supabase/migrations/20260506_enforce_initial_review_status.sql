-- ============================================================
-- posts.review_status 초기값을 서버에서 강제 (클라이언트 신뢰 제거)
--
-- Before: 클라이언트가 review_status를 임의로 보낼 수 있어,
--         악의적인 클라이언트는 개인기록도 'approved'로 INSERT 가능
-- After:  BEFORE INSERT 트리거로 비즈니스 룰에 따라 강제 설정
--           - is_personal_record = true → 'pending' (인증 필수)
--           - 그 외 (피드, 리그)        → 'approved' (자동 승인)
-- ============================================================

CREATE OR REPLACE FUNCTION enforce_initial_review_status()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_personal_record = true THEN
    NEW.review_status := 'pending';
  ELSE
    NEW.review_status := 'approved';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS posts_enforce_initial_review_status ON posts;

CREATE TRIGGER posts_enforce_initial_review_status
BEFORE INSERT ON posts
FOR EACH ROW
EXECUTE FUNCTION enforce_initial_review_status();
