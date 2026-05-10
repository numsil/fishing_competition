-- 회원 탈퇴 시 작성한 게시물을 즉시 비공개 처리.
-- 다이얼로그 약속 ("게시물·기록은 즉시 비공개 처리됩니다") 이행.
-- 단, 탈퇴 전 사용자가 직접 삭제한 게시물과 구분해야 복구 시 잘못 부활하지 않음.

ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS hidden_by_withdrawal boolean DEFAULT false NOT NULL;

CREATE INDEX IF NOT EXISTS idx_posts_hidden_by_withdrawal
  ON public.posts(user_id) WHERE hidden_by_withdrawal = true;

-- 자가 탈퇴용 RPC.
-- SECURITY DEFINER 로 RLS 우회 (users 자체 update + posts 일괄 update를 한 트랜잭션으로).
-- 호출자는 자기 자신만 탈퇴 가능 (admin 강제 탈퇴는 service_role 로 직접 처리).
CREATE OR REPLACE FUNCTION public.withdraw_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  UPDATE users
     SET is_deleted = true,
         deleted_at = NOW()
   WHERE id = v_uid
     AND is_deleted = false;

  UPDATE posts
     SET is_deleted = true,
         hidden_by_withdrawal = true
   WHERE user_id = v_uid
     AND is_deleted = false;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.withdraw_user() FROM public;
GRANT EXECUTE ON FUNCTION public.withdraw_user() TO authenticated;
