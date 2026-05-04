-- review_status CHECK 제약에 pending, rejected 추가
ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_review_status_check;
ALTER TABLE posts ADD CONSTRAINT posts_review_status_check
  CHECK (review_status IN ('approved', 'held', 'pending', 'rejected'));
