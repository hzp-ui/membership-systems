-- ========================================
-- 检查 auth.users 表结构（用于调试）
-- ========================================

-- 1. 检查 auth.users 所有列
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'auth' AND table_name = 'users'
ORDER BY ordinal_position;

-- 2. 检查约束
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'auth.users'::regclass;

-- 3. 查看一条现有记录的结构（脱敏）
SELECT 
  id,
  email,
  role,
  aud,
  instance_id,
  email_confirmed_at IS NOT NULL AS email_confirmed,
  encrypted_password IS NOT NULL AS has_password,
  created_at,
  updated_at
FROM auth.users
WHERE email = 'admin@membership.internal'
LIMIT 1;
