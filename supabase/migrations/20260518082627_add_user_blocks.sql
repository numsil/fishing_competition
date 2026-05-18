-- ============================================================
-- blocks: 사용자 간 차단 시스템 (Play Store UGC 정책 필수)
-- ------------------------------------------------------------
-- blocker_id 가 blocked_id 를 차단 → blocker 의 피드/DM 에서
-- blocked 의 흔적이 숨겨진다. blocked 는 자기가 차단당한 줄
-- 명시적으로 알지 못한다.
--
-- v1.0 스코프 (최소 구현):
--   - 피드: 차단된 유저의 게시물 숨김
--   - DM: 차단된 유저에게 메시지 보내기 차단 + 받기 차단
-- v1.1 이후 추가 예정: 리그 랭킹/검색/댓글 필터
-- ============================================================

CREATE TABLE public.blocks (
  blocker_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

CREATE INDEX idx_blocks_blocker ON public.blocks(blocker_id);

ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;

-- 본인이 차단한 목록만 SELECT 가능
CREATE POLICY "blocks_select_own" ON public.blocks
  FOR SELECT USING (blocker_id = auth.uid());

-- 본인 명의로만 INSERT/DELETE
CREATE POLICY "blocks_insert_own" ON public.blocks
  FOR INSERT WITH CHECK (blocker_id = auth.uid());

CREATE POLICY "blocks_delete_own" ON public.blocks
  FOR DELETE USING (blocker_id = auth.uid());


-- ── RPC: 차단 ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.block_user(p_blocked_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF auth.uid() = p_blocked_id THEN
    RAISE EXCEPTION 'cannot block self';
  END IF;
  INSERT INTO public.blocks (blocker_id, blocked_id)
  VALUES (auth.uid(), p_blocked_id)
  ON CONFLICT DO NOTHING;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.block_user(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.block_user(uuid) TO authenticated;


-- ── RPC: 차단 해제 ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.unblock_user(p_blocked_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  DELETE FROM public.blocks
  WHERE blocker_id = auth.uid() AND blocked_id = p_blocked_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.unblock_user(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.unblock_user(uuid) TO authenticated;


-- ── RPC: 차단 목록 (관리 화면용) ──────────────────────────
CREATE OR REPLACE FUNCTION public.get_my_blocked_users()
RETURNS TABLE (
  blocked_id uuid,
  username text,
  user_key text,
  avatar_url text,
  blocked_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    u.id,
    u.username,
    u.user_key,
    u.avatar_url,
    b.created_at
  FROM public.blocks b
  JOIN public.users u ON u.id = b.blocked_id
  WHERE b.blocker_id = auth.uid()
  ORDER BY b.created_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION public.get_my_blocked_users() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_my_blocked_users() TO authenticated;
