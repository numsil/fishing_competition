-- 본인 댓글 수정 허용. (기존엔 INSERT/SELECT/DELETE만 있고 UPDATE 정책이 없어 수정 불가였음)
DROP POLICY IF EXISTS "Users can update own comments" ON public.post_comments;
CREATE POLICY "Users can update own comments"
  ON public.post_comments
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
