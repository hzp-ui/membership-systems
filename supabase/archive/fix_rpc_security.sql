-- =============================================
-- RPC 权限安全加固
-- 方案：前端传 p_admin_id，后端校验身份+强制门店隔离
-- 所有写操作函数增加调用者权限校验
-- =============================================

-- ==================== 辅助函数：校验管理员身份 ====================
-- 返回 (role, store_id)，校验失败抛异常
CREATE OR REPLACE FUNCTION rpc_check_admin(p_admin_id UUID)
RETURNS RECORD AS $$
DECLARE
  v_role TEXT;
  v_store_id UUID;
  v_result RECORD;
BEGIN
  SELECT role, store_id INTO v_role, v_store_id
  FROM admins WHERE id = p_admin_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '无效的管理员身份';
  END IF;
  
  -- 构造返回值
  SELECT v_role, v_store_id INTO v_result;
  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ==================== 辅助函数：校验门店归属 ====================
-- 店长只能操作自己门店的数据，超管可操作所有
-- 参数：p_admin_id, p_target_store_id(要操作的数据所属门店)
-- 如果店长试图操作其他门店，抛异常
CREATE OR REPLACE FUNCTION rpc_check_store_access(p_admin_id UUID, p_target_store_id UUID)
RETURNS VOID AS $$
DECLARE
  v_role TEXT;
  v_store_id UUID;
BEGIN
  SELECT role, store_id INTO v_role, v_store_id
  FROM admins WHERE id = p_admin_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '无效的管理员身份';
  END IF;
  
  -- 店长检查
  IF v_role = 'store_admin' THEN
    IF v_store_id IS NULL THEN
      RAISE EXCEPTION '店长未绑定门店，数据异常';
    END IF;
    IF p_target_store_id IS NOT NULL AND p_target_store_id != v_store_id THEN
      RAISE EXCEPTION '无权操作其他门店数据';
    END IF;
  END IF;
  -- super_admin 自动放行
END;
$$ LANGUAGE plpgsql;

-- ==================== 辅助函数：强制门店过滤 ====================
-- 店长查询时强制覆盖 p_store_id 为自己的门店
-- 返回实际应该使用的 store_id
CREATE OR REPLACE FUNCTION rpc_enforce_store_filter(p_admin_id UUID, p_store_id UUID)
RETURNS UUID AS $$
DECLARE
  v_role TEXT;
  v_store_id UUID;
BEGIN
  SELECT role, store_id INTO v_role, v_store_id
  FROM admins WHERE id = p_admin_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '无效的管理员身份';
  END IF;
  
  -- 店长强制用自己门店
  IF v_role = 'store_admin' THEN
    RETURN v_store_id;
  END IF;
  
  -- 超管：用传入的 store_id（可为 NULL 查全部）
  RETURN p_store_id;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- 以下重写所有需要权限校验的 RPC 函数
-- 所有函数新增 p_admin_id 参数（放第一个）
-- =============================================


-- ==================== 管理员 CRUD ====================

DROP FUNCTION IF EXISTS rpc_get_admins;
CREATE OR REPLACE FUNCTION rpc_get_admins(p_admin_id UUID, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'username', t.username, 'name', t.name,
    'phone', t.phone, 'role', t.role, 'store_id', t.store_id,
    'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT a.id, a.username, a.name, a.phone, a.role, a.store_id, a.created_at, s.name AS store_name
    FROM admins a LEFT JOIN stores s ON a.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR a.store_id = v_actual_store_id)
    ORDER BY a.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_create_admin;
CREATE OR REPLACE FUNCTION rpc_create_admin(p_admin_id UUID, p_username TEXT, p_password TEXT, p_name TEXT, p_phone TEXT, p_role TEXT, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_role TEXT;
  v_store_id UUID;
  v_record RECORD;
BEGIN
  SELECT role, store_id INTO v_role, v_store_id FROM admins WHERE id = p_admin_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '无效的管理员身份'); END IF;
  
  -- 只有超管能创建管理员
  IF v_role != 'super_admin' THEN
    RETURN jsonb_build_object('error', '只有超级管理员才能创建管理员账号');
  END IF;
  
  IF p_role = 'store_admin' AND p_store_id IS NULL THEN
    RETURN jsonb_build_object('error', '店长必须绑定门店');
  END IF;
  INSERT INTO admins (username, password_hash, name, phone, role, store_id)
  VALUES (
    p_username,
    crypt(p_password, gen_salt('bf', 10)),
    p_name,
    NULLIF(p_phone, ''),
    NULLIF(p_role, ''),
    p_store_id
  )
  RETURNING id, username, name, phone, role, store_id, created_at INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_update_admin;
