-- Phase 1: 认证基建 — 加 auth_user_id 列
-- 执行方式：Supabase Dashboard → SQL Editor → 粘贴 → Run

ALTER TABLE admins ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_admins_auth_user ON admins(auth_user_id);

ALTER TABLE members ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_members_auth_user ON members(auth_user_id);

SELECT '✅ Phase 1: 认证基建完成' AS result;
