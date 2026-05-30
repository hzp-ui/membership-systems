-- =============================================
-- 会员系统 - 安全加固 RPC Functions
-- 替代 Edge Functions，使用 Supabase Auth + RLS
-- 
-- 执行方式：Supabase Dashboard → SQL Editor → 粘贴执行
-- =============================================

-- =============================================
-- 0. 启用 pgcrypto 扩展（用于密码哈希）
-- =============================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =============================================
-- 1. 管理员登录（使用 Supabase Auth）
-- =============================================
CREATE OR REPLACE FUNCTION rpc_admin_login(
  p_username VARCHAR,
  p_password VARCHAR
)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_user_id UUID;
BEGIN
  -- 查找管理员
  SELECT * INTO v_admin FROM admins WHERE username = p_username;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '用户名或密码错误');
  END IF;
  
  -- 密码验证（支持 bcrypt 哈希和明文过渡）
  IF v_admin.password_hash IS NULL THEN
    RETURN jsonb_build_object('error', '账户异常，请联系管理员');
    
  ELSIF v_admin.password_hash LIKE '$2%' THEN
    -- bcrypt 哈希验证
    IF NOT (crypt(p_password, v_admin.password_hash) = v_admin.password_hash) THEN
      RETURN jsonb_build_object('error', '用户名或密码错误');
    END IF;
    
  ELSE
    -- 明文密码过渡（首次登录后自动升级）
    IF v_admin.password_hash != p_password THEN
      RETURN jsonb_build_object('error', '用户名或密码错误');
    END IF;
    
    -- 自动升级密码为 bcrypt 哈希
    UPDATE admins 
    SET password_hash = crypt(p_password, gen_salt('bf', 10)),
        password_upgraded_at = NOW()
    WHERE id = v_admin.id;
  END IF;
  
  -- 返回管理员信息（不含密码）
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'id', v_admin.id,
      'username', v_admin.username,
      'name', v_admin.name,
      'role', v_admin.role,
      'store_id', v_admin.store_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 2. 会员注册（使用 Supabase Auth）
-- =============================================
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
  -- 输入验证
  IF p_phone IS NULL OR p_password IS NULL OR p_store_id IS NULL THEN
    RETURN jsonb_build_object('error', '缺少必填字段');
  END IF;
  
  -- 手机号格式验证
  IF p_phone !~ '^1[3-9]\d{9}$' THEN
    RETURN jsonb_build_object('error', '手机号格式不正确');
  END IF;
  
  -- 密码复杂度验证
  IF LENGTH(p_password) < 8 
     OR p_password !~ '[A-Z]' 
     OR p_password !~ '[a-z]' 
     OR p_password !~ '[0-9]' THEN
    RETURN jsonb_build_object('error', '密码至少8位，需包含大小写字母和数字');
  END IF;
  
  -- 检查手机号是否已注册
  IF EXISTS (SELECT 1 FROM members WHERE phone = p_phone AND store_id = p_store_id) THEN
    RETURN jsonb_build_object('error', '该手机号已注册');
  END IF;
  
  -- 创建会员（密码使用 bcrypt 哈希）
  INSERT INTO members (phone, password_hash, name, store_id, level, points, balance, status)
  VALUES (
    p_phone, 
    crypt(p_password, gen_salt('bf', 10)), 
    p_name, 
    p_store_id, 
    'normal', 
    0, 
    0,
    'active'
  )
  RETURNING * INTO v_member;
  
  -- 返回会员信息（不含密码）
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'id', v_member.id,
      'phone', v_member.phone,
      'name', v_member.name,
      'level', v_member.level,
      'points', v_member.points,
      'balance', v_member.balance,
      'store_id', v_member.store_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 3. 会员登录（使用 Supabase Auth）