CREATE OR REPLACE FUNCTION rpc_update_admin(p_admin_id UUID, p_id UUID, p_name TEXT, p_phone TEXT, p_role TEXT, p_store_id UUID, p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_role TEXT;
  v_store_id UUID;
  v_target RECORD;
  v_record RECORD;
BEGIN
  SELECT role, store_id INTO v_role, v_store_id FROM admins WHERE id = p_admin_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '无效的管理员身份'); END IF;
  
  -- 只有超管能修改管理员
  IF v_role != 'super_admin' THEN
    RETURN jsonb_build_object('error', '只有超级管理员才能修改管理员信息');
  END IF;
  
  -- 不允许修改自己的角色
  IF p_admin_id = p_id AND p_role IS NOT NULL AND p_role != v_role THEN
    RETURN jsonb_build_object('error', '不能修改自己的角色');
  END IF;
  
  IF p_password IS NOT NULL AND p_password != '' THEN
    UPDATE admins SET
      name = COALESCE(NULLIF(p_name, ''), name),
      phone = COALESCE(NULLIF(p_phone, ''), phone),
      role = COALESCE(NULLIF(p_role, ''), role),
      store_id = COALESCE(p_store_id, store_id),
      password_hash = crypt(p_password, gen_salt('bf', 10))
    WHERE id = p_id
    RETURNING id, username, name, phone, role, store_id, created_at INTO v_record;
  ELSE
    UPDATE admins SET
      name = COALESCE(NULLIF(p_name, ''), name),
      phone = COALESCE(NULLIF(p_phone, ''), phone),
      role = COALESCE(NULLIF(p_role, ''), role),
      store_id = COALESCE(p_store_id, store_id)
    WHERE id = p_id
    RETURNING id, username, name, phone, role, store_id, created_at INTO v_record;
  END IF;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '管理员不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_delete_admin;
CREATE OR REPLACE FUNCTION rpc_delete_admin(p_admin_id UUID, p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT role INTO v_role FROM admins WHERE id = p_admin_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '无效的管理员身份'); END IF;
  
  IF v_role != 'super_admin' THEN
    RETURN jsonb_build_object('error', '只有超级管理员才能删除管理员');
  END IF;
  
  -- 不允许删除自己
  IF p_admin_id = p_id THEN
    RETURN jsonb_build_object('error', '不能删除自己的账号');
  END IF;
  
  DELETE FROM admins WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '管理员不存在'); END IF;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==================== 门店 CRUD ====================

DROP FUNCTION IF EXISTS rpc_create_store;
CREATE OR REPLACE FUNCTION rpc_create_store(p_admin_id UUID, p_name TEXT, p_address TEXT, p_phone TEXT, p_manager TEXT)
RETURNS JSONB AS $$
DECLARE
  v_role TEXT;
  v_record RECORD;
