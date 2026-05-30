-- RPC Functions - 替代 Edge Functions
-- 通过 Supabase REST API 的 /rpc/ 端点调用

-- ==================== 1. 管理员登录 ====================
CREATE OR REPLACE FUNCTION rpc_admin_login(p_username VARCHAR, p_password VARCHAR)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_token TEXT;
BEGIN
  SELECT * INTO v_admin FROM admins WHERE username = p_username LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '用户名或密码错误');
  END IF;
  
  -- 简单密码验证（生产环境应使用 bcrypt）
  IF v_admin.password_hash != p_password THEN
    RETURN jsonb_build_object('error', '用户名或密码错误');
  END IF;
  
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'id', v_admin.id,
      'username', v_admin.username,
      'name', v_admin.name,
      'phone', v_admin.phone,
      'role', v_admin.role,
      'store_id', v_admin.store_id,
      'token', 'admin_' || v_admin.id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 2. 会员注册 ====================
CREATE OR REPLACE FUNCTION rpc_member_register(
  p_phone VARCHAR, 
  p_password VARCHAR, 
  p_name VARCHAR DEFAULT NULL,
  p_store_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
BEGIN
  IF p_store_id IS NULL THEN
    RETURN jsonb_build_object('error', '请选择门店');
  END IF;
  
  INSERT INTO members (phone, password_hash, name, store_id)
  VALUES (p_phone, p_password, p_name, p_store_id)
  RETURNING * INTO v_member;
  
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'id', v_member.id,
      'phone', v_member.phone,
      'name', v_member.name,
      'level', v_member.level,
      'points', v_member.points,
      'balance', v_member.balance,
      'store_id', v_member.store_id,
      'token', 'member_' || v_member.id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 3. 会员登录 ====================
CREATE OR REPLACE FUNCTION rpc_member_login(p_phone VARCHAR, p_password VARCHAR, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
BEGIN
  SELECT * INTO v_member FROM members WHERE phone = p_phone AND store_id = p_store_id LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '手机号或密码错误');
  END IF;
  
  IF v_member.password_hash != p_password THEN
    RETURN jsonb_build_object('error', '手机号或密码错误');
  END IF;
  
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'id', v_member.id,
      'phone', v_member.phone,
      'name', v_member.name,
      'level', v_member.level,
      'points', v_member.points,
      'balance', v_member.balance,
      'store_id', v_member.store_id,
      'token', 'member_' || v_member.id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 4. 会员充值 ====================
CREATE OR REPLACE FUNCTION rpc_recharge(p_member_id UUID, p_package_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
  v_pkg RECORD;
  v_record RECORD;
BEGIN
  SELECT * INTO v_member FROM members WHERE id = p_member_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '会员不存在');
  END IF;
  
  SELECT * INTO v_pkg FROM recharge_packages WHERE id = p_package_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '充值套餐不存在');
  END IF;
  
  -- 更新余额
  UPDATE members SET balance = balance + v_pkg.amount + v_pkg.bonus WHERE id = p_member_id;
  
  -- 写充值记录
  INSERT INTO recharge_records (member_id, amount, bonus, package_name, store_id)
  VALUES (p_member_id, v_pkg.amount, v_pkg.bonus, v_pkg.name, v_member.store_id)
  RETURNING * INTO v_record;
  
  -- 返回新余额
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'new_balance', v_member.balance + v_pkg.amount + v_pkg.bonus,
      'recharge_amount', v_pkg.amount,
      'bonus', v_pkg.bonus,
      'record_id', v_record.id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 5. 会员消费 ====================
