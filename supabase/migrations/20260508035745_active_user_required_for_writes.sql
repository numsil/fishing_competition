-- 정지(banned) 또는 soft-deleted 유저의 쓰기 동작을 RLS 레벨에서 차단.
-- 기존 PERMISSIVE 정책에 RESTRICTIVE 정책을 AND로 결합.
-- 클라이언트 우회 불가 — 어드민이 status='banned'로 바꾸면 즉시 모든 쓰기 차단됨.

-- ── 헬퍼 함수 ─────────────────────────────────────────────
-- SECURITY DEFINER로 users 테이블 RLS 우회 (status 항상 읽을 수 있어야 함)
CREATE OR REPLACE FUNCTION public.is_active_user(uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = uid
      AND status = 'active'
      AND is_deleted = false
  )
$$;

REVOKE EXECUTE ON FUNCTION public.is_active_user(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.is_active_user(uuid) TO authenticated, anon, service_role;

-- ── RESTRICTIVE 정책 ──────────────────────────────────────
-- posts
CREATE POLICY "active_user_required_posts_insert"
  ON public.posts AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (public.is_active_user(auth.uid()));
CREATE POLICY "active_user_required_posts_update"
  ON public.posts AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (public.is_active_user(auth.uid()))
  WITH CHECK (public.is_active_user(auth.uid()));

-- post_comments
CREATE POLICY "active_user_required_comments_insert"
  ON public.post_comments AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (public.is_active_user(auth.uid()));

-- post_likes
CREATE POLICY "active_user_required_likes_insert"
  ON public.post_likes AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (public.is_active_user(auth.uid()));

-- reports
CREATE POLICY "active_user_required_reports_insert"
  ON public.reports AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (public.is_active_user(auth.uid()));

-- tickets
CREATE POLICY "active_user_required_tickets_insert"
  ON public.tickets AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (public.is_active_user(auth.uid()));

-- leagues
CREATE POLICY "active_user_required_leagues_insert"
  ON public.leagues AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (public.is_active_user(auth.uid()));
CREATE POLICY "active_user_required_leagues_update"
  ON public.leagues AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (public.is_active_user(auth.uid()))
  WITH CHECK (public.is_active_user(auth.uid()));

-- league_participants
CREATE POLICY "active_user_required_lp_insert"
  ON public.league_participants AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (public.is_active_user(auth.uid()));

-- conversations
CREATE POLICY "active_user_required_conv_insert"
  ON public.conversations AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (public.is_active_user(auth.uid()));

-- messages
CREATE POLICY "active_user_required_messages_insert"
  ON public.messages AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (public.is_active_user(auth.uid()));

-- catch_verifications
CREATE POLICY "active_user_required_verif_insert"
  ON public.catch_verifications AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (public.is_active_user(auth.uid()));

-- verification_votes
CREATE POLICY "active_user_required_vote_insert"
  ON public.verification_votes AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (public.is_active_user(auth.uid()));
CREATE POLICY "active_user_required_vote_update"
  ON public.verification_votes AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (public.is_active_user(auth.uid()))
  WITH CHECK (public.is_active_user(auth.uid()));
