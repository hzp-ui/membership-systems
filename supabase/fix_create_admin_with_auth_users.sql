-- ========================================
-- 修复 rpc_create_admin：在 auth.users 中创建用户（用于 Supabase Auth 登录）
-- 问题: 新建店长登录报 "Invalid login credentials"
-- 根因: 前端登录先用 supabase.auth.signInWithPassword 登录 auth.users
--       新建管理员时没在 auth.users 创建记录 → Supabase Auth 找不到用户
-- 解决: 用 auth.jwt() + auth.admin 创建 auth.users 记录
-- ========================================

-- 1. 检查 auth schema 是否可访问
SELECT '📊 检查 auth schema:' AS info;
SELECT EXISTS (
  SELECT 1 FROM information_schema.schemata WHERE schema_name = 'auth'
) AS auth_schema_exists;

-- 2. 检查 auth.users 表结构
SELECT '📊 auth.users 表列（部分）:' AS info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'auth' AND table_name = 'users'
  AND column_name IN ('id', 'email', 'encrypted_password', 'email_confirmed_at', 'role', 'aud', 'instance_id')
ORDER BY ordinal_position;

-- 3. 检查现有 admin 在 auth.users 中的情况
SELECT '📊 admins 与 auth.users 关联情况:' AS info;
SELECT 
  a.id AS admin_id,
  a.username,
  a.name,
  a.role,
  CASE WHEN a.auth_user_id IS NOT NULL THEN '✅ 已绑定' ELSE '❌ 未绑定' END AS auth_bind,
  CASE WHEN au.id IS NOT NULL THEN '✅ auth.users 存在' ELSE '❌ auth.users 不存在' END AS auth_exists
FROM admins a
LEFT JOIN auth.users au ON a.auth_user_id = au.id;

-- 4. 重新创建 rpc_create_admin（自动创建 auth.users）
DROP FUNCTION IF EXISTS rpc_create_admin(TEXT, TEXT, TEXT, TEXT, TEXT, UUID);

CREATE OR REPLACE FUNCTION rpc_create_admin(
  p_username TEXT,
  p_password TEXT,
  p_name TEXT,
  p_phone TEXT,
  p_role TEXT,
  p_store_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_id UUID;
  auth_uid UUID;
BEGIN
  -- 权限检查
  IF NOT (EXISTS (SELECT 1 FROM admins WHERE auth_user_id = auth.uid() AND role = 'super_admin')) THEN
    IF p_store_id IS NOT NULL AND p_store_id != (SELECT store_id FROM admins WHERE auth_user_id = auth.uid()) THEN
      RETURN jsonb_build_object('error', '无权限操作其他门店');
    END IF;
  END IF;

  -- 参数校验
  IF p_role NOT IN ('super_admin', 'store_admin') THEN
    RETURN jsonb_build_object('error', '无效的角色');
  END IF;

  IF p_store_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM stores WHERE id = p_store_id) THEN
      RETURN jsonb_build_object('error', '门店不存在');
    END IF;
  END IF;

  -- 用户名唯一性
  IF EXISTS (SELECT 1 FROM admins WHERE username = p_username) THEN
    RETURN jsonb_build_object('error', '用户名已存在');
  END IF;

  -- 在 auth.users 中创建用户（用于 supabase.auth.signInWithPassword 登录）
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
    is_sso_user
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    p_role,
    p_username || '@membership.internal',
    crypt(p_password, gen_salt('bf')),
    NOW(),
    jsonb_build_object('provider', 'email', 'name', p_name),
    NOW(),
    NOW(),
    false
  )
  RETURNING id INTO auth_uid;

  -- 插入 admins 表（关联 auth_user_id）
  INSERT INTO admins (username, password_hash, name, phone, role, store_id, auth_user_id)
  VALUES (p_username, crypt(p_password, gen_salt('bf')), p_name, p_phone, p_role, p_store_id, auth_uid)
  RETURNING id INTO new_id;

  RETURN jsonb_build_object('data', jsonb_build_object('id', new_id));
END;
$$;

RAISE NOTICE '✅ rpc_create_admin 已更新（自动创建 auth.users + admins）';

-- 完成提示
DO $$
BEGIN
  RAISE NOTICE '✅ ================================';
  RAISE NOTICE '✅ rpc_create_admin 已更新';
  RAISE NOTICE '✅ 新建管理员时会自动创建 auth.users 记录';
  RAISE NOTICE '✅ 请重新测试：新增店长 → 用新账号登录';
  RAISE NOTICE '✅ ================================';
END;
$$;
