-- 댓글 신고 지원: reports에 comment_id 추가.
-- post_id는 이미 nullable. 게시물 신고는 post_id, 댓글 신고는 comment_id 사용.
ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS comment_id uuid REFERENCES public.post_comments(id) ON DELETE CASCADE;

-- 둘 중 최소 하나는 있어야 함 (대상 없는 신고 방지).
ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_target_check;
ALTER TABLE public.reports
  ADD CONSTRAINT reports_target_check CHECK (post_id IS NOT NULL OR comment_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_reports_comment_id ON public.reports(comment_id) WHERE comment_id IS NOT NULL;
