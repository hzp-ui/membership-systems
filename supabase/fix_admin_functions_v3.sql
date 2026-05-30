-- ========================================
-- 修复 rpc_create_admin / rpc_update_admin 函数签名
-- 问题: 数据库中函数签名只有 5 个参数（缺少 p_store_id）
-- 解决: 强制删除所有旧签名 + 重新创建完整版本
-- ========================================

-- ========================================
-- 第1步: 删除所有可能存在的旧签名
-- ========================================
DROP FUNCTION IF EXISTS rpc_create_admin(TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS rpc_create_admin(TEXT, TEXT, TEXT, TEXT, admin_role);
DROP FUNCTION IF EXISTS rpc_create_admin(TEXT, TEXT, TEXT, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS rpc_create_admin(TEXT, TEXT, TEXT, TEXT, admin_role, UUID);

DROP FUNCTION IF EXISTS rpc_update_admin(UUID, TEXT, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS rpc_update_admin(UUID, TEXT, TEXT, admin_role, UUID);
DROP FUNCTION IF EXISTS rpc_update_admin(UUID, TEXT, TEXT, TEXT, UUID, TEXT);
DROP FUNCTION IF EXISTS rpc_update_admin(UUID, TEXT, TEXT, admin_role, UUID, TEXT);

RAISE NOTICE '✅ 已删除所有旧的 rpc_create_admin / rpc_update_admin 签名';

-- ========================================
-- 第2步: 检查 admins 表是否有 password 列
-- ========================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'admins' AND column_name = 'password'
  ) THEN
    ALTER TABLE admins ADD COLUMN password TEXT;
    RAISE NOTICE '✅ 已添加 password 列到 admins 表';
  ELSE
    RAISE NOTICE '⚠️ password 列已存在';
  END IF;
END;
$$;

-- ========================================
-- 第3步: 为现有管理员设置默认密码
-- ========================================
UPDATE admins
SET password = crypt('admin123', gen_salt('bf'))
WHERE password IS NULL;

SELECT '✅ 已为 ' || COUNT(*) || ' 个管理员设置默认密码 (admin123)' AS result
FROM admins
WHERE password IS NOT NULL;

-- ========================================
-- 第4步: 创建 rpc_create_admin (6个参数)
-- ========================================
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

RAISE NOTICE '✅ rpc_create_admin 已创建 (6个参数: username, password, name, phone, role, store_id)';

-- ========================================
-- 第5步: 创建 rpc_update_admin (6个参数)
-- ========================================
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

RAISE NOTICE '✅ rpc_update_admin 已创建 (6个参数: id, name, phone, role, store_id, password)';

-- ========================================
-- 第6步: 验证函数签名
-- ========================================
SELECT '📊 当前 rpc_create_admin 签名:' AS info;
SELECT 
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'rpc_create_admin'
  AND n.nspname = 'public';

SELECT '📊 当前 rpc_update_admin 签名:' AS info;
SELECT 
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'rpc_update_admin'
  AND n.nspname = 'public';

-- 完成提示
DO $$
BEGIN
  RAISE NOTICE '✅ ================================';
  RAISE NOTICE '✅ rpc_create_admin / rpc_update_admin 修复完成';
  RAISE NOTICE '✅ 函数签名已更新为 6 个参数';
  RAISE NOTICE '✅ 请重新测试新增管理员功能';
  RAISE NOTICE '✅ ================================';
END;
$$;
