-- =============================================
-- 修复所有 RPC 函数中的不存在的枚举类型转换
-- 根因：admins.role / services.type / members.level 等列都是 TEXT 类型
--       但 RPC 函数里错误地用了 ::admin_role ::service_type 等枚举转换
-- =============================================

-- ==================== 管理员 CRUD ====================

DROP FUNCTION IF EXISTS rpc_create_admin(TEXT, TEXT, TEXT, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS rpc_update_admin(UUID, TEXT, TEXT, TEXT, UUID, TEXT);

CREATE FUNCTION rpc_create_admin(p_username TEXT, p_password TEXT, p_name TEXT, p_phone TEXT, p_role TEXT, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  IF p_role = 'store_admin' AND p_store_id IS NULL THEN
    RETURN jsonb_build_object('error', '店长必须绑定门店');
  END IF;
  INSERT INTO admins (username, password_hash, name, phone, role, store_id)
  VALUES (p_username, crypt(p_password, gen_salt('bf', 10)), p_name, NULLIF(p_phone, ''), NULLIF(p_role, ''), p_store_id)
  RETURNING id, username, name, phone, role, store_id, created_at INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION rpc_update_admin(p_id UUID, p_name TEXT, p_phone TEXT, p_role TEXT, p_store_id UUID, p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
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

-- ==================== 会员 CRUD ====================

DROP FUNCTION IF EXISTS rpc_update_member(UUID, TEXT, TEXT, TEXT, BIGINT, DECIMAL, TEXT);

CREATE FUNCTION rpc_update_member(p_id UUID, p_name TEXT, p_phone TEXT, p_level TEXT, p_points BIGINT, p_balance DECIMAL, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE members SET
    name = COALESCE(NULLIF(p_name, ''), name),
    phone = COALESCE(NULLIF(p_phone, ''), phone),
    level = COALESCE(NULLIF(p_level, ''), level),
    points = COALESCE(p_points, points),
    balance = COALESCE(p_balance, balance),
    status = COALESCE(NULLIF(p_status, ''), status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 门店 CRUD ====================

DROP FUNCTION IF EXISTS rpc_update_store(UUID, TEXT, TEXT, TEXT, TEXT, TEXT);

CREATE FUNCTION rpc_update_store(p_id UUID, p_name TEXT, p_address TEXT, p_phone TEXT, p_manager TEXT, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
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

-- ==================== 理发师 CRUD ====================

DROP FUNCTION IF EXISTS rpc_create_barber(TEXT, TEXT, JSONB, UUID);
DROP FUNCTION IF EXISTS rpc_update_barber(UUID, TEXT, TEXT, JSONB, TEXT);

CREATE FUNCTION rpc_create_barber(p_name TEXT, p_phone TEXT, p_specialties JSONB, p_store_id UUID)
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

CREATE FUNCTION rpc_update_barber(p_id UUID, p_name TEXT, p_phone TEXT, p_specialties JSONB, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE barbers SET
    name = COALESCE(NULLIF(p_name, ''), name),
    phone = COALESCE(NULLIF(p_phone, ''), phone),
    specialties = COALESCE(p_specialties::text[], specialties),
    status = COALESCE(NULLIF(p_status, ''), status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '理发师不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 服务项目 CRUD ====================

DROP FUNCTION IF EXISTS rpc_create_service(TEXT, TEXT, DECIMAL, DECIMAL, DECIMAL, DECIMAL, DECIMAL, UUID);
DROP FUNCTION IF EXISTS rpc_update_service(UUID, TEXT, TEXT, DECIMAL, DECIMAL, DECIMAL, DECIMAL, DECIMAL);

CREATE FUNCTION rpc_create_service(p_type TEXT, p_name TEXT, p_price DECIMAL, p_discount_normal DECIMAL, p_discount_silver DECIMAL, p_discount_gold DECIMAL, p_discount_diamond DECIMAL, p_store_id UUID)
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

CREATE FUNCTION rpc_update_service(p_id UUID, p_type TEXT, p_name TEXT, p_price DECIMAL, p_discount_normal DECIMAL, p_discount_silver DECIMAL, p_discount_gold DECIMAL, p_discount_diamond DECIMAL)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
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
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '服务项目不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 套餐 CRUD ====================

DROP FUNCTION IF EXISTS rpc_create_package(TEXT, DECIMAL, DECIMAL, TEXT, UUID);
DROP FUNCTION IF EXISTS rpc_update_package(UUID, TEXT, DECIMAL, DECIMAL, TEXT);

CREATE FUNCTION rpc_create_package(p_name TEXT, p_amount DECIMAL, p_bonus DECIMAL, p_status TEXT, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  INSERT INTO recharge_packages (name, amount, bonus, status, store_id)
  VALUES (p_name, p_amount, p_bonus, NULLIF(p_status, ''), p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION rpc_update_package(p_id UUID, p_name TEXT, p_amount DECIMAL, p_bonus DECIMAL, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_record RECORD;
BEGIN
  UPDATE recharge_packages SET
    name = COALESCE(NULLIF(p_name, ''), name),
    amount = COALESCE(p_amount, amount),
    bonus = COALESCE(p_bonus, bonus),
    status = COALESCE(NULLIF(p_status, ''), status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '充值套餐不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT '✅ 所有枚举类型转换已修复' AS result;
