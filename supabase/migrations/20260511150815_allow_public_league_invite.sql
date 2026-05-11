-- 공개 리그도 @user_key 초대 허용. (수락 시 즉시 approved로 가입)
-- 기존: create_league_invite가 is_public=true 리그를 거부했음.
-- 신규: 공개·비공개 모두 호스트가 초대 가능. 비공개의 "초대 전용" 제약은 그대로.

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
  IF v_league.status NOT IN ('recruiting', 'in_progress') THEN
    RAISE EXCEPTION '종료된 리그입니다' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.league_participants
    WHERE league_id = p_league_id
      AND user_id = p_invitee_id
      AND status IN ('approved', 'pending')
  ) THEN
    RAISE EXCEPTION '이미 참여 중인 유저입니다' USING ERRCODE = '23505';
  END IF;

  SELECT id INTO v_invite_id
    FROM public.league_invites
    WHERE league_id = p_league_id
      AND invitee_id = p_invitee_id
      AND status IN ('pending', 'accepted');
  IF v_invite_id IS NOT NULL THEN
    RETURN v_invite_id;
  END IF;

  INSERT INTO public.league_invites (league_id, inviter_id, invitee_id, status)
    VALUES (p_league_id, v_caller, p_invitee_id, 'pending')
    RETURNING id INTO v_invite_id;

  RETURN v_invite_id;
END;
$$;