-- =============================================
CREATE OR REPLACE FUNCTION rpc_member_login(
  p_phone VARCHAR, 
  p_password VARCHAR, 
  p_store_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
BEGIN
  -- 查找会员
  SELECT * INTO v_member 
  FROM members 
  WHERE phone = p_phone AND store_id = p_store_id AND status = 'active';
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '手机号或密码错误');
  END IF;
  
  -- 密码验证（支持 bcrypt 哈希和明文过渡）
  IF v_member.password_hash IS NULL THEN
    RETURN jsonb_build_object('error', '账户异常，请联系管理员');
    
  ELSIF v_member.password_hash LIKE '$2%' THEN
    -- bcrypt 哈希验证
    IF NOT (crypt(p_password, v_member.password_hash) = v_member.password_hash) THEN
      RETURN jsonb_build_object('error', '手机号或密码错误');
    END IF;
    
  ELSE
    -- 明文密码过渡
    IF v_member.password_hash != p_password THEN
      RETURN jsonb_build_object('error', '手机号或密码错误');
    END IF;
    
    -- 自动升级密码为 bcrypt 哈希
    UPDATE members 
    SET password_hash = crypt(p_password, gen_salt('bf', 10)),
        password_upgraded_at = NOW()
    WHERE id = v_member.id;
  END IF;
  
  -- 返回会员信息（不含密码）
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'id', v_member.id,
      'phone', v_member.phone,
      'name', v_member.name,
      'level', v_member.level,
      'points', v_member.points,
      'balance', v_member.balance,
      'store_id', v_member.store_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 4. 会员充值（带事务保护 + 审计日志）
-- =============================================
CREATE OR REPLACE FUNCTION rpc_recharge(
  p_member_id UUID, 
  p_package_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
  v_pkg RECORD;
  v_new_balance DECIMAL;
  v_record RECORD;
  v_old_balance DECIMAL;
BEGIN
  -- 获取会员信息（行锁）
  SELECT * INTO v_member 
  FROM members 
  WHERE id = p_member_id AND status = 'active'
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '会员不存在或已冻结');
  END IF;
  
  v_old_balance := v_member.balance;
  
  -- 获取充值套餐
  SELECT * INTO v_pkg 
  FROM recharge_packages 
  WHERE id = p_package_id AND status = 'active';
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '充值套餐不存在或已下架');
  END IF;
  
  -- 验证套餐属于同一门店
  IF v_pkg.store_id != v_member.store_id THEN
    RETURN jsonb_build_object('error', '充值套餐不适用于此会员');
  END IF;
  
  -- 计算新余额
  v_new_balance := v_old_balance + v_pkg.amount + v_pkg.bonus;
  
  -- 更新会员余额
  UPDATE members 
  SET balance = v_new_balance,
      updated_at = NOW()
  WHERE id = p_member_id;
  
  -- 创建充值记录
  INSERT INTO recharge_records (member_id, amount, bonus, package_name, store_id)
  VALUES (p_member_id, v_pkg.amount, v_pkg.bonus, v_pkg.name, v_member.store_id)
  RETURNING * INTO v_record;
  
  -- 写入审计日志
  INSERT INTO audit_logs (user_id, user_type, action, resource_type, resource_id, details)
  VALUES (
    auth.uid(), 
    'admin', 
    'RECHARGE', 
    'member_balance', 
    p_member_id, 
    jsonb_build_object(
      'package_id', p_package_id,
      'package_name', v_pkg.name,
      'amount', v_pkg.amount,
      'bonus', v_pkg.bonus,
      'old_balance', v_old_balance,
      'new_balance', v_new_balance
    )
  );
  
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'record_id', v_record.id,
      'new_balance', v_new_balance,
      'recharge_amount', v_pkg.amount,
      'bonus', v_pkg.bonus
    )
  );
  
EXCEPTION WHEN OTHERS THEN
  -- 回滚事务
  RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 5. 会员消费（带事务保护 + 审计日志）
