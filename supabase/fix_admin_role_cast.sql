-- ========================================
-- 修复 rpc_create_admin 和 rpc_update_admin
-- 问题: type "admin_role" does not exist
-- 原因: 函数内还有 ::admin_role 强制类型转换
-- 解决: 移除所有枚举强转，p_role 直接用 TEXT
-- ========================================

-- 先删除旧函数（如果有错误的参数签名）
DROP FUNCTION IF EXISTS rpc_create_admin(TEXT, TEXT, TEXT, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS rpc_create_admin(TEXT, TEXT, TEXT, TEXT, admin_role, UUID);
DROP FUNCTION IF EXISTS rpc_update_admin(UUID, TEXT, TEXT, TEXT, UUID, TEXT);
DROP FUNCTION IF EXISTS rpc_update_admin(UUID, TEXT, TEXT, admin_role, UUID, TEXT);

-- ========================================
-- 修复 rpc_create_admin
-- ========================================
CREATE OR REPLACE FUNCTION rpc_create_admin(
  p_username TEXT,
  p_password TEXT,
  p_name TEXT,
  p_phone TEXT,
  p_role TEXT,  -- 直接用 TEXT，不转 enum
  p_store_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_id UUID;
  role_check TEXT;
BEGIN
  -- 权限检查: super_admin 可创建所有，store_admin 只能创建自己门店的
  IF NOT (EXISTS (SELECT 1 FROM admins WHERE auth_user_id = auth.uid() AND role = 'super_admin')) THEN
    IF NOT (p_store_id = (SELECT store_id FROM admins WHERE auth_user_id = auth.uid())) THEN
      RETURN jsonb_build_object('error', '无权限操作其他门店');
    END IF;
  END IF;

  -- 参数校验
  IF p_role NOT IN ('super_admin', 'store_admin') THEN
    RETURN jsonb_build_object('error', '无效的角色，只能是 super_admin 或 store_admin');
  END IF;

  IF p_store_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM stores WHERE id = p_store_id) THEN
      RETURN jsonb_build_object('error', '门店不存在');
    END IF;
  END IF;

  -- 用户名唯一性检查
  IF EXISTS (SELECT 1 FROM admins WHERE username = p_username) THEN
    RETURN jsonb_build_object('error', '用户名已存在');
  END IF;

  -- 插入（role 直接写 TEXT，不做 ::admin_role 强转）
  INSERT INTO admins (username, password, name, phone, role, store_id)
  VALUES (p_username, crypt(p_password, gen_salt('bf')), p_name, p_phone, p_role, p_store_id)
  RETURNING id INTO new_id;

  RETURN jsonb_build_object('data', jsonb_build_object('id', new_id));
END;
$$;

-- ========================================
-- 修复 rpc_update_admin
-- ========================================
CREATE OR REPLACE FUNCTION rpc_update_admin(
  p_id UUID,
  p_name TEXT,
  p_phone TEXT,
  p_role TEXT,  -- 直接用 TEXT，不转 enum
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
    IF NOT (p_store_id = (SELECT store_id FROM admins WHERE auth_user_id = auth.uid())) THEN
      RETURN jsonb_build_object('error', '无权限操作其他门店');
    END IF;
  END IF;

  -- 参数校验
  IF p_role NOT IN ('super_admin', 'store_admin') THEN
    RETURN jsonb_build_object('error', '无效的角色，只能是 super_admin 或 store_admin');
  END IF;

  IF p_store_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM stores WHERE id = p_store_id) THEN
      RETURN jsonb_build_object('error', '门店不存在');
    END IF;
  END IF;

  -- 更新（role 直接写 TEXT，不做 ::admin_role 强转）
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

-- ========================================
-- 完成提示
-- ========================================
DO $$
BEGIN
  RAISE NOTICE '✅ rpc_create_admin / rpc_update_admin 修复完成（移除 admin_role 枚举强转）';
END;
$$;
