-- ============================================================
-- DM 미읽음 카운트 + 나만 숨김 기능 마이그레이션
-- Supabase Dashboard > SQL Editor 에서 실행
-- ============================================================

-- conversations 테이블 컬럼 추가
ALTER TABLE conversations
  ADD COLUMN IF NOT EXISTS unread_count_user1 INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS unread_count_user2 INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS user1_hidden_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS user2_hidden_at    TIMESTAMPTZ;

-- 메시지 전송 시 수신자 unread +1, 수신자 hidden_at 초기화
CREATE OR REPLACE FUNCTION on_dm_sent(
  p_conv_id   UUID,
  p_sender_id UUID,
  p_content   TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE conversations SET
    last_message       = p_content,
    last_message_at    = NOW(),
    unread_count_user1 = CASE WHEN user2_id = p_sender_id THEN unread_count_user1 + 1 ELSE unread_count_user1 END,
    unread_count_user2 = CASE WHEN user1_id = p_sender_id THEN unread_count_user2 + 1 ELSE unread_count_user2 END,
    user1_hidden_at    = CASE WHEN user2_id = p_sender_id THEN NULL ELSE user1_hidden_at END,
    user2_hidden_at    = CASE WHEN user1_id = p_sender_id THEN NULL ELSE user2_hidden_at END
  WHERE id = p_conv_id;
END;
$$;

-- 읽음 처리 시 내 unread_count 0으로 리셋
CREATE OR REPLACE FUNCTION on_dm_read(
  p_conv_id   UUID,
  p_reader_id UUID
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE conversations SET
    unread_count_user1 = CASE WHEN user1_id = p_reader_id THEN 0 ELSE unread_count_user1 END,
    unread_count_user2 = CASE WHEN user2_id = p_reader_id THEN 0 ELSE unread_count_user2 END
  WHERE id = p_conv_id;
END;
$$;

-- 대화방 나만 숨김 (상대방 새 메시지 오면 last_message_at > hidden_at 으로 자동 복원)
CREATE OR REPLACE FUNCTION hide_conversation(
  p_conv_id UUID,
  p_user_id UUID
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE conversations SET
    user1_hidden_at = CASE WHEN user1_id = p_user_id THEN NOW() ELSE user1_hidden_at END,
    user2_hidden_at = CASE WHEN user2_id = p_user_id THEN NOW() ELSE user2_hidden_at END
  WHERE id = p_conv_id;
END;
$$;