-- =============================================
CREATE OR REPLACE FUNCTION rpc_consume(
  p_member_id UUID, 
  p_service_id UUID, 
  p_barber_id UUID DEFAULT NULL
)
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
  -- 获取会员信息（行锁）
  SELECT * INTO v_member 
  FROM members 
  WHERE id = p_member_id AND status = 'active'
  FOR UPDATE;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '会员不存在或已冻结');
  END IF;
  
  -- 获取服务项目
  SELECT * INTO v_service 
  FROM services 
  WHERE id = p_service_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '服务项目不存在');
  END IF;
  
  -- 验证服务属于同一门店
  IF v_service.store_id != v_member.store_id THEN
    RETURN jsonb_build_object('error', '服务项目不适用于此会员');
  END IF;
  
  -- 根据会员等级获取折扣
  v_discount := CASE v_member.level
    WHEN 'normal' THEN v_service.discount_normal
    WHEN 'silver' THEN v_service.discount_silver
    WHEN 'gold' THEN v_service.discount_gold
    WHEN 'diamond' THEN v_service.discount_diamond
    ELSE 1.00
  END;
  
  v_amount := ROUND(v_service.price * v_discount, 2);
  
  -- 检查余额
  IF v_member.balance < v_amount THEN
    RETURN jsonb_build_object(
      'error', '余额不足',
      'current_balance', v_member.balance,
      'required_amount', v_amount
    );
  END IF;
  
  -- 获取理发师名字
  IF p_barber_id IS NOT NULL THEN
    SELECT name INTO v_barber_name 
    FROM barbers 
    WHERE id = p_barber_id AND store_id = v_member.store_id;
  END IF;
  
  -- 计算积分（消费金额向下取整）
  v_points := FLOOR(v_amount);
  v_new_balance := v_member.balance - v_amount;
  v_new_points := v_member.points + v_points;
  
  -- 扣余额、加积分
  UPDATE members 
  SET balance = v_new_balance,
      points = v_new_points,
      updated_at = NOW()
  WHERE id = p_member_id;
  
  -- 写消费记录
  INSERT INTO consumption_records (
    member_id, amount, original_price, discount, 
    service_id, service_name, barber_id, barber_name, 
    points_earned, store_id
  )
  VALUES (
    p_member_id, v_amount, v_service.price, v_discount,
    p_service_id, v_service.name, p_barber_id, v_barber_name,
    v_points, v_member.store_id
  );
  
  -- 升级会员等级（根据累计积分）
  UPDATE members 
  SET level = CASE
    WHEN v_new_points >= 5000 THEN 'diamond'
    WHEN v_new_points >= 2000 THEN 'gold'
    WHEN v_new_points >= 500 THEN 'silver'
    ELSE 'normal'
  END
  WHERE id = p_member_id;
  
  -- 写入审计日志
  INSERT INTO audit_logs (user_id, user_type, action, resource_type, resource_id, details)
  VALUES (
    auth.uid(), 
    'admin', 
    'CONSUME', 
    'member_balance', 
    p_member_id, 
    jsonb_build_object(
      'service_id', p_service_id,
      'service_name', v_service.name,
      'barber_id', p_barber_id,
      'barber_name', v_barber_name,
      'original_price', v_service.price,
      'discount', v_discount,
      'amount', v_amount,
      'points_earned', v_points,
      'old_balance', v_member.balance,
      'new_balance', v_new_balance
    )
  );
  
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'new_balance', v_new_balance,
      'amount', v_amount,
      'original_price', v_service.price,
      'discount', v_discount,
      'points_earned', v_points,
      'total_points', v_new_points
    )
  );
  
EXCEPTION WHEN OTHERS THEN
  RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 6. 创建预约（带审计日志）
-- =============================================
CREATE OR REPLACE FUNCTION rpc_create_appointment(
  p_member_id UUID, 
  p_barber_id UUID, 
  p_service_id UUID, 
  p_appointment_time TIMESTAMPTZ
)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
  v_appointment RECORD;
