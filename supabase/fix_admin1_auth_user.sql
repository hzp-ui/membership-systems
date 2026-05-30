-- ========================================
-- 为 admin1 补建 auth.users 记录
-- 问题: admin1 的 auth_user_id 为 NULL，auth.users 缺失
-- ========================================

-- 1. 检查 admin1 当前状态
SELECT '📊 admin1 当前状态:' AS info;
SELECT id, username, name, role, store_id, auth_user_id, password_hash
FROM admins
WHERE username = 'admin1';

-- 2. 在 auth.users 中创建 admin1 的记录
-- 注意：需要正确的 instance_id，通常是 '00000000-0000-0000-0000-000000000000'
INSERT INTO auth.users (
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_user_meta_data,
  created_at,
  updated_at,
  is_sso_user,
  confirmation_sent_at,
  recovery_sent_at,
  email_change,
  new_email,
  new_phone,
  invited_at,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  email_change_token_current,
  reauthentication_token,
  is_anonymous
)
VALUES (
  '00000000-0000-0000-0000-000000000000',  -- instance_id
  'authenticated',                           -- aud
  'authenticated',                           -- role
  'admin1@membership.internal',              -- email
  crypt('admin123', gen_salt('bf')),         -- encrypted_password
  NOW(),                                     -- email_confirmed_at
  jsonb_build_object('provider', 'email', 'name', 'admin1'),  -- raw_user_meta_data
  NOW(),                                     -- created_at
  NOW(),                                     -- updated_at
  false,                                     -- is_sso_user
  NULL,                                      -- confirmation_sent_at
  NULL,                                      -- recovery_sent_at
  NULL,                                      -- email_change
  NULL,                                      -- new_email
  NULL,                                      -- new_phone
  NULL,                                      -- invited_at
  '',                                        -- confirmation_token
  '',                                        -- recovery_token
  '',                                        -- email_change_token_new
  '',                                        -- email_change_token_current
  '',                                        -- reauthentication_token
  false                                      -- is_anonymous
)
RETURNING id AS new_auth_user_id;

-- 3. 更新 admins 表的 auth_user_id
UPDATE admins
SET auth_user_id = (
  SELECT id FROM auth.users WHERE email = 'admin1@membership.internal'
)
WHERE username = 'admin1';

-- 4. 验证修复结果
SELECT '📊 修复后 admin1 状态:' AS info;
SELECT 
  a.id AS admin_id,
  a.username,
  a.name,
  a.role,
  a.auth_user_id,
  au.email,
  au.encrypted_password IS NOT NULL AS has_password,
  CASE WHEN au.id IS NOT NULL THEN '✅ auth.users 已创建' ELSE '❌ 仍缺失' END AS status
FROM admins a
LEFT JOIN auth.users au ON a.auth_user_id = au.id
WHERE a.username = 'admin1';

-- 完成提示
DO $$
BEGIN
  RAISE NOTICE '✅ ================================';
  RAISE NOTICE '✅ admin1 的 auth.users 记录已补建';
  RAISE NOTICE '✅ 邮箱: admin1@membership.internal';
  RAISE NOTICE '✅ 密码: admin123';
  RAISE NOTICE '✅ 请用 admin1/admin123 登录测试';
  RAISE NOTICE '✅ ================================';
END;
$$;