CREATE OR REPLACE FUNCTION rpc_consume(p_member_id UUID, p_service_id UUID, p_barber_id UUID DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
  v_service RECORD;
  v_barber_name VARCHAR;
  v_discount DECIMAL;
  v_amount DECIMAL;
  v_points INT;
BEGIN
  SELECT * INTO v_member FROM members WHERE id = p_member_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '会员不存在');
  END IF;
  
  SELECT * INTO v_service FROM services WHERE id = p_service_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '服务项目不存在');
  END IF;
  
  -- 根据会员等级获取折扣
  CASE v_member.level
    WHEN 'normal' THEN v_discount := v_service.discount_normal;
    WHEN 'silver' THEN v_discount := v_service.discount_silver;
    WHEN 'gold' THEN v_discount := v_service.discount_gold;
    WHEN 'diamond' THEN v_discount := v_service.discount_diamond;
    ELSE v_discount := 1.00;
  END CASE;
  
  v_amount := ROUND(v_service.price * v_discount, 2);
  
  -- 检查余额
  IF v_member.balance < v_amount THEN
    RETURN jsonb_build_object('error', '余额不足，当前余额: ' || v_member.balance || ' 元，需要: ' || v_amount || ' 元');
  END IF;
  
  -- 获取理发师名字
  v_barber_name := NULL;
  IF p_barber_id IS NOT NULL THEN
    SELECT name INTO v_barber_name FROM barbers WHERE id = p_barber_id;
  END IF;
  
  -- 计算积分（消费金额向下取整）
  v_points := FLOOR(v_amount);
  
  -- 扣余额、加积分
  UPDATE members SET balance = balance - v_amount, points = points + v_points WHERE id = p_member_id;
  
  -- 写消费记录
  INSERT INTO consumption_records (member_id, amount, original_price, discount, service_id, service_name, barber_id, barber_name, points_earned, store_id)
  VALUES (p_member_id, v_amount, v_service.price, v_discount, p_service_id, v_service.name, p_barber_id, v_barber_name, v_points, v_member.store_id);
  
  -- 升级会员等级（根据累计积分）
  UPDATE members SET level = CASE
    WHEN points >= 5000 THEN 'diamond'
    WHEN points >= 2000 THEN 'gold'
    WHEN points >= 500 THEN 'silver'
    ELSE 'normal'
  END WHERE id = p_member_id;
  
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'new_balance', v_member.balance - v_amount,
      'amount', v_amount,
      'original_price', v_service.price,
      'discount', v_discount,
      'points_earned', v_points,
      'total_points', v_member.points + v_points,
      'service_name', v_service.name
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 6. 创建预约 ====================
CREATE OR REPLACE FUNCTION rpc_create_appointment(p_member_id UUID, p_barber_id UUID, p_service_id UUID, p_appointment_time TIMESTAMPTZ)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
  v_appointment RECORD;
BEGIN
  SELECT * INTO v_member FROM members WHERE id = p_member_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '会员不存在');
  END IF;
  
  INSERT INTO appointments (member_id, barber_id, service_id, appointment_time, status, store_id)
  VALUES (p_member_id, p_barber_id, p_service_id, p_appointment_time, 'pending', v_member.store_id)
  RETURNING * INTO v_appointment;
  
  RETURN jsonb_build_object('data', to_jsonb(v_appointment));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 7. 确认预约 ====================
CREATE OR REPLACE FUNCTION rpc_confirm_appointment(p_id UUID)
RETURNS JSONB AS $$
BEGIN
  UPDATE appointments SET status = 'confirmed', updated_at = now() WHERE id = p_id AND status = 'pending';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '预约不存在或状态不允许确认');
  END IF;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id, 'status', 'confirmed'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 8. 取消预约 ====================
CREATE OR REPLACE FUNCTION rpc_cancel_appointment(p_id UUID)
RETURNS JSONB AS $$
BEGIN
  UPDATE appointments SET status = 'cancelled', updated_at = now() WHERE id = p_id AND status IN ('pending', 'confirmed');
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '预约不存在或状态不允许取消');
  END IF;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id, 'status', 'cancelled'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 9. 完成预约（自动消费） ====================
