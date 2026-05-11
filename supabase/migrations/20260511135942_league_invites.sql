-- 리그 초대 기능
-- 비공개 리그(is_public=false)는 호스트가 초대한 사람만 참여 가능.
-- 공개 리그는 기존대로 누구나 즉시 참여.
-- 신청제(pending) 흐름은 더 이상 신규 INSERT 불가 (기존 데이터는 유지).

-- ─────────────────────────────────────────────────────────
-- 1) league_invites 테이블
-- ─────────────────────────────────────────────────────────
CREATE TABLE public.league_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  league_id uuid NOT NULL REFERENCES public.leagues(id) ON DELETE CASCADE,
  inviter_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  invitee_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  CONSTRAINT league_invites_status_check
    CHECK (status IN ('pending', 'accepted', 'declined', 'canceled')),
  CONSTRAINT league_invites_self_check
    CHECK (inviter_id <> invitee_id)
);

-- 살아있는(pending/accepted) 초대만 중복 차단 — 취소/거절 후 재초대 가능
CREATE UNIQUE INDEX league_invites_active_unique
  ON public.league_invites (league_id, invitee_id)
  WHERE status IN ('pending', 'accepted');

CREATE INDEX league_invites_invitee_pending_idx
  ON public.league_invites (invitee_id, created_at DESC)
  WHERE status = 'pending';

CREATE INDEX league_invites_league_idx
  ON public.league_invites (league_id, status);

-- ─────────────────────────────────────────────────────────
-- 2) RLS
-- ─────────────────────────────────────────────────────────
ALTER TABLE public.league_invites ENABLE ROW LEVEL SECURITY;

-- SELECT: 호스트(=inviter) 또는 invitee 본인
CREATE POLICY "league_invites_select"
  ON public.league_invites FOR SELECT
  USING (
    auth.uid() = invitee_id
    OR auth.uid() = inviter_id
  );

-- INSERT / UPDATE / DELETE는 RPC(SECURITY DEFINER)로만 처리.
-- 명시적으로 차단 정책 없음 = 어떤 PERMISSIVE도 없으므로 직접 쓰기 불가.

-- active_user RESTRICTIVE (밴/탈퇴 유저 차단). RPC 우회 대비 RPC 내부에서도 재확인.
CREATE POLICY "active_user_required_invites_insert"
  ON public.league_invites AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (public.is_active_user(auth.uid()));
CREATE POLICY "active_user_required_invites_update"
  ON public.league_invites AS RESTRICTIVE FOR UPDATE TO authenticated
  USING (public.is_active_user(auth.uid()))
  WITH CHECK (public.is_active_user(auth.uid()));

-- ─────────────────────────────────────────────────────────
-- 3) league_participants INSERT RLS 강화
-- ─────────────────────────────────────────────────────────
-- 기존: auth.role()='authenticated' (느슨)
-- 신규: 공개 리그이거나 호스트 본인일 때만 직접 INSERT 가능.
-- 비공개 리그 가입은 respond_league_invite RPC 만으로 처리.
DROP POLICY IF EXISTS "Authenticated users can join leagues." ON public.league_participants;

CREATE POLICY "league_participants_insert"
  ON public.league_participants FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.leagues l
      WHERE l.id = league_id
        AND (l.is_public = true OR l.host_id = auth.uid())
    )
  );

