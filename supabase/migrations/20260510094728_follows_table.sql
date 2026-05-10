-- 단방향 팔로우 테이블 (인스타식)
CREATE TABLE IF NOT EXISTS public.follows (
    follower_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    followee_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (follower_id, followee_id),
    CONSTRAINT no_self_follow CHECK (follower_id <> followee_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_followee ON public.follows(followee_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_follows_follower ON public.follows(follower_id, created_at DESC);

ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Follows are viewable by everyone."
ON public.follows FOR SELECT
USING (true);

CREATE POLICY "Users can follow others."
ON public.follows FOR INSERT
WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can unfollow."
ON public.follows FOR DELETE
USING (auth.uid() = follower_id);
