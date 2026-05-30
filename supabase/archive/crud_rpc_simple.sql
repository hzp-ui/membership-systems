-- =============================================
-- CRUD RPC 函数（简化版）
-- 修复：去掉复杂 join，确保函数能创建
-- =============================================

-- ==================== 门店 ====================

CREATE OR REPLACE FUNCTION rpc_get_stores(p_store_id UUID)
RETURNS SETOF stores AS $$
BEGIN
  IF p_store_id IS NULL THEN
    RETURN QUERY SELECT * FROM stores ORDER BY created_at DESC;
  ELSE
    RETURN QUERY SELECT * FROM stores WHERE id = p_store_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_create_store(p_name TEXT, p_address TEXT, p_phone TEXT, p_manager TEXT)
RETURNS stores AS $$
DECLARE
  v_record stores;
BEGIN
  INSERT INTO stores (name, address, phone, manager)
  VALUES (p_name, p_address, p_phone, p_manager)
  RETURNING * INTO v_record;
  RETURN v_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_store(p_id UUID, p_name TEXT, p_address TEXT, p_phone TEXT, p_manager TEXT, p_status TEXT)
RETURNS stores AS $$
DECLARE
  v_record stores;
BEGIN
  UPDATE stores SET
    name = COALESCE(p_name, name),
    address = COALESCE(p_address, address),
    phone = COALESCE(p_phone, phone),
    manager = COALESCE(p_manager, manager),
    status = COALESCE(p_status::store_status, status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  RETURN v_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 管理员 ====================

CREATE OR REPLACE FUNCTION rpc_get_admins(p_store_id UUID)
RETURNS TABLE (
  id UUID, username TEXT, name TEXT, phone TEXT,
  role TEXT, store_id UUID, created_at TIMESTAMPTZ,
  store_name TEXT
) AS $$
BEGIN
  RETURN QUERY SELECT
    a.id, a.username, a.name, a.phone, a.role::TEXT, a.store_id, a.created_at,
    s.name AS store_name
  FROM admins a
  LEFT JOIN stores s ON a.store_id = s.id
  WHERE (p_store_id IS NULL OR a.store_id = p_store_id)
  ORDER BY a.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_admin(p_id UUID, p_name TEXT, p_phone TEXT, p_role TEXT, p_store_id UUID, p_password TEXT)
RETURNS TABLE (
  id UUID, username TEXT, name TEXT, phone TEXT,
  role TEXT, store_id UUID, created_at TIMESTAMPTZ
) AS $$
BEGIN
  IF p_password IS NOT NULL THEN
    UPDATE admins SET
      name = COALESCE(p_name, name),
      phone = COALESCE(p_phone, phone),
      role = COALESCE(p_role::admin_role, role),
      store_id = COALESCE(p_store_id, store_id),
      password_hash = crypt(p_password, gen_salt('bf', 10))
    WHERE id = p_id;
  ELSE
    UPDATE admins SET
      name = COALESCE(p_name, name),
      phone = COALESCE(p_phone, phone),
      role = COALESCE(p_role::admin_role, role),
      store_id = COALESCE(p_store_id, store_id)
    WHERE id = p_id;
  END IF;
  RETURN QUERY SELECT a.id, a.username, a.name, a.phone, a.role::TEXT, a.store_id, a.created_at
  FROM admins a WHERE a.id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_delete_admin(p_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  DELETE FROM admins WHERE id = p_id;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 会员 ====================

CREATE OR REPLACE FUNCTION rpc_get_members(p_store_id UUID)
RETURNS TABLE (
  id UUID, phone TEXT, name TEXT, level TEXT,
  points INT, balance DECIMAL, store_id UUID,
  status TEXT, created_at TIMESTAMPTZ,
  store_name TEXT
) AS $$
BEGIN
  RETURN QUERY SELECT
    m.id, m.phone, m.name, m.level::TEXT, m.points, m.balance, m.store_id,
    m.status::TEXT, m.created_at,
    s.name AS store_name
  FROM members m
  LEFT JOIN stores s ON m.store_id = s.id
  WHERE (p_store_id IS NULL OR m.store_id = p_store_id)
  ORDER BY m.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_member(p_id UUID, p_name TEXT, p_phone TEXT, p_level TEXT, p_points INT, p_balance DECIMAL, p_status TEXT)
RETURNS members AS $$
DECLARE
  v_record members;
BEGIN
  UPDATE members SET
    name = COALESCE(p_name, name),
    phone = COALESCE(p_phone, phone),
    level = COALESCE(p_level::member_level, level),
    points = COALESCE(p_points, points),
    balance = COALESCE(p_balance, balance),
    status = COALESCE(p_status::member_status, status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  RETURN v_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 理发师 ====================

CREATE OR REPLACE FUNCTION rpc_get_barbers(p_store_id UUID)
RETURNS TABLE (
  id UUID, name TEXT, phone TEXT, specialties TEXT[],
  status TEXT, store_id UUID, created_at TIMESTAMPTZ,
  store_name TEXT
) AS $$
BEGIN
  RETURN QUERY SELECT
    b.id, b.name, b.phone, b.specialties,
    b.status::TEXT, b.store_id, b.created_at,
    s.name AS store_name
  FROM barbers b
  LEFT JOIN stores s ON b.store_id = s.id
  WHERE (p_store_id IS NULL OR b.store_id = p_store_id)
  ORDER BY b.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_barber(p_id UUID, p_name TEXT, p_phone TEXT, p_specialties TEXT[], p_status TEXT)
RETURNS barbers AS $$
DECLARE
  v_record barbers;
BEGIN
  UPDATE barbers SET
    name = COALESCE(p_name, name),
    phone = COALESCE(p_phone, phone),
    specialties = COALESCE(p_specialties, specialties),
    status = COALESCE(p_status::barber_status, status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  RETURN v_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_delete_barber(p_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  DELETE FROM barbers WHERE id = p_id;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 服务项目 ====================

CREATE OR REPLACE FUNCTION rpc_get_services(p_store_id UUID)
RETURNS TABLE (
  id UUID, type TEXT, name TEXT, price DECIMAL,
  discount_normal DECIMAL, discount_silver DECIMAL,
  discount_gold DECIMAL, discount_diamond DECIMAL,
  store_id UUID, created_at TIMESTAMPTZ,
  store_name TEXT
) AS $$
BEGIN
  RETURN QUERY SELECT
    sv.id, sv.type::TEXT, sv.name, sv.price,
    sv.discount_normal, sv.discount_silver,
    sv.discount_gold, sv.discount_diamond,
    sv.store_id, sv.created_at,
    s.name AS store_name
  FROM services sv
  LEFT JOIN stores s ON sv.store_id = s.id
  WHERE (p_store_id IS NULL OR sv.store_id = p_store_id)
  ORDER BY sv.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_service(
  p_id UUID, p_type TEXT, p_name TEXT, p_price DECIMAL,
  p_discount_normal DECIMAL, p_discount_silver DECIMAL,
  p_discount_gold DECIMAL, p_discount_diamond DECIMAL
)
RETURNS services AS $$
DECLARE
  v_record services;
BEGIN
  UPDATE services SET
    type = COALESCE(p_type::service_type, type),
    name = COALESCE(p_name, name),
    price = COALESCE(p_price, price),
    discount_normal = COALESCE(p_discount_normal, discount_normal),
    discount_silver = COALESCE(p_discount_silver, discount_silver),
    discount_gold = COALESCE(p_discount_gold, discount_gold),
    discount_diamond = COALESCE(p_discount_diamond, discount_diamond)
  WHERE id = p_id
  RETURNING * INTO v_record;
  RETURN v_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_delete_service(p_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  DELETE FROM services WHERE id = p_id;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 充值套餐 ====================

CREATE OR REPLACE FUNCTION rpc_get_packages(p_store_id UUID)
RETURNS TABLE (
  id UUID, name TEXT, amount DECIMAL, bonus DECIMAL,
  status TEXT, store_id UUID, created_at TIMESTAMPTZ,
  store_name TEXT
) AS $$
BEGIN
  RETURN QUERY SELECT
    rp.id, rp.name, rp.amount, rp.bonus,
    rp.status::TEXT, rp.store_id, rp.created_at,
    s.name AS store_name
  FROM recharge_packages rp
  LEFT JOIN stores s ON rp.store_id = s.id
  WHERE (p_store_id IS NULL OR rp.store_id = p_store_id)
  ORDER BY rp.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_update_package(p_id UUID, p_name TEXT, p_amount DECIMAL, p_bonus DECIMAL, p_status TEXT)
RETURNS recharge_packages AS $$
DECLARE
  v_record recharge_packages;
BEGIN
  UPDATE recharge_packages SET
    name = COALESCE(p_name, name),
    amount = COALESCE(p_amount, amount),
    bonus = COALESCE(p_bonus, bonus),
    status = COALESCE(p_status::package_status, status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  RETURN v_record;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_delete_package(p_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  DELETE FROM recharge_packages WHERE id = p_id;
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 充值记录 ====================

CREATE OR REPLACE FUNCTION rpc_get_recharge_records(p_store_id UUID)
RETURNS TABLE (
  id UUID, member_id UUID, member_name TEXT, member_phone TEXT,
  amount DECIMAL, bonus DECIMAL, package_name TEXT,
  store_id UUID, store_name TEXT, created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY SELECT
    r.id, r.member_id, m.name AS member_name, m.phone AS member_phone,
    r.amount, r.bonus, r.package_name,
    r.store_id, s.name AS store_name, r.created_at
  FROM recharge_records r
  LEFT JOIN members m ON r.member_id = m.id
  LEFT JOIN stores s ON r.store_id = s.id
  WHERE (p_store_id IS NULL OR r.store_id = p_store_id)
  ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 消费记录 ====================

CREATE OR REPLACE FUNCTION rpc_get_consumption_records(p_store_id UUID)
RETURNS TABLE (
  id UUID, member_id UUID, member_name TEXT, member_phone TEXT,
  amount DECIMAL, original_price DECIMAL, discount DECIMAL,
  service_name TEXT, barber_name TEXT, points_earned INT,
  store_id UUID, store_name TEXT, created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY SELECT
    c.id, c.member_id, m.name AS member_name, m.phone AS member_phone,
    c.amount, c.original_price, c.discount,
    c.service_name, c.barber_name, c.points_earned,
    c.store_id, s.name AS store_name, c.created_at
  FROM consumption_records c
  LEFT JOIN members m ON c.member_id = m.id
  LEFT JOIN stores s ON c.store_id = s.id
  WHERE (p_store_id IS NULL OR c.store_id = p_store_id)
  ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 预约列表 ====================

CREATE OR REPLACE FUNCTION rpc_get_appointments(p_store_id UUID)
RETURNS TABLE (
  id UUID, member_id UUID, member_name TEXT, member_phone TEXT,
  barber_id UUID, barber_name TEXT, service_id UUID, service_name TEXT,
  appointment_time TIMESTAMPTZ, status TEXT,
  store_id UUID, store_name TEXT, created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY SELECT
    a.id, a.member_id, m.name AS member_name, m.phone AS member_phone,
    a.barber_id, b.name AS barber_name, a.service_id, sv.name AS service_name,
    a.appointment_time, a.status::TEXT,
    a.store_id, s.name AS store_name, a.created_at
  FROM appointments a
  LEFT JOIN members m ON a.member_id = m.id
  LEFT JOIN barbers b ON a.barber_id = b.id
  LEFT JOIN services sv ON a.service_id = sv.id
  LEFT JOIN stores s ON a.store_id = s.id
  WHERE (p_store_id IS NULL OR a.store_id = p_store_id)
  ORDER BY a.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT '✅ 简化版 CRUD RPC 创建完成' AS result;
