-- 알림함용 알림 레코드
CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,   -- 수신자
    type text NOT NULL CHECK (type IN ('dm', 'comment', 'follow')),
    actor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,  -- 행위자
    target_id uuid,                       -- post_id(comment) | conversation_id(dm) | null(follow)
    body text NOT NULL DEFAULT '',
    is_read boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
    ON public.notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON public.notifications(user_id) WHERE is_read = false;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 본인 알림만 조회
CREATE POLICY "Users read own notifications"
    ON public.notifications FOR SELECT
    USING (auth.uid() = user_id);

-- 본인 알림만 읽음 처리(UPDATE)
CREATE POLICY "Users update own notifications"
    ON public.notifications FOR UPDATE
    USING (auth.uid() = user_id);
-- INSERT 정책 없음 → 트리거(SECURITY DEFINER)만 삽입 가능

-- 배지 Realtime 구독용
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- 기기 푸시 토큰
CREATE TABLE IF NOT EXISTS public.device_tokens (
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    token text NOT NULL,
    platform text NOT NULL CHECK (platform IN ('android', 'ios')),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON public.device_tokens(user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own device tokens (select)"
    ON public.device_tokens FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users manage own device tokens (insert)"
    ON public.device_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users manage own device tokens (update)"
    ON public.device_tokens FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users manage own device tokens (delete)"
    ON public.device_tokens FOR DELETE USING (auth.uid() = user_id);
