-- service_types CRUD RPCs
-- 注意：先删除旧函数（因为 PostgreSQL 不允许 CREATE OR REPLACE 移除 DEFAULT 值）

DROP FUNCTION IF EXISTS rpc_get_service_types(UUID);
DROP FUNCTION IF EXISTS rpc_create_service_type(TEXT, UUID);
DROP FUNCTION IF EXISTS rpc_delete_service_type(UUID);

-- 查询服务类型（超级管理员看全部，店长只看本店+全局）
CREATE FUNCTION rpc_get_service_types(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id', st.id,
      'name', st.name,
      'store_id', st.store_id,
      'created_at', st.created_at
    ) ORDER BY st.name
  )
  INTO result
  FROM service_types st
  WHERE st.store_id IS NULL
     OR st.store_id = p_store_id;

  RETURN jsonb_build_object('data', COALESCE(result, '[]'::jsonb), 'error', NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建服务类型
-- 权限：超级管理员可创建全局/任意门店类型；店长只能创建本店类型
CREATE FUNCTION rpc_create_service_type(p_name TEXT, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin_record RECORD;
  v_admin_store_id UUID;
  v_actual_store_id UUID;
  new_id UUID;
BEGIN
  -- 1. 获取当前调用者的管理员信息（通过 JWT token 中的 sub = admin id）
  SELECT store_id, role INTO v_admin_record
  FROM admins
  WHERE id = (SELECT current_setting('request.jwt.claims', true)::jsonb->>'sub')::UUID;

  -- 2. 校验：管理员必须存在
  IF NOT FOUND THEN
    RETURN jsonb_build_object('data', NULL, 'error', '未授权：无效的管理员身份');
  END IF;

  v_admin_store_id := v_admin_record.store_id;

  -- 3. 确定实际写入的 store_id
  v_actual_store_id := NULLIF(p_store_id, '00000000-0000-0000-0000-000000000000'::uuid);

  -- 4. 权限校验
  --    超级管理员(store_id=NULL)：可以创建任何类型
  --    店长(store_id=xxx)：只能创建本店类型，且不能创建全局类型(NULL)
  IF v_admin_store_id IS NOT NULL THEN
    -- 店长：只能创建本店的类型
    IF v_actual_store_id IS NULL THEN
      RETURN jsonb_build_object('data', NULL, 'error', '权限不足：店长不能创建全局类型');
    END IF;
    IF v_actual_store_id != v_admin_store_id THEN
      RETURN jsonb_build_object('data', NULL, 'error', '权限不足：只能为本店创建类型');
    END IF;
  END IF;

  -- 5. 插入
  INSERT INTO service_types (name, store_id)
  VALUES (p_name, v_actual_store_id)
  RETURNING id INTO new_id;

  RETURN jsonb_build_object('data', jsonb_build_object('id', new_id), 'error', NULL);
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('data', NULL, 'error', '该服务类型已存在');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 删除服务类型
-- 权限：超级管理员可删除任意类型；店长只能删除本店创建的类型，不能删全局的
CREATE FUNCTION rpc_delete_service_type(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_target_store_id UUID;
  v_admin_store_id UUID;
BEGIN
  -- 1. 获取目标类型的 store_id
  SELECT store_id INTO v_target_store_id
  FROM service_types
  WHERE id = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('data', NULL, 'error', '服务类型不存在');
  END IF;

  -- 2. 获取当前管理员的 store_id
  SELECT a.store_id INTO v_admin_store_id
  FROM admins a
  WHERE a.id = (SELECT current_setting('request.jwt.claims', true)::jsonb->>'sub')::UUID;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('data', NULL, 'error', '未授权：无效的管理员身份');
  END IF;

  -- 3. 权限校验
  IF v_admin_store_id IS NOT NULL THEN
    -- 店长：不能删除全局类型
    IF v_target_store_id IS NULL THEN
      RETURN jsonb_build_object('data', NULL, 'error', '权限不足：店长不能删除全局类型');
    END IF;
    -- 店长：只能删除本店创建的类型
    IF v_target_store_id != v_admin_store_id THEN
      RETURN jsonb_build_object('data', NULL, 'error', '权限不足：只能删除本店创建的类型');
    END IF;
  END IF;
  -- 超级管理员(store_id=NULL)：可以删除任意类型

  -- 4. 删除
  DELETE FROM service_types WHERE id = p_id;
  RETURN jsonb_build_object('data', TRUE, 'error', NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
