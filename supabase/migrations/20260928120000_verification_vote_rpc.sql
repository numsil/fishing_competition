-- 조과 인증 투표 통합 RPC + verif_update RLS 자기참조 버그 수정
--
-- 문제 1) verif_update 정책의 EXISTS 서브쿼리가 v.verification_id = v.id (같은 행의 FK/PK)를
--         비교하고 있어 항상 false → 일반 심사위원이 catch_verifications를 UPDATE 불가.
--         결과: 투표는 기록되고 posts.review_status는 바뀌는데(별도 정책 통과)
--         catch_verifications.status는 pending으로 남아 어드민 목록에 계속 노출됨.
-- 문제 2) 투표→집계→판정→posts 반영이 클라이언트 4회 왕복이라 부분 실패가 조용히 묻히고
--         동시 투표 시 경합이 발생.

-- 1. RLS 수정
DROP POLICY IF EXISTS verif_update ON public.catch_verifications;
CREATE POLICY verif_update ON public.catch_verifications
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.verification_votes v
      WHERE v.verification_id = catch_verifications.id
        AND v.voter_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.verification_votes v
      WHERE v.verification_id = catch_verifications.id
        AND v.voter_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role = 'admin'
    )
  );

-- 2. 투표 통합 RPC (판정 기준 유지: 거절 1표 즉시 거절 / 승인 2표 승인)
CREATE OR REPLACE FUNCTION public.submit_verification_vote(
  p_verification_id uuid,
  p_vote text
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid        uuid := auth.uid();
  v_post_id    uuid;
  v_status     text;
  v_approve    int;
  v_reject     int;
  v_new_status text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;
  IF p_vote NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'INVALID_VOTE';
  END IF;
  IF NOT public.is_active_user(v_uid) THEN
    RAISE EXCEPTION 'USER_NOT_ACTIVE';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users u WHERE u.id = v_uid AND u.is_verifier = true
  ) THEN
    RAISE EXCEPTION 'NOT_VERIFIER';
  END IF;

  -- 동시 투표 직렬화
  SELECT post_id, status INTO v_post_id, v_status
  FROM public.catch_verifications
  WHERE id = p_verification_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'VERIFICATION_NOT_FOUND';
  END IF;

  -- 배정된 voter 행이 있어야만 투표 가능
  UPDATE public.verification_votes
  SET vote = p_vote, voted_at = now()
  WHERE verification_id = p_verification_id AND voter_id = v_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_ASSIGNED_VOTER';
  END IF;

  -- 이미 종결된 건이면 표만 기록하고 종료
  IF v_status <> 'pending' THEN
    RETURN v_status;
  END IF;

  SELECT
    count(*) FILTER (WHERE vote = 'approve'),
    count(*) FILTER (WHERE vote = 'reject')
  INTO v_approve, v_reject
  FROM public.verification_votes
  WHERE verification_id = p_verification_id;

  IF v_reject >= 1 THEN
    v_new_status := 'rejected';
  ELSIF v_approve >= 2 THEN
    v_new_status := 'approved';
  END IF;

  UPDATE public.catch_verifications
  SET approve_count = v_approve,
      reject_count  = v_reject,
      status        = COALESCE(v_new_status, status),
      resolved_at   = CASE WHEN v_new_status IS NOT NULL THEN now() ELSE resolved_at END
  WHERE id = p_verification_id;

  IF v_new_status IS NOT NULL THEN
    UPDATE public.posts
    SET review_status = v_new_status
    WHERE id = v_post_id;
  END IF;

  RETURN COALESCE(v_new_status, 'pending');
END;
$$;

REVOKE ALL ON FUNCTION public.submit_verification_vote(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_verification_vote(uuid, text) TO authenticated;
