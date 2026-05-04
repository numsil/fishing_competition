-- users 테이블에 인증자 권한 컬럼 추가
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verifier BOOLEAN NOT NULL DEFAULT FALSE;

-- 인덱스 (인증자 목록 조회 최적화)
CREATE INDEX IF NOT EXISTS idx_users_is_verifier ON users(is_verifier) WHERE is_verifier = TRUE;
