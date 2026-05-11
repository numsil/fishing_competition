-- 공개 리그도 신청제로 전환: 가입은 status='pending' INSERT만 허용, 호스트가 approve.
-- 비공개 리그는 기존대로 RPC(respond_league_invite)로만 가입 → 직접 INSERT 차단.
-- 호스트 본인은 자기 리그에 어떤 status로든 INSERT 가능(즉시 approved 자가가입).
-- 기존 approved/pending/rejected 행은 영향 없음 (INSERT RLS만 변경).

DROP POLICY IF EXISTS "league_participants_insert" ON public.league_participants;

CREATE POLICY "league_participants_insert"
  ON public.league_participants FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.leagues l
      WHERE l.id = league_id
        AND (
          -- 공개 리그 자가 신청은 pending만
          (l.is_public = true AND status = 'pending')
          -- 호스트 본인은 자기 리그에 자유롭게 (status 제약 없음)
          OR l.host_id = auth.uid()
        )
    )
  );
