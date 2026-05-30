-- =============================================
-- CRUD RPC 函数（完整版 v3）
-- 修复：所有带 JOIN 的查询用子查询包装，避免 GROUP BY 冲突
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

-- ==================== 充值记录查询 ====================

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

-- ==================== 消费记录查询 ====================

CREATE OR REPLACE FUNCTION rpc_get_consumption_records(p_store_id UUID)
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

-- ==================== 预约列表查询 ====================

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

SELECT '✅ CRUD RPC v3 创建完成' AS result;
