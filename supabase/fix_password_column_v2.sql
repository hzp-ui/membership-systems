-- ========================================
-- 检查 admins 表结构 + 彻底修复 password 列
-- ========================================

-- 1. 检查 admins 表的所有列
SELECT '📊 admins 表结构:' AS info;
SELECT 
  column_name, 
  data_type, 
  is_nullable
FROM information_schema.columns
WHERE table_name = 'admins'
ORDER BY ordinal_position;

-- 2. 如果 password 列不存在，立即添加
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'admins' AND column_name = 'password'
  ) THEN
    ALTER TABLE admins ADD COLUMN password TEXT;
    RAISE NOTICE '✅ 已添加 password 列';
  ELSE
    RAISE NOTICE '⚠️ password 列已存在';
  END IF;
END;
$$;

-- 3. 为现有管理员设置默认密码（bcrypt 哈希）
UPDATE admins
SET password = crypt('admin123', gen_salt('bf'))
WHERE password IS NULL;

SELECT '✅ 已为 ' || COUNT(*) || ' 个管理员设置默认密码' AS result
FROM admins
WHERE password IS NOT NULL;

-- 4. 检查 rpc_create_admin 函数定义（看它是否在引用 password 列）
SELECT '📊 rpc_create_admin 函数定义:' AS info;
SELECT pg_get_functiondef('rpc_create_admin(TEXT, TEXT, TEXT, TEXT, TEXT, UUID)'::regprocedure);

-- 5. 如果上面的查询报错，尝试不带参数签名查询
SELECT '📊 所有名为 rpc_create_admin 的函数:' AS info;
SELECT 
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'rpc_create_admin'
  AND n.nspname = 'public';

-- 6. 重新创建 rpc_create_admin（确保它正确引用 password 列）
-- 先删除所有可能存在的签名
DROP FUNCTION IF EXISTS rpc_create_admin(TEXT, TEXT, TEXT, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS rpc_create_admin(TEXT, TEXT, TEXT, TEXT, admin_role, UUID);

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

  -- 插入（明确指定 password 列）
  INSERT INTO admins (username, password, name, phone, role, store_id)
  VALUES (p_username, crypt(p_password, gen_salt('bf')), p_name, p_phone, p_role, p_store_id)
  RETURNING id INTO new_id;

  RETURN jsonb_build_object('data', jsonb_build_object('id', new_id));
END;
$$;

-- 7. 重新创建 rpc_update_admin
DROP FUNCTION IF EXISTS rpc_update_admin(UUID, TEXT, TEXT, TEXT, UUID, TEXT);
DROP FUNCTION IF EXISTS rpc_update_admin(UUID, TEXT, TEXT, admin_role, UUID, TEXT);

CREATE OR REPLACE FUNCTION rpc_update_admin(
  p_id UUID,
  p_name TEXT,
  p_phone TEXT,
  p_role TEXT,
  p_store_id UUID,
  p_password TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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

  -- 更新
  IF p_password IS NOT NULL AND p_password != '' THEN
    UPDATE admins
    SET name = p_name,
        phone = p_phone,
        role = p_role,
        store_id = p_store_id,
        password = crypt(p_password, gen_salt('bf')),
        updated_at = NOW()
    WHERE id = p_id;
  ELSE
    UPDATE admins
    SET name = p_name,
        phone = p_phone,
        role = p_role,
        store_id = p_store_id,
        updated_at = NOW()
    WHERE id = p_id;
  END IF;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '管理员不存在');
  END IF;

  RETURN jsonb_build_object('data', jsonb_build_object('success', true));
END;
$$;

-- 8. 完成提示
DO $$
BEGIN
  RAISE NOTICE '✅ ================================';
  RAISE NOTICE '✅ admins 表 password 列已确认存在';
  RAISE NOTICE '✅ rpc_create_admin 已重新创建';
  RAISE NOTICE '✅ rpc_update_admin 已重新创建';
  RAISE NOTICE '✅ 请重新测试新增管理员功能';
  RAISE NOTICE '✅ ================================';
END;
$$;
