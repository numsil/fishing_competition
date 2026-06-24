-- 본인 알림 삭제 허용 (알림함 슬라이드 삭제 기능용)
CREATE POLICY "Users delete own notifications"
    ON public.notifications FOR DELETE
    USING (auth.uid() = user_id);