-- ─────────────────────────────────────────────────────────
-- 4) RPC: create_league_invite
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_league_invite(
  p_league_id uuid,
  p_invitee_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_league record;
  v_invite_id uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다' USING ERRCODE = '28000';
  END IF;
  IF NOT public.is_active_user(v_caller) THEN
    RAISE EXCEPTION '비활성 계정입니다' USING ERRCODE = '42501';
  END IF;
  IF v_caller = p_invitee_id THEN
    RAISE EXCEPTION '자기 자신은 초대할 수 없습니다' USING ERRCODE = '22023';
  END IF;
  IF NOT public.is_active_user(p_invitee_id) THEN
    RAISE EXCEPTION '초대할 수 없는 유저입니다' USING ERRCODE = '42501';
  END IF;

  SELECT id, host_id, is_public, status
    INTO v_league
    FROM public.leagues
    WHERE id = p_league_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '리그를 찾을 수 없습니다' USING ERRCODE = '02000';
  END IF;
  IF v_league.host_id <> v_caller THEN
    RAISE EXCEPTION '호스트만 초대할 수 있습니다' USING ERRCODE = '42501';
  END IF;
  IF v_league.is_public THEN
    RAISE EXCEPTION '공개 리그는 초대 기능을 사용하지 않습니다' USING ERRCODE = '22023';
  END IF;
  IF v_league.status NOT IN ('recruiting', 'in_progress') THEN
    RAISE EXCEPTION '종료된 리그입니다' USING ERRCODE = '22023';
  END IF;

  -- 이미 참여 중(approved/pending)이면 중복 초대 불가
  IF EXISTS (
    SELECT 1 FROM public.league_participants
    WHERE league_id = p_league_id
      AND user_id = p_invitee_id
      AND status IN ('approved', 'pending')
  ) THEN
    RAISE EXCEPTION '이미 참여 중인 유저입니다' USING ERRCODE = '23505';
  END IF;

  -- 이미 살아있는 초대 있으면 그대로 반환 (idempotent)
  SELECT id INTO v_invite_id
    FROM public.league_invites
    WHERE league_id = p_league_id
      AND invitee_id = p_invitee_id
      AND status IN ('pending', 'accepted');
  IF v_invite_id IS NOT NULL THEN
    RETURN v_invite_id;
  END IF;

  -- 새 초대 INSERT. (이전 canceled/declined 행은 그대로 둠 — partial unique라 충돌 없음)
  INSERT INTO public.league_invites (league_id, inviter_id, invitee_id, status)
    VALUES (p_league_id, v_caller, p_invitee_id, 'pending')
    RETURNING id INTO v_invite_id;

  RETURN v_invite_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_league_invite(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.create_league_invite(uuid, uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────
-- 5) RPC: cancel_league_invite (호스트가 보낸 초대 취소)
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cancel_league_invite(p_invite_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_invite record;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다' USING ERRCODE = '28000';
  END IF;

  SELECT i.id, i.status, i.inviter_id
    INTO v_invite
    FROM public.league_invites i
    WHERE i.id = p_invite_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '초대를 찾을 수 없습니다' USING ERRCODE = '02000';
  END IF;
  IF v_invite.inviter_id <> v_caller THEN
    RAISE EXCEPTION '본인이 보낸 초대만 취소할 수 있습니다' USING ERRCODE = '42501';
  END IF;
  IF v_invite.status <> 'pending' THEN
    RAISE EXCEPTION '대기 중인 초대만 취소할 수 있습니다' USING ERRCODE = '22023';
  END IF;

  UPDATE public.league_invites
    SET status = 'canceled', responded_at = now()
    WHERE id = p_invite_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cancel_league_invite(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.cancel_league_invite(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────
-- 6) RPC: respond_league_invite (invitee가 수락/거절)
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.respond_league_invite(
  p_invite_id uuid,
  p_accept boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_invite record;
  v_league record;
  v_approved_count int;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다' USING ERRCODE = '28000';
  END IF;
  IF NOT public.is_active_user(v_caller) THEN
    RAISE EXCEPTION '비활성 계정입니다' USING ERRCODE = '42501';
  END IF;

  SELECT i.id, i.status, i.invitee_id, i.league_id
    INTO v_invite
    FROM public.league_invites i
    WHERE i.id = p_invite_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '초대를 찾을 수 없습니다' USING ERRCODE = '02000';
  END IF;
  IF v_invite.invitee_id <> v_caller THEN
    RAISE EXCEPTION '본인에게 온 초대만 응답할 수 있습니다' USING ERRCODE = '42501';
  END IF;
  IF v_invite.status <> 'pending' THEN
    RAISE EXCEPTION '이미 응답한 초대입니다' USING ERRCODE = '22023';
  END IF;

  IF NOT p_accept THEN
    UPDATE public.league_invites
      SET status = 'declined', responded_at = now()
      WHERE id = p_invite_id;
    RETURN;
  END IF;

  -- 수락 처리
  SELECT id, status, max_participants
    INTO v_league
    FROM public.leagues
    WHERE id = v_invite.league_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '리그를 찾을 수 없습니다' USING ERRCODE = '02000';
  END IF;
  IF v_league.status NOT IN ('recruiting', 'in_progress') THEN
    RAISE EXCEPTION '종료된 리그입니다' USING ERRCODE = '22023';
  END IF;

  SELECT COUNT(*) INTO v_approved_count
    FROM public.league_participants
    WHERE league_id = v_invite.league_id
      AND status = 'approved';

  IF v_approved_count >= v_league.max_participants THEN
    RAISE EXCEPTION '정원이 마감되었습니다' USING ERRCODE = '23514';
  END IF;

  -- 이미 참가자 행이 있으면 approved로 업데이트, 없으면 INSERT
  INSERT INTO public.league_participants (league_id, user_id, status)
    VALUES (v_invite.league_id, v_caller, 'approved')
    ON CONFLICT (league_id, user_id)
    DO UPDATE SET status = 'approved';

  UPDATE public.league_invites
    SET status = 'accepted', responded_at = now()
    WHERE id = p_invite_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.respond_league_invite(uuid, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.respond_league_invite(uuid, boolean) TO authenticated;
