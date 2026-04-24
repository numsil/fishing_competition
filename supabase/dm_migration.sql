-- DM 기능: conversations & messages 테이블
-- Supabase Dashboard > SQL Editor에서 실행

-- 1. conversations 테이블
create table if not exists conversations (
  id uuid primary key default gen_random_uuid(),
  user1_id uuid references users(id) on delete cascade not null,
  user2_id uuid references users(id) on delete cascade not null,
  last_message text,
  last_message_at timestamptz default now() not null,
  created_at timestamptz default now() not null,
  constraint conversations_unique_pair unique (user1_id, user2_id),
  constraint conversations_ordered_pair check (user1_id < user2_id)
);

-- 2. messages 테이블
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references conversations(id) on delete cascade not null,
  sender_id uuid references users(id) on delete cascade not null,
  content text not null,
  is_read boolean default false not null,
  created_at timestamptz default now() not null
);

-- 3. 인덱스
create index if not exists messages_conversation_id_idx on messages(conversation_id, created_at);
create index if not exists conversations_user1_idx on conversations(user1_id);
create index if not exists conversations_user2_idx on conversations(user2_id);

-- 4. RLS 활성화
alter table conversations enable row level security;
alter table messages enable row level security;

-- 5. conversations RLS
create policy "자신의 대화 조회"
  on conversations for select
  using (auth.uid() = user1_id or auth.uid() = user2_id);

create policy "대화 생성"
  on conversations for insert
  with check (auth.uid() = user1_id or auth.uid() = user2_id);

create policy "자신의 대화 업데이트"
  on conversations for update
  using (auth.uid() = user1_id or auth.uid() = user2_id);

-- 6. messages RLS
create policy "자신의 대화 메시지 조회"
  on messages for select
  using (
    exists (
      select 1 from conversations
      where id = messages.conversation_id
      and (user1_id = auth.uid() or user2_id = auth.uid())
    )
  );

create policy "메시지 전송"
  on messages for insert
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from conversations
      where id = messages.conversation_id
      and (user1_id = auth.uid() or user2_id = auth.uid())
    )
  );

create policy "읽음 처리"
  on messages for update
  using (
    exists (
      select 1 from conversations
      where id = messages.conversation_id
      and (user1_id = auth.uid() or user2_id = auth.uid())
    )
  );

-- 7. Realtime 활성화 (messages 테이블)
alter publication supabase_realtime add table messages;
