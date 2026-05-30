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