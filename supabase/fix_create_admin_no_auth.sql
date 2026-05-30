-- ========================================
-- 修复 rpc_create_admin：移除 auth.users 依赖（纯 RPC 模式）
-- 问题: 新增管理员报 "null value in column id of relation users violates not-null constraint"
-- 根因: fix_create_admin_auth_users.sql 版本会 INSERT auth.users，但纯 RPC 登录不需要
-- 日期: 2026-05-28
-- ========================================

-- 1. 重新创建 rpc_create_admin（纯 RPC 版本，不碰 auth.users）
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
  -- 参数校验
  IF p_role NOT IN ('super_admin', 'store_admin') THEN
    RETURN jsonb_build_object('error', '无效的角色');
  END IF;

  IF p_role = 'store_admin' AND p_store_id IS NULL THEN
    RETURN jsonb_build_object('error', '店长必须绑定门店');
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

  -- 只插入 admins 表（纯 RPC 模式，不依赖 auth.users）
  INSERT INTO admins (username, password_hash, name, phone, role, store_id)
  VALUES (
    p_username,
    crypt(p_password, gen_salt('bf', 10)),
    p_name,
    NULLIF(p_phone, ''),
    NULLIF(p_role, '')::admin_role,
    p_store_id
  )
  RETURNING id, username, name, phone, role, store_id, created_at INTO new_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '创建失败');
  END IF;

  RETURN jsonb_build_object('data', to_jsonb(new_id));
END;
$$;

-- 验证
SELECT '✅ rpc_create_admin 已重建（纯 RPC 版本，不依赖 auth.users）' AS status;