BEGIN
  SELECT role INTO v_role FROM admins WHERE id = p_admin_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '无效的管理员身份'); END IF;
  
  IF v_role != 'super_admin' THEN
    RETURN jsonb_build_object('error', '只有超级管理员才能创建门店');
  END IF;
  
  INSERT INTO stores (name, address, phone, manager)
  VALUES (p_name, NULLIF(p_address, ''), NULLIF(p_phone, ''), NULLIF(p_manager, ''))
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_update_store;
CREATE OR REPLACE FUNCTION rpc_update_store(p_admin_id UUID, p_id UUID, p_name TEXT, p_address TEXT, p_phone TEXT, p_manager TEXT, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_role TEXT;
  v_record RECORD;
BEGIN
  SELECT role INTO v_role FROM admins WHERE id = p_admin_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '无效的管理员身份'); END IF;
  
  IF v_role != 'super_admin' THEN
    RETURN jsonb_build_object('error', '只有超级管理员才能修改门店');
  END IF;
  
  UPDATE stores SET
    name = COALESCE(NULLIF(p_name, ''), name),
    address = COALESCE(NULLIF(p_address, ''), address),
    phone = COALESCE(NULLIF(p_phone, ''), phone),
    manager = COALESCE(NULLIF(p_manager, ''), manager),
    status = COALESCE(NULLIF(p_status, ''), status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '门店不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==================== 会员 CRUD ====================

DROP FUNCTION IF EXISTS rpc_get_members;
CREATE OR REPLACE FUNCTION rpc_get_members(p_admin_id UUID, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'phone', t.phone, 'name', t.name, 'level', t.level,
    'points', t.points, 'balance', t.balance, 'store_id', t.store_id,
    'status', t.status, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT m.id, m.phone, m.name, m.level, m.points, m.balance, m.store_id,
           m.status, m.created_at, s.name AS store_name
    FROM members m LEFT JOIN stores s ON m.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR m.store_id = v_actual_store_id)
    ORDER BY m.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_update_member;
CREATE OR REPLACE FUNCTION rpc_update_member(p_admin_id UUID, p_id UUID, p_name TEXT, p_phone TEXT, p_level TEXT, p_points BIGINT, p_balance DECIMAL, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_member_store_id UUID;
  v_record RECORD;
BEGIN
  -- 先查会员所属门店
  SELECT store_id INTO v_member_store_id FROM members WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在'); END IF;
  
  -- 校验门店权限
  PERFORM rpc_check_store_access(p_admin_id, v_member_store_id);
  
  UPDATE members SET
    name = COALESCE(NULLIF(p_name, ''), name),
    phone = COALESCE(NULLIF(p_phone, ''), phone),
    level = COALESCE(NULLIF(p_level, ''), level),
    points = COALESCE(p_points, points),
    balance = COALESCE(p_balance, balance),
    status = COALESCE(NULLIF(p_status, ''), status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==================== 理发师 CRUD ====================

DROP FUNCTION IF EXISTS rpc_get_barbers;
CREATE OR REPLACE FUNCTION rpc_get_barbers(p_admin_id UUID, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'name', t.name, 'phone', t.phone,
    'specialties', t.specialties, 'status', t.status,
    'store_id', t.store_id, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT b.id, b.name, b.phone, b.specialties, b.status, b.store_id, b.created_at, s.name AS store_name
    FROM barbers b LEFT JOIN stores s ON b.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR b.store_id = v_actual_store_id)
    ORDER BY b.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_create_barber;
CREATE OR REPLACE FUNCTION rpc_create_barber(p_admin_id UUID, p_name TEXT, p_phone TEXT, p_specialties JSONB, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  PERFORM rpc_check_store_access(p_admin_id, p_store_id);
  
  -- 店长强制用自己门店
  IF p_store_id IS NULL THEN
    SELECT store_id INTO p_store_id FROM admins WHERE id = p_admin_id;
  END IF;
  
  INSERT INTO barbers (name, phone, specialties, store_id)
  VALUES (p_name, NULLIF(p_phone, ''), p_specialties::text[], p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_update_barber;
CREATE OR REPLACE FUNCTION rpc_update_barber(p_admin_id UUID, p_id UUID, p_name TEXT, p_phone TEXT, p_specialties JSONB, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_barber_store_id UUID;
  v_record RECORD;
BEGIN
  SELECT store_id INTO v_barber_store_id FROM barbers WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '理发师不存在'); END IF;
  
  PERFORM rpc_check_store_access(p_admin_id, v_barber_store_id);
  
  UPDATE barbers SET
    name = COALESCE(NULLIF(p_name, ''), name),
    phone = COALESCE(NULLIF(p_phone, ''), phone),
    specialties = COALESCE(p_specialties::text[], specialties),
    status = COALESCE(NULLIF(p_status, ''), status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_delete_barber;
CREATE OR REPLACE FUNCTION rpc_delete_barber(p_admin_id UUID, p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_barber_store_id UUID;
BEGIN
  SELECT store_id INTO v_barber_store_id FROM barbers WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '理发师不存在'); END IF;
  
  PERFORM rpc_check_store_access(p_admin_id, v_barber_store_id);
  
  DELETE FROM barbers WHERE id = p_id;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==================== 服务项目 CRUD ====================

DROP FUNCTION IF EXISTS rpc_get_services;
CREATE OR REPLACE FUNCTION rpc_get_services(p_admin_id UUID, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'type', t.type, 'name', t.name, 'price', t.price,
    'discount_normal', t.discount_normal, 'discount_silver', t.discount_silver,
    'discount_gold', t.discount_gold, 'discount_diamond', t.discount_diamond,
    'store_id', t.store_id, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT sv.id, sv.type, sv.name, sv.price, sv.discount_normal, sv.discount_silver,
           sv.discount_gold, sv.discount_diamond, sv.store_id, sv.created_at, s.name AS store_name
    FROM services sv LEFT JOIN stores s ON sv.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR sv.store_id = v_actual_store_id)
    ORDER BY sv.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_create_service;
CREATE OR REPLACE FUNCTION rpc_create_service(p_admin_id UUID, p_type TEXT, p_name TEXT, p_price DECIMAL, p_discount_normal DECIMAL, p_discount_silver DECIMAL, p_discount_gold DECIMAL, p_discount_diamond DECIMAL, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  PERFORM rpc_check_store_access(p_admin_id, p_store_id);
  
  IF p_store_id IS NULL THEN
    SELECT store_id INTO p_store_id FROM admins WHERE id = p_admin_id;
  END IF;
  
  INSERT INTO services (type, name, price, discount_normal, discount_silver, discount_gold, discount_diamond, store_id)
  VALUES (
    p_type,
    p_name,
    p_price,
    p_discount_normal,
    p_discount_silver,
    p_discount_gold,
    p_discount_diamond,
    p_store_id
  )
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_update_service;
CREATE OR REPLACE FUNCTION rpc_update_service(p_admin_id UUID, p_id UUID, p_type TEXT, p_name TEXT, p_price DECIMAL, p_discount_normal DECIMAL, p_discount_silver DECIMAL, p_discount_gold DECIMAL, p_discount_diamond DECIMAL)
RETURNS JSONB AS $$
DECLARE
  v_service_store_id UUID;
  v_record RECORD;
BEGIN
  SELECT store_id INTO v_service_store_id FROM services WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '服务项目不存在'); END IF;
  
  PERFORM rpc_check_store_access(p_admin_id, v_service_store_id);
  
  UPDATE services SET
    type = COALESCE(NULLIF(p_type, ''), type),
    name = COALESCE(NULLIF(p_name, ''), name),
    price = COALESCE(p_price, price),
    discount_normal = COALESCE(p_discount_normal, discount_normal),
    discount_silver = COALESCE(p_discount_silver, discount_silver),
    discount_gold = COALESCE(p_discount_gold, discount_gold),
    discount_diamond = COALESCE(p_discount_diamond, discount_diamond)
  WHERE id = p_id
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_delete_service;
CREATE OR REPLACE FUNCTION rpc_delete_service(p_admin_id UUID, p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_service_store_id UUID;
BEGIN
  SELECT store_id INTO v_service_store_id FROM services WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '服务项目不存在'); END IF;
  
  PERFORM rpc_check_store_access(p_admin_id, v_service_store_id);
  
  DELETE FROM services WHERE id = p_id;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==================== 充值套餐 CRUD ====================

DROP FUNCTION IF EXISTS rpc_get_packages;
CREATE OR REPLACE FUNCTION rpc_get_packages(p_admin_id UUID, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'name', t.name, 'amount', t.amount,
    'bonus', t.bonus, 'status', t.status,
    'store_id', t.store_id, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT rp.id, rp.name, rp.amount, rp.bonus, rp.status, rp.store_id, rp.created_at, s.name AS store_name
    FROM recharge_packages rp LEFT JOIN stores s ON rp.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR rp.store_id = v_actual_store_id)
    ORDER BY rp.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_create_package;
CREATE OR REPLACE FUNCTION rpc_create_package(p_admin_id UUID, p_name TEXT, p_amount DECIMAL, p_bonus DECIMAL, p_status TEXT, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  PERFORM rpc_check_store_access(p_admin_id, p_store_id);
  
  IF p_store_id IS NULL THEN
    SELECT store_id INTO p_store_id FROM admins WHERE id = p_admin_id;
  END IF;
  
  INSERT INTO recharge_packages (name, amount, bonus, status, store_id)
  VALUES (p_name, p_amount, p_bonus, NULLIF(p_status, ''), p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_update_package;
CREATE OR REPLACE FUNCTION rpc_update_package(p_admin_id UUID, p_id UUID, p_name TEXT, p_amount DECIMAL, p_bonus DECIMAL, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_pkg_store_id UUID;
  v_record RECORD;
BEGIN
  SELECT store_id INTO v_pkg_store_id FROM recharge_packages WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '充值套餐不存在'); END IF;
  
  PERFORM rpc_check_store_access(p_admin_id, v_pkg_store_id);
  
  UPDATE recharge_packages SET
    name = COALESCE(NULLIF(p_name, ''), name),
    amount = COALESCE(p_amount, amount),
    bonus = COALESCE(p_bonus, bonus),
    status = COALESCE(NULLIF(p_status, ''), status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_delete_package;
CREATE OR REPLACE FUNCTION rpc_delete_package(p_admin_id UUID, p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_pkg_store_id UUID;
BEGIN
  SELECT store_id INTO v_pkg_store_id FROM recharge_packages WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '充值套餐不存在'); END IF;
  
  PERFORM rpc_check_store_access(p_admin_id, v_pkg_store_id);
  
  DELETE FROM recharge_packages WHERE id = p_id;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==================== 记录查询 ====================

DROP FUNCTION IF EXISTS rpc_get_recharge_records;
CREATE OR REPLACE FUNCTION rpc_get_recharge_records(p_admin_id UUID, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'member_id', t.member_id, 'member_name', t.member_name,
    'member_phone', t.member_phone, 'amount', t.amount, 'bonus', t.bonus,
    'package_name', t.package_name, 'store_id', t.store_id,
    'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT r.id, r.member_id, m.name AS member_name, m.phone AS member_phone,
           r.amount, r.bonus, r.package_name, r.store_id, r.created_at, s.name AS store_name
    FROM recharge_records r
    LEFT JOIN members m ON r.member_id = m.id
    LEFT JOIN stores s ON r.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR r.store_id = v_actual_store_id)
    ORDER BY r.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_get_consumption_records;
CREATE OR REPLACE FUNCTION rpc_get_consumption_records(p_admin_id UUID, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'member_id', t.member_id, 'member_name', t.member_name,
    'member_phone', t.member_phone, 'amount', t.amount, 'original_price', t.original_price,
    'discount', t.discount, 'service_name', t.service_name,
    'barber_name', t.barber_name, 'points_earned', t.points_earned,
    'store_id', t.store_id, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT c.id, c.member_id, m.name AS member_name, m.phone AS member_phone,
           c.amount, c.original_price, c.discount, c.service_name,
           c.barber_name, c.points_earned, c.store_id, c.created_at, s.name AS store_name
    FROM consumption_records c
    LEFT JOIN members m ON c.member_id = m.id
    LEFT JOIN stores s ON c.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR c.store_id = v_actual_store_id)
    ORDER BY c.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_get_appointments;
CREATE OR REPLACE FUNCTION rpc_get_appointments(p_admin_id UUID, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'member_id', t.member_id, 'member_name', t.member_name,
    'member_phone', t.member_phone, 'barber_id', t.barber_id, 'barber_name', t.barber_name,
    'service_id', t.service_id, 'service_name', t.service_name,
    'appointment_time', t.appointment_time, 'status', t.status,
    'store_id', t.store_id, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT a.id, a.member_id, m.name AS member_name, m.phone AS member_phone,
           a.barber_id, b.name AS barber_name, a.service_id, sv.name AS service_name,
           a.appointment_time, a.status, a.store_id, a.created_at, s.name AS store_name
    FROM appointments a
    LEFT JOIN members m ON a.member_id = m.id
    LEFT JOIN barbers b ON a.barber_id = b.id
    LEFT JOIN services sv ON a.service_id = sv.id
    LEFT JOIN stores s ON a.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR a.store_id = v_actual_store_id)
    ORDER BY a.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==================== 充值/消费/预约 操作 ====================

DROP FUNCTION IF EXISTS rpc_recharge;
CREATE OR REPLACE FUNCTION rpc_recharge(p_admin_id UUID, p_member_id UUID, p_package_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
  v_pkg RECORD;
  v_new_balance DECIMAL;
  v_record RECORD;
BEGIN
  PERFORM rpc_check_admin(p_admin_id);
  
  SELECT * INTO v_member FROM members WHERE id = p_member_id AND status = 'active' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在或已冻结'); END IF;
  
  PERFORM rpc_check_store_access(p_admin_id, v_member.store_id);
  
  SELECT * INTO v_pkg FROM recharge_packages WHERE id = p_package_id AND status = 'active';
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '充值套餐不存在或已下架'); END IF;
  IF v_pkg.store_id != v_member.store_id THEN RETURN jsonb_build_object('error', '套餐不适用于此门店'); END IF;
  
  v_new_balance := v_member.balance + v_pkg.amount + v_pkg.bonus;
  UPDATE members SET balance = v_new_balance WHERE id = p_member_id;
  
  INSERT INTO recharge_records (member_id, amount, bonus, package_name, store_id)
  VALUES (p_member_id, v_pkg.amount, v_pkg.bonus, v_pkg.name, v_member.store_id)
  RETURNING * INTO v_record;
  
  RETURN jsonb_build_object('data', jsonb_build_object(
    'record_id', v_record.id, 'new_balance', v_new_balance,
    'recharge_amount', v_pkg.amount, 'bonus', v_pkg.bonus
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_custom_recharge;
CREATE OR REPLACE FUNCTION rpc_custom_recharge(p_admin_id UUID, p_member_id UUID, p_amount DECIMAL, p_bonus DECIMAL)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
  v_new_balance DECIMAL;
  v_record RECORD;
BEGIN
  PERFORM rpc_check_admin(p_admin_id);
  
  IF p_amount <= 0 THEN RETURN jsonb_build_object('error', '充值金额必须大于0'); END IF;
  
  SELECT * INTO v_member FROM members WHERE id = p_member_id AND status = 'active' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在或已冻结'); END IF;
  
  PERFORM rpc_check_store_access(p_admin_id, v_member.store_id);
  
  v_new_balance := v_member.balance + p_amount + p_bonus;
  UPDATE members SET balance = v_new_balance WHERE id = p_member_id;
  
  INSERT INTO recharge_records (member_id, amount, bonus, package_name, store_id)
  VALUES (p_member_id, p_amount, p_bonus, '自定义充值', v_member.store_id)
  RETURNING * INTO v_record;
  
  RETURN jsonb_build_object('data', jsonb_build_object(
    'record_id', v_record.id, 'new_balance', v_new_balance,
    'recharge_amount', p_amount, 'bonus', p_bonus
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_consume;
CREATE OR REPLACE FUNCTION rpc_consume(p_admin_id UUID, p_member_id UUID, p_service_id UUID, p_barber_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
  v_service RECORD;
  v_barber_name VARCHAR;
  v_discount DECIMAL;
  v_amount DECIMAL;
  v_points INT;
  v_new_balance DECIMAL;
  v_new_points INT;
BEGIN
  PERFORM rpc_check_admin(p_admin_id);
  
  SELECT * INTO v_member FROM members WHERE id = p_member_id AND status = 'active' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在或已冻结'); END IF;
  
  PERFORM rpc_check_store_access(p_admin_id, v_member.store_id);
  
  SELECT * INTO v_service FROM services WHERE id = p_service_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '服务项目不存在'); END IF;
  
  v_discount := CASE v_member.level
    WHEN 'normal' THEN v_service.discount_normal
    WHEN 'silver' THEN v_service.discount_silver
    WHEN 'gold' THEN v_service.discount_gold
    WHEN 'diamond' THEN v_service.discount_diamond
    ELSE 1.00
  END;
  v_amount := ROUND(v_service.price * v_discount, 2);
  
  IF v_member.balance < v_amount THEN
    RETURN jsonb_build_object('error', '余额不足', 'current_balance', v_member.balance, 'required', v_amount);
  END IF;
  
  IF p_barber_id IS NOT NULL THEN
    SELECT name INTO v_barber_name FROM barbers WHERE id = p_barber_id;
  END IF;
  
  v_points := FLOOR(v_amount)::INT;
  v_new_balance := v_member.balance - v_amount;
  v_new_points := v_member.points + v_points;
  
  UPDATE members SET balance = v_new_balance, points = v_new_points WHERE id = p_member_id;
  
  INSERT INTO consumption_records (member_id, amount, original_price, discount, service_id, service_name, barber_id, barber_name, points_earned, store_id)
  VALUES (p_member_id, v_amount, v_service.price, v_discount, p_service_id, v_service.name, p_barber_id, v_barber_name, v_points, v_member.store_id);
  
  UPDATE members SET level = CASE
    WHEN v_new_points >= 5000 THEN 'diamond'
    WHEN v_new_points >= 2000 THEN 'gold'
    WHEN v_new_points >= 500 THEN 'silver'
    ELSE 'normal'
  END WHERE id = p_member_id;
  
  RETURN jsonb_build_object('data', jsonb_build_object(
    'new_balance', v_new_balance, 'amount', v_amount,
    'original_price', v_service.price, 'discount', v_discount,
    'points_earned', v_points, 'total_points', v_new_points
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_create_appointment;
CREATE OR REPLACE FUNCTION rpc_create_appointment(p_admin_id UUID, p_member_id UUID, p_barber_id UUID, p_service_id UUID, p_appointment_time TIMESTAMPTZ)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
  v_appointment RECORD;
BEGIN
  PERFORM rpc_check_admin(p_admin_id);
  
  SELECT * INTO v_member FROM members WHERE id = p_member_id AND status = 'active';
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在'); END IF;
  
  PERFORM rpc_check_store_access(p_admin_id, v_member.store_id);
  
  IF p_appointment_time < NOW() THEN RETURN jsonb_build_object('error', '预约时间不能是过去'); END IF;
  
  INSERT INTO appointments (member_id, barber_id, service_id, appointment_time, status, store_id)
  VALUES (p_member_id, p_barber_id, p_service_id, p_appointment_time, 'pending', v_member.store_id)
  RETURNING * INTO v_appointment;
  
  RETURN jsonb_build_object('data', to_jsonb(v_appointment));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_confirm_appointment;
CREATE OR REPLACE FUNCTION rpc_confirm_appointment(p_admin_id UUID, p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_appt_store_id UUID;
BEGIN
  SELECT store_id INTO v_appt_store_id FROM appointments WHERE id = p_id AND status = 'pending';
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '预约不存在或状态不允许确认'); END IF;
  
  PERFORM rpc_check_store_access(p_admin_id, v_appt_store_id);
  
  UPDATE appointments SET status = 'confirmed', updated_at = now() WHERE id = p_id;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id, 'status', 'confirmed'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_cancel_appointment;
CREATE OR REPLACE FUNCTION rpc_cancel_appointment(p_admin_id UUID, p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_appt_store_id UUID;
BEGIN
  SELECT store_id INTO v_appt_store_id FROM appointments WHERE id = p_id AND status IN ('pending', 'confirmed');
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '预约不存在或状态不允许取消'); END IF;
  
  PERFORM rpc_check_store_access(p_admin_id, v_appt_store_id);
  
  UPDATE appointments SET status = 'cancelled', updated_at = now() WHERE id = p_id;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id, 'status', 'cancelled'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_complete_appointment;
CREATE OR REPLACE FUNCTION rpc_complete_appointment(p_admin_id UUID, p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_appt RECORD;
  v_result JSONB;
BEGIN
  SELECT * INTO v_appt FROM appointments WHERE id = p_id AND status = 'confirmed';
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '预约不存在或状态不允许完成'); END IF;
  
  PERFORM rpc_check_store_access(p_admin_id, v_appt.store_id);
  
  UPDATE appointments SET status = 'completed', updated_at = now() WHERE id = p_id;
  v_result := rpc_consume(p_admin_id, v_appt.member_id, v_appt.service_id, v_appt.barber_id);
  
  RETURN jsonb_build_object('data', jsonb_build_object(
    'id', p_id, 'status', 'completed', 'consumption', v_result
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==================== 统计函数 ====================

DROP FUNCTION IF EXISTS rpc_revenue_stats;
CREATE OR REPLACE FUNCTION rpc_revenue_stats(p_admin_id UUID, p_store_id UUID, p_start_date DATE, p_end_date DATE, p_dimension TEXT)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB := '[]'::JSONB;
  v_start DATE;
  v_end DATE;
BEGIN
  PERFORM rpc_check_admin(p_admin_id);
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  
  v_start := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
  v_end := COALESCE(p_end_date, CURRENT_DATE);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object('period', d::text, 'total_amount', COALESCE(s.total, 0))),'[]'::JSONB)
  INTO v_result
  FROM generate_series(v_start, v_end, INTERVAL '1 day') d
  LEFT JOIN (
    SELECT DATE(created_at) AS dt, SUM(amount) AS total
    FROM consumption_records
    WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
      AND created_at >= v_start AND created_at < v_end + INTERVAL '1 day'
    GROUP BY DATE(created_at)
  ) s ON d = s.dt;
  
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_member_growth_stats;
CREATE OR REPLACE FUNCTION rpc_member_growth_stats(p_admin_id UUID, p_store_id UUID, p_start_date DATE, p_end_date DATE, p_dimension TEXT)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB := '[]'::JSONB;
  v_start DATE;
  v_end DATE;
BEGIN
  PERFORM rpc_check_admin(p_admin_id);
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  
  v_start := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
  v_end := COALESCE(p_end_date, CURRENT_DATE);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object('period', d::text, 'count', COALESCE(s.cnt, 0))),'[]'::JSONB)
  INTO v_result
  FROM generate_series(v_start, v_end, INTERVAL '1 day') d
  LEFT JOIN (
    SELECT DATE(created_at) AS dt, COUNT(*) AS cnt
    FROM members
    WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
      AND created_at >= v_start AND created_at < v_end + INTERVAL '1 day'
      AND status = 'active'
    GROUP BY DATE(created_at)
  ) s ON d = s.dt;
  
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_hot_services_stats;
CREATE OR REPLACE FUNCTION rpc_hot_services_stats(p_admin_id UUID, p_store_id UUID, p_start_date DATE, p_end_date DATE)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  PERFORM rpc_check_admin(p_admin_id);
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object('service_name', service_name, 'count', cnt)),'[]'::JSONB)
  INTO v_result
  FROM (
    SELECT service_name, COUNT(*) AS cnt
    FROM consumption_records
    WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
      AND (p_start_date IS NULL OR created_at >= p_start_date)
      AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day')
    GROUP BY service_name ORDER BY cnt DESC LIMIT 10
  ) sub;
  
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_finance_summary;
CREATE OR REPLACE FUNCTION rpc_finance_summary(p_admin_id UUID, p_store_id UUID, p_start_date DATE, p_end_date DATE)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_recharge DECIMAL;
  v_consumption DECIMAL;
BEGIN
  PERFORM rpc_check_admin(p_admin_id);
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  
  SELECT COALESCE(SUM(amount + bonus), 0) INTO v_recharge FROM recharge_records
  WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day');
  
  SELECT COALESCE(SUM(amount), 0) INTO v_consumption FROM consumption_records
  WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day');
  
  RETURN jsonb_build_object('data', jsonb_build_object(
    'recharge_income', v_recharge,
    'consumption_income', v_consumption,
    'net_income', v_consumption
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_daily_statements;
CREATE OR REPLACE FUNCTION rpc_daily_statements(p_admin_id UUID, p_store_id UUID, p_start_date DATE, p_end_date DATE)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  PERFORM rpc_check_admin(p_admin_id);
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'date', d.dt,
    'recharge_count', COALESCE(r.cnt, 0),
    'recharge_amount', COALESCE(r.total, 0),
    'consumption_count', COALESCE(c.cnt, 0),
    'consumption_amount', COALESCE(c.total, 0)
  )),'[]'::JSONB)
  INTO v_result
  FROM generate_series(
    COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days'),
    COALESCE(p_end_date, CURRENT_DATE),
    INTERVAL '1 day'
  ) d(dt)
  LEFT JOIN (
    SELECT DATE(created_at) AS dt, COUNT(*) AS cnt, SUM(amount + bonus) AS total
    FROM recharge_records WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
    GROUP BY DATE(created_at)
  ) r ON d.dt = r.dt
  LEFT JOIN (
    SELECT DATE(created_at) AS dt, COUNT(*) AS cnt, SUM(amount) AS total
    FROM consumption_records WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
    GROUP BY DATE(created_at)
  ) c ON d.dt = c.dt;
  
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==================== 服务类型 RPC ====================

DROP FUNCTION IF EXISTS rpc_get_service_types;
CREATE OR REPLACE FUNCTION rpc_get_service_types(p_admin_id UUID, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'name', t.name, 'store_id', t.store_id, 'is_global', t.is_global, 'created_at', t.created_at
  ) ORDER BY t.is_global DESC, t.name), '[]'::jsonb) INTO v_result
  FROM (
    SELECT st.id, st.name, st.store_id, st.created_at,
           CASE WHEN st.store_id IS NULL THEN true ELSE false END AS is_global
    FROM service_types st
    WHERE (v_actual_store_id IS NULL OR st.store_id IS NULL OR st.store_id = v_actual_store_id)
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_create_service_type;
CREATE OR REPLACE FUNCTION rpc_create_service_type(p_admin_id UUID, p_name TEXT, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_role TEXT;
  v_admin_store_id UUID;
  v_record RECORD;
BEGIN
  SELECT role, store_id INTO v_role, v_admin_store_id FROM admins WHERE id = p_admin_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '无效的管理员身份'); END IF;
  
  -- 超管可创建全局类型（store_id=NULL），店长只能创建本店类型
  IF p_store_id IS NULL THEN
    IF v_role != 'super_admin' THEN
      p_store_id := v_admin_store_id;
    END IF;
  END IF;
  
  IF p_store_id IS NOT NULL THEN
    PERFORM rpc_check_store_access(p_admin_id, p_store_id);
  END IF;
  
  INSERT INTO service_types (name, store_id)
  VALUES (p_name, p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_delete_service_type;
CREATE OR REPLACE FUNCTION rpc_delete_service_type(p_admin_id UUID, p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin_role TEXT;
  v_admin_store_id UUID;
  v_type_store_id UUID;
BEGIN
  SELECT role, store_id INTO v_admin_role, v_admin_store_id FROM admins WHERE id = p_admin_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '无效的管理员身份'); END IF;

  SELECT store_id INTO v_type_store_id FROM service_types WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '服务类型不存在'); END IF;

  -- 超管可删全局+本店，店长只能删本店
  IF v_admin_role = 'store_admin' THEN
    IF v_type_store_id IS NULL THEN
      RETURN jsonb_build_object('error', '店长不能删除全局服务类型');
    END IF;
    IF v_type_store_id != v_admin_store_id THEN
      RETURN jsonb_build_object('error', '无权删除此服务类型');
    END IF;
  END IF;

  DELETE FROM service_types WHERE id = p_id;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;




-- ==================== 门店查询（补漏：fix_rpc_security 原本遗漏） ====================
DROP FUNCTION IF EXISTS rpc_get_stores;
CREATE OR REPLACE FUNCTION rpc_get_stores(p_admin_id UUID, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);

  IF v_actual_store_id IS NOT NULL THEN
    SELECT to_jsonb(s) INTO v_result FROM stores s WHERE id = v_actual_store_id;
    RETURN jsonb_build_object('data', v_result);
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO v_result
  FROM (SELECT * FROM stores ORDER BY created_at DESC) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================
-- 完成
-- =============================================
SELECT '✅ RPC 权限安全加固完成！所有函数已添加管理员身份校验和门店隔离。' AS result;



