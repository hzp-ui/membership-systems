-- ========================================
-- 修复 rpc_create_admin：新建管理员时自动创建 auth.users 记录
-- 问题: 新建店长登录报 "Invalid login credentials"
-- 根因: rpc_create_admin 只插 admins 表，没创建 auth.users
-- ========================================

-- 1. 先检查 rpc_admin_login 的定义（看它怎么验证的）
SELECT '📊 rpc_admin_login 函数定义:' AS info;
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'rpc_admin_login'
  AND n.nspname = 'public';

-- 2. 重新创建 rpc_create_admin（自动创建 auth.users）
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
AS $$
DECLARE
  new_id UUID;
  auth_uid UUID;
BEGIN
  -- 权限检查（super_admin 可操作所有，store_admin 只能操作自己门店）
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

  -- 在 auth.users 中创建用户（用于 Supabase Auth 登录）
  INSERT INTO auth.users (
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    p_role,
    p_username || '@membership.internal',
    crypt(p_password, gen_salt('bf')),
    NOW(),
    jsonb_build_object(
      'provider', 'email',
      'role', p_role,
      'name', p_name
    ),
    NOW(),
    NOW()
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

-- 3. 检查/修复 rpc_admin_login（确保它用 password_hash 验证，不依赖 Supabase Auth）
SELECT '📊 当前 rpc_admin_login 签名:' AS info;
SELECT 
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'rpc_admin_login'
  AND n.nspname = 'public';

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
