-- 버그 수정: 이전 RLS의 EXISTS 서브쿼리 안에서 unqualified `status`가
-- leagues.status(리그 진행 상태)로 해석되어 공개 리그 신청 INSERT가 항상 실패함.
-- status 체크를 서브쿼리 밖으로 빼서 league_participants.status로 명확히 해석되게 함.

DROP POLICY IF EXISTS "league_participants_insert" ON public.league_participants;

CREATE POLICY "league_participants_insert"
  ON public.league_participants FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND (
      -- 공개 리그 자가 신청: status='pending'만 허용
      (
        status = 'pending'
        AND EXISTS (
          SELECT 1 FROM public.leagues l
          WHERE l.id = league_id
            AND l.is_public = true
        )
      )
      -- 호스트가 자기 리그에 가입: status 제약 없음
      OR EXISTS (
        SELECT 1 FROM public.leagues l
        WHERE l.id = league_id
          AND l.host_id = auth.uid()
      )
    )
  );