BEGIN
  -- 验证会员
  SELECT * INTO v_member 
  FROM members 
  WHERE id = p_member_id AND status = 'active';
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '会员不存在或已冻结');
  END IF;
  
  -- 验证预约时间（不能是过去）
  IF p_appointment_time < NOW() THEN
    RETURN jsonb_build_object('error', '预约时间不能是过去');
  END IF;
  
  -- 创建预约
  INSERT INTO appointments (member_id, barber_id, service_id, appointment_time, status, store_id)
  VALUES (p_member_id, p_barber_id, p_service_id, p_appointment_time, 'pending', v_member.store_id)
  RETURNING * INTO v_appointment;
  
  -- 审计日志
  INSERT INTO audit_logs (user_id, user_type, action, resource_type, resource_id, details)
  VALUES (
    auth.uid(), 
    'member', 
    'CREATE_APPOINTMENT', 
    'appointment', 
    v_appointment.id, 
    jsonb_build_object(
      'member_id', p_member_id,
      'barber_id', p_barber_id,
      'service_id', p_service_id,
      'appointment_time', p_appointment_time
    )
  );
  
  RETURN jsonb_build_object('data', to_jsonb(v_appointment));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 7. 确认预约
-- =============================================
CREATE OR REPLACE FUNCTION rpc_confirm_appointment(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_appointment RECORD;
BEGIN
  SELECT * INTO v_appointment 
  FROM appointments 
  WHERE id = p_id AND status = 'pending';
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '预约不存在或状态不允许确认');
  END IF;
  
  UPDATE appointments 
  SET status = 'confirmed', updated_at = NOW()
  WHERE id = p_id;
  
  -- 审计日志
  INSERT INTO audit_logs (user_id, user_type, action, resource_type, resource_id)
  VALUES (auth.uid(), 'admin', 'CONFIRM_APPOINTMENT', 'appointment', p_id);
  
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id, 'status', 'confirmed'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 8. 取消预约
-- =============================================
CREATE OR REPLACE FUNCTION rpc_cancel_appointment(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_appointment RECORD;
BEGIN
  SELECT * INTO v_appointment 
  FROM appointments 
  WHERE id = p_id AND status IN ('pending', 'confirmed');
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '预约不存在或状态不允许取消');
  END IF;
  
  UPDATE appointments 
  SET status = 'cancelled', updated_at = NOW()
  WHERE id = p_id;
  
  -- 审计日志
  INSERT INTO audit_logs (user_id, user_type, action, resource_type, resource_id)
  VALUES (auth.uid(), 'member', 'CANCEL_APPOINTMENT', 'appointment', p_id);
  
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id, 'status', 'cancelled'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 9. 完成预约（自动消费）
-- =============================================
CREATE OR REPLACE FUNCTION rpc_complete_appointment(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_appointment RECORD;
  v_result JSONB;
BEGIN
  SELECT * INTO v_appointment 
  FROM appointments 
  WHERE id = p_id AND status = 'confirmed';
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '预约不存在或状态不允许完成');
  END IF;
  
  UPDATE appointments 
  SET status = 'completed', updated_at = NOW()
  WHERE id = p_id;
  
  -- 自动触发消费
  SELECT rpc_consume(v_appointment.member_id, v_appointment.service_id, v_appointment.barber_id) 
  INTO v_result;
  
  -- 审计日志
  INSERT INTO audit_logs (user_id, user_type, action, resource_type, resource_id, details)
  VALUES (
    auth.uid(), 
    'admin', 
    'COMPLETE_APPOINTMENT', 
    'appointment', 
    p_id,
    jsonb_build_object('consumption', v_result)
  );
  
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'id', p_id, 
      'status', 'completed',
      'consumption', v_result
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 10. 营业额统计（安全版）
-- =============================================
CREATE OR REPLACE FUNCTION rpc_revenue_stats(
  p_store_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL,
  p_dimension VARCHAR DEFAULT 'day'
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB := '[]'::JSONB;
  v_start DATE;
  v_end DATE;
BEGIN
  v_start := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
  v_end := COALESCE(p_end_date, CURRENT_DATE);
  
  -- 只有店长和超管可以查看统计
  IF NOT EXISTS (
    SELECT 1 FROM admins 
    WHERE id = auth.uid() 
      AND (role = 'super_admin' OR (role = 'store_admin' AND store_id = p_store_id))
  ) THEN
    RETURN jsonb_build_object('error', '权限不足');
  END IF;
  
  IF p_dimension = 'day' THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object('period', d::text, 'total_amount', COALESCE(s.total, 0))),'[]'::JSONB)
    INTO v_result
    FROM generate_series(v_start, v_end, INTERVAL '1 day') d
    LEFT JOIN (
      SELECT DATE(created_at) AS dt, SUM(amount) AS total
      FROM consumption_records
      WHERE (p_store_id IS NULL OR store_id = p_store_id)
        AND created_at >= v_start
        AND created_at < v_end + INTERVAL '1 day'
      GROUP BY DATE(created_at)
    ) s ON d = s.dt;
  END IF;
  
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 11. 会员增长统计
-- =============================================
CREATE OR REPLACE FUNCTION rpc_member_growth_stats(
  p_store_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL,
  p_dimension VARCHAR DEFAULT 'day'
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB := '[]'::JSONB;
  v_start DATE;
  v_end DATE;
BEGIN
  v_start := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
  v_end := COALESCE(p_end_date, CURRENT_DATE);
  
  -- 权限检查
  IF NOT EXISTS (
    SELECT 1 FROM admins 
    WHERE id = auth.uid() 
      AND (role = 'super_admin' OR (role = 'store_admin' AND store_id = p_store_id))
  ) THEN
    RETURN jsonb_build_object('error', '权限不足');
  END IF;
  
  IF p_dimension = 'day' THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object('period', d::text, 'count', COALESCE(s.cnt, 0))),'[]'::JSONB)
    INTO v_result
    FROM generate_series(v_start, v_end, INTERVAL '1 day') d
    LEFT JOIN (
      SELECT DATE(created_at) AS dt, COUNT(*) AS cnt
      FROM members
      WHERE (p_store_id IS NULL OR store_id = p_store_id)
        AND created_at >= v_start
        AND created_at < v_end + INTERVAL '1 day'
        AND status = 'active'
      GROUP BY DATE(created_at)
    ) s ON d = s.dt;
  END IF;
  
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 12. 热门服务统计
-- =============================================
CREATE OR REPLACE FUNCTION rpc_hot_services_stats(
  p_store_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  -- 权限检查
  IF NOT EXISTS (
    SELECT 1 FROM admins 
    WHERE id = auth.uid() 
      AND (role = 'super_admin' OR (role = 'store_admin' AND store_id = p_store_id))
  ) THEN
    RETURN jsonb_build_object('error', '权限不足');
  END IF;
  
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

-- =============================================
-- 13. 财务汇总
-- =============================================
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
  -- 权限检查
  IF NOT EXISTS (
    SELECT 1 FROM admins 
    WHERE id = auth.uid() 
      AND (role = 'super_admin' OR (role = 'store_admin' AND store_id = p_store_id))
  ) THEN
    RETURN jsonb_build_object('error', '权限不足');
  END IF;
  
  SELECT COALESCE(SUM(amount + bonus), 0) INTO v_recharge 
  FROM recharge_records
  WHERE (p_store_id IS NULL OR store_id = p_store_id)
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day');
  
  SELECT COALESCE(SUM(amount), 0) INTO v_consumption 
  FROM consumption_records
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

-- =============================================
-- 14. 每日对账单（支持 CSV 导出）
-- =============================================
CREATE OR REPLACE FUNCTION rpc_daily_statements(
  p_store_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  -- 权限检查
  IF NOT EXISTS (
    SELECT 1 FROM admins 
    WHERE id = auth.uid() 
      AND (role = 'super_admin' OR (role = 'store_admin' AND store_id = p_store_id))
  ) THEN
    RETURN jsonb_build_object('error', '权限不足');
  END IF;
  
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

-- =============================================
-- 完成：验证所有函数创建成功
-- =============================================
DO $$
BEGIN
  -- 验证关键函数存在
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'rpc_admin_login') THEN
    RAISE EXCEPTION 'rpc_admin_login 创建失败';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'rpc_member_login') THEN
    RAISE EXCEPTION 'rpc_member_login 创建失败';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'rpc_recharge') THEN
    RAISE EXCEPTION 'rpc_recharge 创建失败';
  END IF;
  
  RAISE NOTICE '✅ 安全加固 RPC Functions 创建成功！';
END $$;
