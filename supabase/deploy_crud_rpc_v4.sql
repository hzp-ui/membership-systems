-- =============================================
-- 部署脚本 v4：重新部署所有 CRUD RPC 函数
-- 先 DROP 所有可能存在的旧签名，然后 CREATE 新函数
-- 执行方式：复制到 Supabase Dashboard > SQL Editor 执行
-- =============================================

-- ==================== 辅助函数 ====================
-- 先 DROP 可能已存在的函数（忽略错误）
DROP FUNCTION IF EXISTS rpc_get_current_admin() CASCADE;
DROP FUNCTION IF EXISTS rpc_get_current_member() CASCADE;
DROP FUNCTION IF EXISTS rpc_check_store_access_v2(UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_enforce_store_filter_v2() CASCADE;
DROP FUNCTION IF EXISTS rpc_get_current_admin_info() CASCADE;
DROP FUNCTION IF EXISTS rpc_get_current_member_info() CASCADE;

-- ==================== 门店 CRUD ====================
DROP FUNCTION IF EXISTS rpc_get_stores(UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_create_store(TEXT, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS rpc_update_store(UUID, TEXT, TEXT, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS rpc_delete_store(UUID) CASCADE;

-- ==================== 管理员 CRUD ====================
DROP FUNCTION IF EXISTS rpc_get_admins(UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_create_admin(TEXT, TEXT, TEXT, TEXT, TEXT, UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_update_admin(UUID, TEXT, TEXT, TEXT, UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS rpc_delete_admin(UUID) CASCADE;

-- ==================== 会员 CRUD ====================
DROP FUNCTION IF EXISTS rpc_get_members(UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_create_member(TEXT, TEXT, TEXT, BIGINT, DECIMAL) CASCADE;
DROP FUNCTION IF EXISTS rpc_update_member(UUID, TEXT, TEXT, TEXT, BIGINT, DECIMAL, TEXT) CASCADE;
DROP FUNCTION IF EXISTS rpc_delete_member(UUID) CASCADE;

-- ==================== 理发师 CRUD ====================
DROP FUNCTION IF EXISTS rpc_get_barbers(UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_create_barber(TEXT, TEXT, JSONB, UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_update_barber(UUID, TEXT, TEXT, JSONB, TEXT) CASCADE;
DROP FUNCTION IF EXISTS rpc_delete_barber(UUID) CASCADE;

-- ==================== 服务项目 CRUD ====================
DROP FUNCTION IF EXISTS rpc_get_services(UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_create_service(TEXT, TEXT, DECIMAL, DECIMAL, DECIMAL, DECIMAL, DECIMAL, UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_update_service(UUID, TEXT, TEXT, DECIMAL, DECIMAL, DECIMAL, DECIMAL, DECIMAL) CASCADE;
DROP FUNCTION IF EXISTS rpc_delete_service(UUID) CASCADE;

-- ==================== 服务类型 CRUD ====================
DROP FUNCTION IF EXISTS rpc_get_service_types(UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_create_service_type(TEXT, UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_delete_service_type(UUID) CASCADE;

-- ==================== 充值套餐 CRUD ====================
DROP FUNCTION IF EXISTS rpc_get_packages(UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_create_package(TEXT, DECIMAL, DECIMAL, TEXT, UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_update_package(UUID, TEXT, DECIMAL, DECIMAL, TEXT) CASCADE;
DROP FUNCTION IF EXISTS rpc_delete_package(UUID) CASCADE;

-- ==================== 充值记录 ====================
DROP FUNCTION IF EXISTS rpc_create_recharge_record(UUID, DECIMAL, DECIMAL, TEXT) CASCADE;
DROP FUNCTION IF EXISTS rpc_get_recharge_records(UUID) CASCADE;

-- ==================== 消费记录 ====================
DROP FUNCTION IF EXISTS rpc_create_consume_record(UUID, DECIMAL, DECIMAL, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS rpc_get_consume_records(UUID) CASCADE;

-- ==================== 预约记录 ====================
DROP FUNCTION IF EXISTS rpc_create_appointment(UUID, UUID, UUID, TIMESTAMPTZ) CASCADE;
DROP FUNCTION IF EXISTS rpc_confirm_appointment(UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_cancel_appointment(UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_complete_appointment(UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_get_appointments(UUID) CASCADE;

-- ==================== 统计 ====================
DROP FUNCTION IF EXISTS rpc_revenue_stats(UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_member_growth_stats(UUID) CASCADE;
DROP FUNCTION IF EXISTS rpc_hot_services_stats(UUID) CASCADE;

-- =============================================
-- 现在创建所有正确的函数（从 crud_rpc_v3.sql）
-- =============================================

-- ==================== 门店 CRUD ====================

CREATE OR REPLACE FUNCTION rpc_get_stores(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  IF p_store_id IS NOT NULL THEN
    SELECT to_jsonb(s) INTO v_result FROM stores s WHERE id = p_store_id;
    RETURN jsonb_build_object('data', v_result);
  END IF;
  SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO v_result
  FROM (SELECT * FROM stores ORDER BY created_at DESC) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_create_store(p_name TEXT, p_address TEXT, p_phone TEXT, p_manager TEXT)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  INSERT INTO stores (name, address, phone, manager)
  VALUES (p_name, NULLIF(p_address, ''), NULLIF(p_phone, ''), NULLIF(p_manager, ''))
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_store(p_id UUID, p_name TEXT, p_address TEXT, p_phone TEXT, p_manager TEXT, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE stores SET
    name = COALESCE(NULLIF(p_name, ''), name),
    address = COALESCE(NULLIF(p_address, ''), address),
    phone = COALESCE(NULLIF(p_phone, ''), phone),
    manager = COALESCE(NULLIF(p_manager, ''), manager),
    status = COALESCE(NULLIF(p_status, '')::store_status, status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '门店不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_delete_store(p_id UUID)
RETURNS JSONB AS $$
BEGIN
  DELETE FROM stores WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '门店不存在'); END IF;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 管理员 CRUD ====================

CREATE OR REPLACE FUNCTION rpc_get_admins(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'username', t.username, 'name', t.name,
    'phone', t.phone, 'role', t.role, 'store_id', t.store_id,
    'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT a.id, a.username, a.name, a.phone, a.role, a.store_id, a.created_at, s.name AS store_name
    FROM admins a LEFT JOIN stores s ON a.store_id = s.id
    WHERE (p_store_id IS NULL OR a.store_id = p_store_id)
    ORDER BY a.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_create_admin(p_username TEXT, p_password TEXT, p_name TEXT, p_phone TEXT, p_role TEXT, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  IF p_role = 'store_admin' AND p_store_id IS NULL THEN
    RETURN jsonb_build_object('error', '店长必须绑定门店');
  END IF;
  INSERT INTO admins (username, password_hash, name, phone, role, store_id)
  VALUES (
    p_username,
    crypt(p_password, gen_salt('bf', 10)),
    p_name,
    NULLIF(p_phone, ''),
    NULLIF(p_role, '')::admin_role,
    p_store_id
  )
  RETURNING id, username, name, phone, role, store_id, created_at INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_admin(p_id UUID, p_name TEXT, p_phone TEXT, p_role TEXT, p_store_id UUID, p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  IF p_password IS NOT NULL AND p_password != '' THEN
    UPDATE admins SET
      name = COALESCE(NULLIF(p_name, ''), name),
      phone = COALESCE(NULLIF(p_phone, ''), phone),
      role = COALESCE(NULLIF(p_role, '')::admin_role, role),
      store_id = COALESCE(p_store_id, store_id),
      password_hash = crypt(p_password, gen_salt('bf', 10))
    WHERE id = p_id
    RETURNING id, username, name, phone, role, store_id, created_at INTO v_record;
  ELSE
    UPDATE admins SET
      name = COALESCE(NULLIF(p_name, ''), name),
      phone = COALESCE(NULLIF(p_phone, ''), phone),
      role = COALESCE(NULLIF(p_role, '')::admin_role, role),
      store_id = COALESCE(p_store_id, store_id)
    WHERE id = p_id
    RETURNING id, username, name, phone, role, store_id, created_at INTO v_record;
  END IF;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '管理员不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_delete_admin(p_id UUID)
RETURNS JSONB AS $$
BEGIN
  DELETE FROM admins WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '管理员不存在'); END IF;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 会员 CRUD ====================

CREATE OR REPLACE FUNCTION rpc_get_members(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'phone', t.phone, 'name', t.name, 'level', t.level,
    'points', t.points, 'balance', t.balance, 'store_id', t.store_id,
    'status', t.status, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT m.id, m.phone, m.name, m.level, m.points, m.balance, m.store_id,
           m.status, m.created_at, s.name AS store_name
    FROM members m LEFT JOIN stores s ON m.store_id = s.id
    WHERE (p_store_id IS NULL OR m.store_id = p_store_id)
    ORDER BY m.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_create_member(p_phone TEXT, p_name TEXT, p_store_id UUID, p_level TEXT)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  INSERT INTO members (phone, name, store_id, level)
  VALUES (
    p_phone,
    NULLIF(p_name, ''),
    p_store_id,
    NULLIF(p_level, '')::member_level
  )
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_member(p_id UUID, p_name TEXT, p_phone TEXT, p_level TEXT, p_points BIGINT, p_balance DECIMAL, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE members SET
    name = COALESCE(NULLIF(p_name, ''), name),
    phone = COALESCE(NULLIF(p_phone, ''), phone),
    level = COALESCE(NULLIF(p_level, '')::member_level, level),
    points = COALESCE(p_points, points),
    balance = COALESCE(p_balance, balance),
    status = COALESCE(NULLIF(p_status, '')::member_status, status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_delete_member(p_id UUID)
RETURNS JSONB AS $$
BEGIN
  DELETE FROM members WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在'); END IF;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 理发师 CRUD ====================

CREATE OR REPLACE FUNCTION rpc_get_barbers(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'name', t.name, 'phone', t.phone,
    'specialties', t.specialties, 'status', t.status,
    'store_id', t.store_id, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT b.id, b.name, b.phone, b.specialties, b.status, b.store_id, b.created_at, s.name AS store_name
    FROM barbers b LEFT JOIN stores s ON b.store_id = s.id
    WHERE (p_store_id IS NULL OR b.store_id = p_store_id)
    ORDER BY b.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_create_barber(p_name TEXT, p_phone TEXT, p_specialties JSONB, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  INSERT INTO barbers (name, phone, specialties, store_id)
  VALUES (p_name, NULLIF(p_phone, ''), p_specialties::text[], p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_barber(p_id UUID, p_name TEXT, p_phone TEXT, p_specialties JSONB, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE barbers SET
    name = COALESCE(NULLIF(p_name, ''), name),
    phone = COALESCE(NULLIF(p_phone, ''), phone),
    specialties = COALESCE(p_specialties::text[], specialties),
    status = COALESCE(NULLIF(p_status, '')::barber_status, status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '理发师不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_delete_barber(p_id UUID)
RETURNS JSONB AS $$
BEGIN
  DELETE FROM barbers WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '理发师不存在'); END IF;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 服务项目 CRUD ====================

CREATE OR REPLACE FUNCTION rpc_get_services(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
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
    WHERE (p_store_id IS NULL OR sv.store_id = p_store_id)
    ORDER BY sv.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_create_service(p_type TEXT, p_name TEXT, p_price DECIMAL, p_discount_normal DECIMAL, p_discount_silver DECIMAL, p_discount_gold DECIMAL, p_discount_diamond DECIMAL, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  INSERT INTO services (type, name, price, discount_normal, discount_silver, discount_gold, discount_diamond, store_id)
  VALUES (
    p_type::service_type,
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

CREATE OR REPLACE FUNCTION rpc_update_service(p_id UUID, p_type TEXT, p_name TEXT, p_price DECIMAL, p_discount_normal DECIMAL, p_discount_silver DECIMAL, p_discount_gold DECIMAL, p_discount_diamond DECIMAL)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE services SET
    type = COALESCE(NULLIF(p_type, '')::service_type, type),
    name = COALESCE(NULLIF(p_name, ''), name),
    price = COALESCE(p_price, price),
    discount_normal = COALESCE(p_discount_normal, discount_normal),
    discount_silver = COALESCE(p_discount_silver, discount_silver),
    discount_gold = COALESCE(p_discount_gold, discount_gold),
    discount_diamond = COALESCE(p_discount_diamond, discount_diamond)
  WHERE id = p_id
  RETURNING * INTO v_record;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '服务项目不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_delete_service(p_id UUID)
RETURNS JSONB AS $$
BEGIN
  DELETE FROM services WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '服务项目不存在'); END IF;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 服务类型 CRUD ====================

CREATE OR REPLACE FUNCTION rpc_get_service_types(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'name', t.name, 'store_id', t.store_id,
    'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT st.id, st.name, st.store_id, st.created_at, s.name AS store_name
    FROM service_types st
    LEFT JOIN stores s ON st.store_id = s.id
    WHERE (p_store_id IS NULL OR st.store_id IS NULL OR st.store_id = p_store_id)
    ORDER BY st.name
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_create_service_type(p_name TEXT, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  INSERT INTO service_types (name, store_id)
  VALUES (p_name, p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_delete_service_type(p_id UUID)
RETURNS JSONB AS $$
BEGIN
  DELETE FROM service_types WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '服务类型不存在'); END IF;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 充值套餐 CRUD ====================

CREATE OR REPLACE FUNCTION rpc_get_packages(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'name', t.name, 'amount', t.amount,
    'bonus', t.bonus, 'status', t.status,
    'store_id', t.store_id, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT rp.id, rp.name, rp.amount, rp.bonus, rp.status, rp.store_id, rp.created_at, s.name AS store_name
    FROM recharge_packages rp LEFT JOIN stores s ON rp.store_id = s.id
    WHERE (p_store_id IS NULL OR rp.store_id = p_store_id)
    ORDER BY rp.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_create_package(p_name TEXT, p_amount DECIMAL, p_bonus DECIMAL, p_status TEXT, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  INSERT INTO recharge_packages (name, amount, bonus, status, store_id)
  VALUES (p_name, p_amount, p_bonus, NULLIF(p_status, '')::package_status, p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_package(p_id UUID, p_name TEXT, p_amount DECIMAL, p_bonus DECIMAL, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE recharge_packages SET
    name = COALESCE(NULLIF(p_name, ''), name),
    amount = COALESCE(p_amount, amount),
    bonus = COALESCE(p_bonus, bonus),
    status = COALESCE(NULLIF(p_status, '')::package_status, status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '充值套餐不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_delete_package(p_id UUID)
RETURNS JSONB AS $$
BEGIN
  DELETE FROM recharge_packages WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '充值套餐不存在'); END IF;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 充值记录 ====================

CREATE OR REPLACE FUNCTION rpc_create_recharge_record(p_member_id UUID, p_amount DECIMAL, p_bonus DECIMAL, p_package_name TEXT)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  INSERT INTO recharge_records (member_id, amount, bonus, package_name)
  VALUES (p_member_id, p_amount, p_bonus, NULLIF(p_package_name, ''))
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_get_recharge_records(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
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
    WHERE (p_store_id IS NULL OR r.store_id = p_store_id)
    ORDER BY r.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 消费记录 ====================

CREATE OR REPLACE FUNCTION rpc_create_consume_record(p_member_id UUID, p_amount DECIMAL, p_original_price DECIMAL, p_service_name TEXT, p_barber_name TEXT, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  INSERT INTO consumption_records (member_id, amount, original_price, service_name, barber_name, store_id)
  VALUES (p_member_id, p_amount, p_original_price, p_service_name, NULLIF(p_barber_name, ''), p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_get_consume_records(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
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
    WHERE (p_store_id IS NULL OR c.store_id = p_store_id)
    ORDER BY c.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 预约 ====================

CREATE OR REPLACE FUNCTION rpc_create_appointment(p_member_id UUID, p_barber_id UUID, p_service_id UUID, p_appointment_time TIMESTAMPTZ)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  INSERT INTO appointments (member_id, barber_id, service_id, appointment_time)
  VALUES (p_member_id, p_barber_id, p_service_id, p_appointment_time)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_confirm_appointment(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE appointments SET status = 'confirmed' WHERE id = p_id AND status = 'pending'
  RETURNING * INTO v_record;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '预约不存在或已确认'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_cancel_appointment(p_id UUID)
RETURNS JSONB AS $$
BEGIN
  DELETE FROM appointments WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '预约不存在'); END IF;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_complete_appointment(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE appointments SET status = 'completed' WHERE id = p_id AND status = 'confirmed'
  RETURNING * INTO v_record;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '预约不存在或未确认'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_get_appointments(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
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
    WHERE (p_store_id IS NULL OR a.store_id = p_store_id)
    ORDER BY a.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 统计 ====================

CREATE OR REPLACE FUNCTION rpc_revenue_stats(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO v_result
  FROM (
    SELECT 
      DATE_TRUNC('day', created_at) AS date,
      SUM(amount) AS revenue,
      COUNT(*) AS count
    FROM consumption_records
    WHERE (p_store_id IS NULL OR store_id = p_store_id)
      AND created_at >= DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY DATE_TRUNC('day', created_at)
    ORDER BY date DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_member_growth_stats(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO v_result
  FROM (
    SELECT 
      DATE_TRUNC('day', created_at) AS date,
      COUNT(*) AS new_members
    FROM members
    WHERE (p_store_id IS NULL OR store_id = p_store_id)
      AND created_at >= DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY DATE_TRUNC('day', created_at)
    ORDER BY date DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_hot_services_stats(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'service_name', t.service_name,
    'count', t.count,
    'revenue', t.revenue
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT 
      service_name,
      COUNT(*) AS count,
      SUM(amount) AS revenue
    FROM consumption_records
    WHERE (p_store_id IS NULL OR store_id = p_store_id)
      AND created_at >= DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY service_name
    ORDER BY count DESC
    LIMIT 10
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 辅助函数（放在最后，因为其他函数依赖它们）====================

CREATE OR REPLACE FUNCTION rpc_get_current_admin()
RETURNS JSONB AS $$
DECLARE
  v_admin_id UUID;
  v_result JSONB;
BEGIN
  SELECT id INTO v_admin_id FROM admins WHERE auth_user_id = auth.uid();
  IF v_admin_id IS NULL THEN
    RETURN jsonb_build_object('error', '未认证');
  END IF;
  SELECT to_jsonb(t) INTO v_result
  FROM (
    SELECT a.*, s.name AS store_name
    FROM admins a
    LEFT JOIN stores s ON a.store_id = s.id
    WHERE a.id = v_admin_id
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_get_current_member()
RETURNS JSONB AS $$
DECLARE
  v_member_id UUID;
  v_result JSONB;
BEGIN
  SELECT id INTO v_member_id FROM members WHERE auth_user_id = auth.uid();
  IF v_member_id IS NULL THEN
    RETURN jsonb_build_object('error', '未认证');
  END IF;
  SELECT to_jsonb(t) INTO v_result
  FROM (
    SELECT m.*, s.name AS store_name
    FROM members m
    LEFT JOIN stores s ON m.store_id = s.id
    WHERE m.id = v_member_id
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_check_store_access_v2(p_requested_store_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_admin_role TEXT;
  v_admin_store_id UUID;
BEGIN
  SELECT role, store_id INTO v_admin_role, v_admin_store_id
  FROM admins WHERE auth_user_id = auth.uid();
  IF v_admin_role = 'super_admin' THEN RETURN TRUE; END IF;
  RETURN v_admin_store_id = p_requested_store_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_enforce_store_filter_v2()
RETURNS UUID AS $$
DECLARE
  v_admin_role TEXT;
  v_admin_store_id UUID;
BEGIN
  SELECT role, store_id INTO v_admin_role, v_admin_store_id
  FROM admins WHERE auth_user_id = auth.uid();
  IF v_admin_role = 'super_admin' THEN RETURN NULL; END IF;
  RETURN v_admin_store_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_get_current_admin_info()
RETURNS JSONB AS $$
DECLARE
  v_auth_user_id UUID;
  v_result JSONB;
BEGIN
  v_auth_user_id := auth.uid();
  IF v_auth_user_id IS NULL THEN
    RETURN jsonb_build_object('error', '未认证');
  END IF;
  SELECT to_jsonb(t) INTO v_result
  FROM (
    SELECT a.id, a.username, a.name, a.phone, a.role, a.store_id, a.created_at,
           s.name AS store_name
    FROM admins a
    LEFT JOIN stores s ON a.store_id = s.id
    WHERE a.auth_user_id = v_auth_user_id
  ) t;
  IF v_result IS NULL THEN
    RETURN jsonb_build_object('error', '管理员不存在');
  END IF;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_get_current_member_info()
RETURNS JSONB AS $$
DECLARE
  v_auth_user_id UUID;
  v_result JSONB;
BEGIN
  v_auth_user_id := auth.uid();
  IF v_auth_user_id IS NULL THEN
    RETURN jsonb_build_object('error', '未认证');
  END IF;
  SELECT to_jsonb(t) INTO v_result
  FROM (
    SELECT m.id, m.phone, m.name, m.level, m.points, m.balance, m.store_id, m.status, m.created_at,
           s.name AS store_name
    FROM members m
    LEFT JOIN stores s ON m.store_id = s.id
    WHERE m.auth_user_id = v_auth_user_id
  ) t;
  IF v_result IS NULL THEN
    RETURN jsonb_build_object('error', '会员不存在');
  END IF;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT '✅ RPC 函数 v4 部署完成（所有函数已重新创建）' AS result;