CREATE OR REPLACE FUNCTION rpc_complete_appointment(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_appt RECORD;
  v_result JSONB;
BEGIN
  SELECT * INTO v_appt FROM appointments WHERE id = p_id AND status = 'confirmed';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '预约不存在或状态不允许完成');
  END IF;
  
  UPDATE appointments SET status = 'completed', updated_at = now() WHERE id = p_id;
  
  -- 自动触发消费
  v_result := rpc_consume(v_appt.member_id, v_appt.service_id, v_appt.barber_id);
  
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'id', p_id, 
      'status', 'completed',
      'consumption', v_result
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 10. 营业额统计 ====================
CREATE OR REPLACE FUNCTION rpc_revenue_stats(
  p_store_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL,
  p_dimension VARCHAR DEFAULT 'day'
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB := '[]'::JSONB;
BEGIN
  IF p_dimension = 'day' THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object('period', d::text, 'total_amount', COALESCE(s.total, 0))),'[]'::JSONB)
    INTO v_result
    FROM generate_series(
      COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days'),
      COALESCE(p_end_date, CURRENT_DATE),
      INTERVAL '1 day'
    ) d
    LEFT JOIN (
      SELECT DATE(created_at) AS dt, SUM(amount) AS total
      FROM consumption_records
      WHERE (p_store_id IS NULL OR store_id = p_store_id)
        AND (p_start_date IS NULL OR created_at >= p_start_date)
        AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day')
      GROUP BY DATE(created_at)
    ) s ON d = s.dt;
  END IF;
  
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 11. 会员增长统计 ====================
CREATE OR REPLACE FUNCTION rpc_member_growth_stats(
  p_store_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL,
  p_dimension VARCHAR DEFAULT 'day'
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB := '[]'::JSONB;
BEGIN
  IF p_dimension = 'day' THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object('period', d::text, 'count', COALESCE(s.cnt, 0))),'[]'::JSONB)
    INTO v_result
    FROM generate_series(
      COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days'),
      COALESCE(p_end_date, CURRENT_DATE),
      INTERVAL '1 day'
    ) d
    LEFT JOIN (
      SELECT DATE(created_at) AS dt, COUNT(*) AS cnt
      FROM members
      WHERE (p_store_id IS NULL OR store_id = p_store_id)
        AND (p_start_date IS NULL OR created_at >= p_start_date)
        AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day')
      GROUP BY DATE(created_at)
    ) s ON d = s.dt;
  END IF;
  
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 12. 热门服务统计 ====================
CREATE OR REPLACE FUNCTION rpc_hot_services_stats(
  p_store_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(jsonb_build_object('service_name', service_name, 'count', cnt)),'[]'::JSONB)
  INTO v_result
  FROM (
    SELECT service_name, COUNT(*) AS cnt
    FROM consumption_records
    WHERE (p_store_id IS NULL OR store_id = p_store_id)
      AND (p_start_date IS NULL OR created_at >= p_start_date)
      AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day')
    GROUP BY service_name
    ORDER BY cnt DESC
    LIMIT 10
  ) sub;
  
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 13. 财务汇总 ====================
CREATE OR REPLACE FUNCTION rpc_finance_summary(
  p_store_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_recharge DECIMAL;
  v_consumption DECIMAL;
BEGIN
  SELECT COALESCE(SUM(amount + bonus), 0) INTO v_recharge FROM recharge_records
  WHERE (p_store_id IS NULL OR store_id = p_store_id)
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day');
  
  SELECT COALESCE(SUM(amount), 0) INTO v_consumption FROM consumption_records
  WHERE (p_store_id IS NULL OR store_id = p_store_id)
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day');
  
  RETURN jsonb_build_object('data', jsonb_build_object(
    'recharge_income', v_recharge,
    'consumption_income', v_consumption,
    'net_income', v_consumption,
    'refund_amount', 0
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==================== 14. 每日对账单 ====================
CREATE OR REPLACE FUNCTION rpc_daily_statements(
  p_store_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
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
    FROM recharge_records
    WHERE (p_store_id IS NULL OR store_id = p_store_id)
    GROUP BY DATE(created_at)
  ) r ON d.dt = r.dt
  LEFT JOIN (
    SELECT DATE(created_at) AS dt, COUNT(*) AS cnt, SUM(amount) AS total
    FROM consumption_records
    WHERE (p_store_id IS NULL OR store_id = p_store_id)
    GROUP BY DATE(created_at)
  ) c ON d.dt = c.dt;
  
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT '✅ RPC Functions created' AS result;
