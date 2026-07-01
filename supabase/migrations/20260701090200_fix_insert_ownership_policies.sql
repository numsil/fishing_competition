-- [MEDIUM] 댓글/신고 작성자 위조 차단
--
-- 문제: 두 INSERT 정책 모두 WITH CHECK가 (auth.role()='authenticated') 뿐이라,
--       user_id / reporter_id 를 타인 UUID로 넣어 남의 이름으로 댓글/신고를 생성할 수 있었음.
-- 해결: 작성자 컬럼을 auth.uid() 에 묶음.
--       (앱은 이미 본인 id를 넣고 있으므로 정상 동작에는 영향 없음.
--        RESTRICTIVE active_user_required_* 정책은 그대로 유지되어 AND로 함께 적용)

-- 댓글: 본인 명의만 작성 가능
DROP POLICY IF EXISTS "Authenticated users can comment." ON public.post_comments;
CREATE POLICY "Users can comment as themselves." ON public.post_comments
  FOR INSERT TO public
  WITH CHECK (auth.uid() = user_id);

-- 신고: 본인 명의만 신고 가능
DROP POLICY IF EXISTS "Users can create reports." ON public.reports;
CREATE POLICY "Users can create reports as themselves." ON public.reports
  FOR INSERT TO public
  WITH CHECK (auth.uid() = reporter_id);
