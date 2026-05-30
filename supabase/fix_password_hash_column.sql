-- ========================================
-- 检查 admins 表结构 + 修复 password_hash 列问题
-- 错误: null value in column "password_hash" violates not-null constraint
-- ========================================

-- 1. 检查 admins 表的所有列
SELECT '📊 admins 表结构:' AS info;
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'admins'
ORDER BY ordinal_position;

-- 2. 检查是否有 password 列
SELECT '📊 检查 password 列:' AS info;
SELECT EXISTS (
  SELECT 1 FROM information_schema.columns
  WHERE table_name = 'admins' AND column_name = 'password'
) AS has_password_column;

-- 3. 检查是否有 password_hash 列
SELECT '📊 检查 password_hash 列:' AS info;
SELECT EXISTS (
  SELECT 1 FROM information_schema.columns
  WHERE table_name = 'admins' AND column_name = 'password_hash'
) AS has_password_hash_column;

-- 4. 如果同时存在两个列，删除 password 列（保留 password_hash）
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'admins' AND column_name = 'password')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'admins' AND column_name = 'password_hash') THEN
    ALTER TABLE admins DROP COLUMN password;
    RAISE NOTICE '✅ 已删除重复的 password 列（保留 password_hash）';
  ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'admins' AND column_name = 'password')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'admins' AND column_name = 'password_hash') THEN
    -- 重命名 password 为 password_hash
    ALTER TABLE admins RENAME COLUMN password TO password_hash;
    RAISE NOTICE '✅ 已将 password 列重命名为 password_hash';
  ELSIF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'admins' AND column_name = 'password')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'admins' AND column_name = 'password_hash') THEN
    RAISE NOTICE '✅ password_hash 列已存在，无需修改';
  ELSE
    -- 两个列都不存在，添加 password_hash
    ALTER TABLE admins ADD COLUMN password_hash TEXT NOT NULL DEFAULT crypt('admin123', gen_salt('bf'));
    RAISE NOTICE '✅ 已添加 password_hash 列';
  END IF;
END;
$$;

-- 5. 如果 password_hash 有 NOT NULL 约束，但需要允许 NULL（用于 UPDATE 时不改密码）
-- 先检查约束
SELECT '📊 password_hash 列约束:' AS info;
SELECT 
  column_name,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'admins' AND column_name = 'password_hash';

-- 6. 如果 NOT NULL 约束导致问题，可以临时移除（可选）
-- ALTER TABLE admins ALTER COLUMN password_hash DROP NOT NULL;

-- 7. 为现有管理员设置默认密码（如果 password_hash 为 NULL 或有默认值）
UPDATE admins
SET password_hash = crypt('admin123', gen_salt('bf'))
WHERE password_hash IS NULL;

SELECT '✅ 已为 ' || COUNT(*) || ' 个管理员设置默认密码 (admin123)' AS result
FROM admins
WHERE password_hash IS NOT NULL;

-- 8. 重新创建 rpc_create_admin（使用 password_hash 列）
DROP FUNCTION IF EXISTS rpc_create_admin(TEXT, TEXT, TEXT, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS rpc_create_admin(TEXT, TEXT, TEXT, TEXT, admin_role, UUID);
DROP FUNCTION IF EXISTS rpc_create_admin(TEXT, TEXT, TEXT, TEXT, UUID);
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

  -- 插入（使用 password_hash 列）
  INSERT INTO admins (username, password_hash, name, phone, role, store_id)
  VALUES (p_username, crypt(p_password, gen_salt('bf')), p_name, p_phone, p_role, p_store_id)
  RETURNING id INTO new_id;

  RETURN jsonb_build_object('data', jsonb_build_object('id', new_id));
END;
$$;

RAISE NOTICE '✅ rpc_create_admin 已更新（使用 password_hash 列）';

-- 9. 重新创建 rpc_update_admin（使用 password_hash 列）
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

  -- 更新（使用 password_hash 列）
  IF p_password IS NOT NULL AND p_password != '' THEN
    UPDATE admins
    SET name = p_name,
        phone = p_phone,
        role = p_role,
        store_id = p_store_id,
        password_hash = crypt(p_password, gen_salt('bf')),
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

RAISE NOTICE '✅ rpc_update_admin 已更新（使用 password_hash 列）';

-- 10. 重新创建 rpc_login（使用 password_hash 列）
DROP FUNCTION IF EXISTS rpc_login(TEXT, TEXT);

CREATE OR REPLACE FUNCTION rpc_login(
  p_username TEXT,
  p_password TEXT
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  admin_record admins%ROWTYPE;
BEGIN
  -- 查找管理员（验证密码，使用 password_hash 列）
  SELECT * INTO admin_record
  FROM admins
  WHERE username = p_username
    AND password_hash = crypt(p_password, password_hash);

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '用户名或密码错误');
  END IF;

  -- 返回管理员信息（不包含密码）
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'id', admin_record.id,
      'username', admin_record.username,
      'name', admin_record.name,
      'phone', admin_record.phone,
      'role', admin_record.role,
      'store_id', admin_record.store_id
    )
  );
END;
$$;

RAISE NOTICE '✅ rpc_login 已更新（使用 password_hash 列）';

-- 完成提示
DO $$
BEGIN
  RAISE NOTICE '✅ ================================';
  RAISE NOTICE '✅ admins 表 password_hash 列修复完成';
  RAISE NOTICE '✅ rpc_create_admin / rpc_update_admin / rpc_login 已更新';
  RAISE NOTICE '✅ 请重新测试新增管理员功能';
  RAISE NOTICE '✅ ================================';
END;
$$;
