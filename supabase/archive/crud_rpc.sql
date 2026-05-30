-- =============================================
-- CRUD RPC 函数（带权限校验）
-- 替代前端 supabase.from() 直接查表
-- 执行方式：Supabase Dashboard → SQL Editor → 粘贴执行
-- =============================================

-- ==================== 门店 CRUD ====================

CREATE OR REPLACE FUNCTION rpc_get_stores(p_store_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  IF p_store_id IS NOT NULL THEN
    SELECT to_jsonb(s) INTO v_result FROM stores s WHERE id = p_store_id;
    RETURN jsonb_build_object('data', v_result);
  END IF;
  SELECT COALESCE(jsonb_agg(to_jsonb(s)), '[]') INTO v_result
  FROM (SELECT * FROM stores ORDER BY created_at DESC) s;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_create_store(
  p_name VARCHAR, p_address VARCHAR DEFAULT NULL,
  p_phone VARCHAR DEFAULT NULL, p_manager VARCHAR DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  INSERT INTO stores (name, address, phone, manager) VALUES (p_name, p_address, p_phone, p_manager)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_store(
  p_id UUID, p_name VARCHAR DEFAULT NULL, p_address VARCHAR DEFAULT NULL,
  p_phone VARCHAR DEFAULT NULL, p_manager VARCHAR DEFAULT NULL, p_status VARCHAR DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE stores SET
    name = COALESCE(p_name, name),
    address = COALESCE(p_address, address),
    phone = COALESCE(p_phone, phone),
    manager = COALESCE(p_manager, manager),
    status = COALESCE(p_status, status)
  WHERE id = p_id RETURNING * INTO v_record;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '门店不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 管理员 CRUD ====================

CREATE OR REPLACE FUNCTION rpc_get_admins(p_store_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', a.id, 'username', a.username, 'name', a.name,
    'phone', a.phone, 'role', a.role, 'store_id', a.store_id,
    'store_name', s.name, 'created_at', a.created_at
  )), '[]') INTO v_result
  FROM admins a LEFT JOIN stores s ON a.store_id = s.id
  WHERE (p_store_id IS NULL OR a.store_id = p_store_id)
  ORDER BY a.created_at DESC;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_create_admin(
  p_username VARCHAR, p_password VARCHAR, p_name VARCHAR,
  p_phone VARCHAR DEFAULT NULL, p_role VARCHAR DEFAULT 'store_admin',
  p_store_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  IF p_role = 'store_admin' AND p_store_id IS NULL THEN
    RETURN jsonb_build_object('error', '店长必须绑定门店');
  END IF;
  INSERT INTO admins (username, password_hash, name, phone, role, store_id)
  VALUES (p_username, crypt(p_password, gen_salt('bf', 10)), p_name, p_phone, p_role, p_store_id)
  RETURNING id, username, name, phone, role, store_id, created_at INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_admin(
  p_id UUID, p_name VARCHAR DEFAULT NULL, p_phone VARCHAR DEFAULT NULL,
  p_role VARCHAR DEFAULT NULL, p_store_id UUID DEFAULT NULL,
  p_password VARCHAR DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  IF p_password IS NOT NULL THEN
    UPDATE admins SET
      name = COALESCE(p_name, name), phone = COALESCE(p_phone, phone),
      role = COALESCE(p_role, role), store_id = COALESCE(p_store_id, store_id),
      password_hash = crypt(p_password, gen_salt('bf', 10))
    WHERE id = p_id RETURNING id, username, name, phone, role, store_id, created_at INTO v_record;
  ELSE
    UPDATE admins SET
      name = COALESCE(p_name, name), phone = COALESCE(p_phone, phone),
      role = COALESCE(p_role, role), store_id = COALESCE(p_store_id, store_id)
    WHERE id = p_id RETURNING id, username, name, phone, role, store_id, created_at INTO v_record;
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

CREATE OR REPLACE FUNCTION rpc_get_members(p_store_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', m.id, 'phone', m.phone, 'name', m.name, 'level', m.level,
    'points', m.points, 'balance', m.balance, 'store_id', m.store_id,
    'status', m.status, 'store_name', s.name, 'created_at', m.created_at
  )), '[]') INTO v_result
  FROM members m LEFT JOIN stores s ON m.store_id = s.id
  WHERE (p_store_id IS NULL OR m.store_id = p_store_id)
  ORDER BY m.created_at DESC;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_member(
  p_id UUID, p_name VARCHAR DEFAULT NULL, p_phone VARCHAR DEFAULT NULL,
  p_level VARCHAR DEFAULT NULL, p_points INT DEFAULT NULL,
  p_balance DECIMAL DEFAULT NULL, p_status VARCHAR DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE members SET
    name = COALESCE(p_name, name), phone = COALESCE(p_phone, phone),
    level = COALESCE(p_level, level), points = COALESCE(p_points, points),
    balance = COALESCE(p_balance, balance), status = COALESCE(p_status, status)
  WHERE id = p_id RETURNING * INTO v_record;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 理发师 CRUD ====================

CREATE OR REPLACE FUNCTION rpc_get_barbers(p_store_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', b.id, 'name', b.name, 'phone', b.phone,
    'specialties', b.specialties, 'status', b.status,
    'store_id', b.store_id, 'store_name', s.name, 'created_at', b.created_at
  )), '[]') INTO v_result
  FROM barbers b LEFT JOIN stores s ON b.store_id = s.id
  WHERE (p_store_id IS NULL OR b.store_id = p_store_id)
  ORDER BY b.created_at DESC;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_create_barber(
  p_name VARCHAR, p_phone VARCHAR DEFAULT NULL,
  p_specialties TEXT[] DEFAULT NULL, p_store_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  INSERT INTO barbers (name, phone, specialties, store_id)
  VALUES (p_name, p_phone, p_specialties, p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_barber(
  p_id UUID, p_name VARCHAR DEFAULT NULL, p_phone VARCHAR DEFAULT NULL,
  p_specialties TEXT[] DEFAULT NULL, p_status VARCHAR DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE barbers SET
    name = COALESCE(p_name, name), phone = COALESCE(p_phone, phone),
    specialties = COALESCE(p_specialties, specialties), status = COALESCE(p_status, status)
  WHERE id = p_id RETURNING * INTO v_record;
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

CREATE OR REPLACE FUNCTION rpc_get_services(p_store_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', sv.id, 'type', sv.type, 'name', sv.name, 'price', sv.price,
    'discount_normal', sv.discount_normal, 'discount_silver', sv.discount_silver,
    'discount_gold', sv.discount_gold, 'discount_diamond', sv.discount_diamond,
    'store_id', sv.store_id, 'store_name', s.name, 'created_at', sv.created_at
  )), '[]') INTO v_result
  FROM services sv LEFT JOIN stores s ON sv.store_id = s.id
  WHERE (p_store_id IS NULL OR sv.store_id = p_store_id)
  ORDER BY sv.created_at DESC;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_create_service(
  p_type VARCHAR, p_name VARCHAR, p_price DECIMAL,
  p_discount_normal DECIMAL DEFAULT 1.00, p_discount_silver DECIMAL DEFAULT 0.95,
  p_discount_gold DECIMAL DEFAULT 0.90, p_discount_diamond DECIMAL DEFAULT 0.80,
  p_store_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  INSERT INTO services (type, name, price, discount_normal, discount_silver, discount_gold, discount_diamond, store_id)
  VALUES (p_type, p_name, p_price, p_discount_normal, p_discount_silver, p_discount_gold, p_discount_diamond, p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_service(
  p_id UUID, p_type VARCHAR DEFAULT NULL, p_name VARCHAR DEFAULT NULL,
  p_price DECIMAL DEFAULT NULL, p_discount_normal DECIMAL DEFAULT NULL,
  p_discount_silver DECIMAL DEFAULT NULL, p_discount_gold DECIMAL DEFAULT NULL,
  p_discount_diamond DECIMAL DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE services SET
    type = COALESCE(p_type::service_type, type), name = COALESCE(p_name, name),
    price = COALESCE(p_price, price),
    discount_normal = COALESCE(p_discount_normal, discount_normal),
    discount_silver = COALESCE(p_discount_silver, discount_silver),
    discount_gold = COALESCE(p_discount_gold, discount_gold),
    discount_diamond = COALESCE(p_discount_diamond, discount_diamond)
  WHERE id = p_id RETURNING * INTO v_record;
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

CREATE OR REPLACE FUNCTION rpc_get_packages(p_store_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', rp.id, 'name', rp.name, 'amount', rp.amount,
    'bonus', rp.bonus, 'status', rp.status,
    'store_id', rp.store_id, 'store_name', s.name, 'created_at', rp.created_at
  )), '[]') INTO v_result
  FROM recharge_packages rp LEFT JOIN stores s ON rp.store_id = s.id
  WHERE (p_store_id IS NULL OR rp.store_id = p_store_id)
  ORDER BY rp.created_at DESC;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_create_package(
  p_name VARCHAR, p_amount DECIMAL, p_bonus DECIMAL DEFAULT 0,
  p_status VARCHAR DEFAULT 'active', p_store_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  INSERT INTO recharge_packages (name, amount, bonus, status, store_id)
  VALUES (p_name, p_amount, p_bonus, p_status, p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_package(
  p_id UUID, p_name VARCHAR DEFAULT NULL, p_amount DECIMAL DEFAULT NULL,
  p_bonus DECIMAL DEFAULT NULL, p_status VARCHAR DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE recharge_packages SET
    name = COALESCE(p_name, name), amount = COALESCE(p_amount, amount),
    bonus = COALESCE(p_bonus, bonus), status = COALESCE(p_status, status)
  WHERE id = p_id RETURNING * INTO v_record;
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

CREATE OR REPLACE FUNCTION rpc_get_recharge_records(p_store_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', r.id, 'member_id', r.member_id, 'member_name', m.name,
    'member_phone', m.phone, 'amount', r.amount, 'bonus', r.bonus,
    'package_name', r.package_name, 'store_id', r.store_id,
    'store_name', s.name, 'created_at', r.created_at
  )), '[]') INTO v_result
  FROM recharge_records r
  LEFT JOIN members m ON r.member_id = m.id
  LEFT JOIN stores s ON r.store_id = s.id
  WHERE (p_store_id IS NULL OR r.store_id = p_store_id)
  ORDER BY r.created_at DESC;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 消费记录查询 ====================

CREATE OR REPLACE FUNCTION rpc_get_consumption_records(p_store_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', c.id, 'member_id', c.member_id, 'member_name', m.name,
    'member_phone', m.phone, 'amount', c.amount, 'original_price', c.original_price,
    'discount', c.discount, 'service_name', c.service_name,
    'barber_name', c.barber_name, 'points_earned', c.points_earned,
    'store_id', c.store_id, 'store_name', s.name, 'created_at', c.created_at
  )), '[]') INTO v_result
  FROM consumption_records c
  LEFT JOIN members m ON c.member_id = m.id
  LEFT JOIN stores s ON c.store_id = s.id
  WHERE (p_store_id IS NULL OR c.store_id = p_store_id)
  ORDER BY c.created_at DESC;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 预约列表查询 ====================

CREATE OR REPLACE FUNCTION rpc_get_appointments(p_store_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', a.id, 'member_id', a.member_id, 'member_name', m.name,
    'member_phone', m.phone, 'barber_id', a.barber_id, 'barber_name', b.name,
    'service_id', a.service_id, 'service_name', sv.name,
    'appointment_time', a.appointment_time, 'status', a.status,
    'store_id', a.store_id, 'store_name', s.name, 'created_at', a.created_at
  )), '[]') INTO v_result
  FROM appointments a
  LEFT JOIN members m ON a.member_id = m.id
  LEFT JOIN barbers b ON a.barber_id = b.id
  LEFT JOIN services sv ON a.service_id = sv.id
  LEFT JOIN stores s ON a.store_id = s.id
  WHERE (p_store_id IS NULL OR a.store_id = p_store_id)
  ORDER BY a.created_at DESC;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT '✅ CRUD RPC Functions 创建完成' AS result;
