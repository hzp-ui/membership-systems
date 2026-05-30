-- =============================================
-- 理发店会员管理系统 - 完整数据库部署脚本（RPC 版）
-- 执行方式：Supabase Dashboard → SQL Editor → 粘贴全部 → Run
-- =============================================

-- =============================================
-- 第一部分：基础表
-- =============================================

-- 01_stores
CREATE TABLE IF NOT EXISTS stores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  address VARCHAR(255),
  phone VARCHAR(20),
  manager VARCHAR(50),
  status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE stores IS '门店表';
CREATE INDEX IF NOT EXISTS idx_stores_status ON stores(status);

-- 02_admins
CREATE TABLE IF NOT EXISTS admins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(50) NOT NULL,
  phone VARCHAR(20),
  role VARCHAR(20) NOT NULL CHECK (role IN ('super_admin', 'store_admin')),
  store_id UUID REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_admins_store FOREIGN KEY (store_id) REFERENCES stores(id),
  CONSTRAINT store_admin_must_have_store CHECK (
    (role = 'store_admin' AND store_id IS NOT NULL) OR
    (role = 'super_admin' AND store_id IS NULL)
  )
);
COMMENT ON TABLE admins IS '管理员表';
CREATE INDEX IF NOT EXISTS idx_admins_role ON admins(role);
CREATE INDEX IF NOT EXISTS idx_admins_store ON admins(store_id);

-- 03_members
CREATE TABLE IF NOT EXISTS members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone VARCHAR(20) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(50),
  level VARCHAR(20) NOT NULL DEFAULT 'normal' CHECK (level IN ('normal', 'silver', 'gold', 'diamond')),
  points INT NOT NULL DEFAULT 0,
  balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  store_id UUID NOT NULL REFERENCES stores(id),
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'frozen')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uk_members_phone_store UNIQUE (phone, store_id)
);
COMMENT ON TABLE members IS '会员表';
CREATE INDEX IF NOT EXISTS idx_members_store ON members(store_id);
CREATE INDEX IF NOT EXISTS idx_members_level ON members(level);
CREATE INDEX IF NOT EXISTS idx_members_phone ON members(phone);

-- 04_barbers
CREATE TABLE IF NOT EXISTS barbers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) NOT NULL,
  phone VARCHAR(20),
  specialties TEXT[],
  status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  store_id UUID NOT NULL REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_barbers_store ON barbers(store_id);

-- 05_services
CREATE TYPE IF NOT EXISTS service_type AS ENUM ('wash', 'cut', 'color', 'perm', 'treatment', 'other');
CREATE TABLE IF NOT EXISTS services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type service_type NOT NULL,
  name VARCHAR(100) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  discount_normal DECIMAL(3,2) NOT NULL DEFAULT 1.00,
  discount_silver DECIMAL(3,2) NOT NULL DEFAULT 0.95,
  discount_gold DECIMAL(3,2) NOT NULL DEFAULT 0.90,
  discount_diamond DECIMAL(3,2) NOT NULL DEFAULT 0.80,
  store_id UUID NOT NULL REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_services_store ON services(store_id);

-- 06_recharge_packages
CREATE TABLE IF NOT EXISTS recharge_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  bonus DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  store_id UUID NOT NULL REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_recharge_packages_store ON recharge_packages(store_id);

-- 07_recharge_records
CREATE TABLE IF NOT EXISTS recharge_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES members(id),
  amount DECIMAL(10,2) NOT NULL,
  bonus DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  package_name VARCHAR(100),
  store_id UUID NOT NULL REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_recharge_records_member ON recharge_records(member_id);
CREATE INDEX IF NOT EXISTS idx_recharge_records_store ON recharge_records(store_id);
CREATE INDEX IF NOT EXISTS idx_recharge_records_created ON recharge_records(created_at);

-- 08_consumption_records
CREATE TABLE IF NOT EXISTS consumption_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES members(id),
  amount DECIMAL(10,2) NOT NULL,
  original_price DECIMAL(10,2) NOT NULL,
  discount DECIMAL(3,2) NOT NULL,
  service_id UUID NOT NULL REFERENCES services(id),
  service_name VARCHAR(100) NOT NULL,
  barber_id UUID REFERENCES barbers(id),
  barber_name VARCHAR(50),
  points_earned INT NOT NULL DEFAULT 0,
  store_id UUID NOT NULL REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_consumption_records_member ON consumption_records(member_id);
CREATE INDEX IF NOT EXISTS idx_consumption_records_store ON consumption_records(store_id);
CREATE INDEX IF NOT EXISTS idx_consumption_records_created ON consumption_records(created_at);

-- 09_appointments
CREATE TABLE IF NOT EXISTS appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES members(id),
  barber_id UUID NOT NULL REFERENCES barbers(id),
  service_id UUID NOT NULL REFERENCES services(id),
  appointment_time TIMESTAMPTZ NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  store_id UUID NOT NULL REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_appointments_member ON appointments(member_id);
CREATE INDEX IF NOT EXISTS idx_appointments_barber ON appointments(barber_id);
CREATE INDEX IF NOT EXISTS idx_appointments_store ON appointments(store_id);
CREATE INDEX IF NOT EXISTS idx_appointments_status ON appointments(status);

-- 11_audit_logs
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  user_type VARCHAR(20) CHECK (user_type IN ('admin', 'member')),
  action VARCHAR(50) NOT NULL,
  resource_type VARCHAR(50) NOT NULL,
  resource_id UUID,
  details JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC);

-- =============================================
-- 第二部分：RLS 策略
-- =============================================
-- 注意：前端不再用 Supabase Auth，而是用 RPC + 自定义 token
-- RLS 策略全部设为 USING (true)，权限控制在 RPC 层实现
-- 客户端用 service_role key 调 RPC，anon key 只读部分表

ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE barbers ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE recharge_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE recharge_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE consumption_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- 清除旧策略
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (
    SELECT schemaname, tablename, policyname 
    FROM pg_policies 
    WHERE schemaname = 'public'
  ) LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
  END LOOP;
END $$;

-- anon 用户：只读门店列表和可用服务（用户端浏览用）
CREATE POLICY stores_read ON stores FOR SELECT USING (status = 'active');
CREATE POLICY services_read ON services FOR SELECT USING (true);
CREATE POLICY barbers_read ON barbers FOR SELECT USING (status = 'active');
CREATE POLICY recharge_packages_read ON recharge_packages FOR SELECT USING (status = 'active');

-- 其余表 anon 无权访问，通过 RPC (SECURITY DEFINER) 操作
-- service_role key 由后端/RPC 使用，有完全访问权

-- =============================================
-- 第三部分：updated_at 触发器
-- =============================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_stores_updated ON stores;
CREATE TRIGGER trg_stores_updated BEFORE UPDATE ON stores FOR EACH ROW EXECUTE FUNCTION update_updated_at();
DROP TRIGGER IF EXISTS trg_admins_updated ON admins;
CREATE TRIGGER trg_admins_updated BEFORE UPDATE ON admins FOR EACH ROW EXECUTE FUNCTION update_updated_at();
DROP TRIGGER IF EXISTS trg_members_updated ON members;
CREATE TRIGGER trg_members_updated BEFORE UPDATE ON members FOR EACH ROW EXECUTE FUNCTION update_updated_at();
DROP TRIGGER IF EXISTS trg_barbers_updated ON barbers;
CREATE TRIGGER trg_barbers_updated BEFORE UPDATE ON barbers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
DROP TRIGGER IF EXISTS trg_services_updated ON services;
CREATE TRIGGER trg_services_updated BEFORE UPDATE ON services FOR EACH ROW EXECUTE FUNCTION update_updated_at();
DROP TRIGGER IF EXISTS trg_recharge_packages_updated ON recharge_packages;
CREATE TRIGGER trg_recharge_packages_updated BEFORE UPDATE ON recharge_packages FOR EACH ROW EXECUTE FUNCTION update_updated_at();
DROP TRIGGER IF EXISTS trg_appointments_updated ON appointments;
CREATE TRIGGER trg_appointments_updated BEFORE UPDATE ON appointments FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================
-- 第四部分：RPC 函数（替代全部 Edge Functions）
-- =============================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------- 1. 管理员登录 ----------
CREATE OR REPLACE FUNCTION rpc_admin_login(
  p_username VARCHAR,
  p_password VARCHAR
)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
BEGIN
  SELECT id, username, name, phone, role, store_id, password_hash
  INTO v_admin FROM admins WHERE username = p_username;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '用户名或密码错误');
  END IF;
  
  IF v_admin.password_hash LIKE '$2%' THEN
    IF NOT (crypt(p_password, v_admin.password_hash) = v_admin.password_hash) THEN
      RETURN jsonb_build_object('error', '用户名或密码错误');
    END IF;
  ELSE
    IF v_admin.password_hash != p_password THEN
      RETURN jsonb_build_object('error', '用户名或密码错误');
    END IF;
    UPDATE admins SET password_hash = crypt(p_password, gen_salt('bf', 10)) WHERE id = v_admin.id;
  END IF;
  
  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'id', v_admin.id,
      'username', v_admin.username,
      'name', v_admin.name,
      'phone', v_admin.phone,
      'role', v_admin.role,
      'store_id', v_admin.store_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 2. 会员注册 ----------
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
  IF p_phone IS NULL OR p_password IS NULL OR p_store_id IS NULL THEN
    RETURN jsonb_build_object('error', '缺少必填字段');
  END IF;
  IF p_phone !~ '^1[3-9]\d{9}$' THEN
    RETURN jsonb_build_object('error', '手机号格式不正确');
  END IF;
  IF LENGTH(p_password) < 6 THEN
    RETURN jsonb_build_object('error', '密码至少6位');
  END IF;
  IF EXISTS (SELECT 1 FROM members WHERE phone = p_phone AND store_id = p_store_id) THEN
    RETURN jsonb_build_object('error', '该手机号已注册');
  END IF;
  
  INSERT INTO members (phone, password_hash, name, store_id, level, points, balance, status)
  VALUES (p_phone, crypt(p_password, gen_salt('bf', 10)), p_name, p_store_id, 'normal', 0, 0, 'active')
  RETURNING id, phone, name, level, points, balance, store_id
  INTO v_member;
  
  RETURN jsonb_build_object('data', to_jsonb(v_member));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 3. 会员登录 ----------
CREATE OR REPLACE FUNCTION rpc_member_login(
  p_phone VARCHAR,
  p_password VARCHAR,
  p_store_id UUID
)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
BEGIN
  SELECT id, phone, name, level, points, balance, store_id, password_hash
  INTO v_member FROM members
  WHERE phone = p_phone AND store_id = p_store_id AND status = 'active';
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '手机号或密码错误');
  END IF;
  
  IF v_member.password_hash LIKE '$2%' THEN
    IF NOT (crypt(p_password, v_member.password_hash) = v_member.password_hash) THEN
      RETURN jsonb_build_object('error', '手机号或密码错误');
    END IF;
  ELSE
    IF v_member.password_hash != p_password THEN
      RETURN jsonb_build_object('error', '手机号或密码错误');
    END IF;
    UPDATE members SET password_hash = crypt(p_password, gen_salt('bf', 10)) WHERE id = v_member.id;
  END IF;
  
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

-- ---------- 4. 会员充值（套餐） ----------
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
BEGIN
  SELECT * INTO v_member FROM members WHERE id = p_member_id AND status = 'active' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在或已冻结'); END IF;
  
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

-- ---------- 5. 自定义金额充值 ----------
CREATE OR REPLACE FUNCTION rpc_custom_recharge(
  p_member_id UUID,
  p_amount DECIMAL,
  p_bonus DECIMAL DEFAULT 0
)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
  v_new_balance DECIMAL;
  v_record RECORD;
BEGIN
  IF p_amount <= 0 THEN RETURN jsonb_build_object('error', '充值金额必须大于0'); END IF;
  
  SELECT * INTO v_member FROM members WHERE id = p_member_id AND status = 'active' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在或已冻结'); END IF;
  
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

-- ---------- 6. 会员消费 ----------
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
  SELECT * INTO v_member FROM members WHERE id = p_member_id AND status = 'active' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在或已冻结'); END IF;
  
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

-- ---------- 7. 创建预约 ----------
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
  SELECT * INTO v_member FROM members WHERE id = p_member_id AND status = 'active';
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在'); END IF;
  IF p_appointment_time < NOW() THEN RETURN jsonb_build_object('error', '预约时间不能是过去'); END IF;
  
  INSERT INTO appointments (member_id, barber_id, service_id, appointment_time, status, store_id)
  VALUES (p_member_id, p_barber_id, p_service_id, p_appointment_time, 'pending', v_member.store_id)
  RETURNING * INTO v_appointment;
  
  RETURN jsonb_build_object('data', to_jsonb(v_appointment));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 8. 确认预约 ----------
CREATE OR REPLACE FUNCTION rpc_confirm_appointment(p_id UUID)
RETURNS JSONB AS $$
BEGIN
  UPDATE appointments SET status = 'confirmed', updated_at = now() WHERE id = p_id AND status = 'pending';
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '预约不存在或状态不允许确认'); END IF;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id, 'status', 'confirmed'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 9. 取消预约 ----------
CREATE OR REPLACE FUNCTION rpc_cancel_appointment(p_id UUID)
RETURNS JSONB AS $$
BEGIN
  UPDATE appointments SET status = 'cancelled', updated_at = now() WHERE id = p_id AND status IN ('pending', 'confirmed');
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '预约不存在或状态不允许取消'); END IF;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id, 'status', 'cancelled'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 10. 完成预约（自动消费） ----------
CREATE OR REPLACE FUNCTION rpc_complete_appointment(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_appt RECORD;
  v_result JSONB;
BEGIN
  SELECT * INTO v_appt FROM appointments WHERE id = p_id AND status = 'confirmed';
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '预约不存在或状态不允许完成'); END IF;
  
  UPDATE appointments SET status = 'completed', updated_at = now() WHERE id = p_id;
  v_result := rpc_consume(v_appt.member_id, v_appt.service_id, v_appt.barber_id);
  
  RETURN jsonb_build_object('data', jsonb_build_object(
    'id', p_id, 'status', 'completed', 'consumption', v_result
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 11. 营业额统计 ----------
CREATE OR REPLACE FUNCTION rpc_revenue_stats(
  p_store_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB := '[]'::JSONB;
  v_start DATE;
  v_end DATE;
BEGIN
  v_start := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
  v_end := COALESCE(p_end_date, CURRENT_DATE);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object('period', d::text, 'total_amount', COALESCE(s.total, 0))),'[]'::JSONB)
  INTO v_result
  FROM generate_series(v_start, v_end, INTERVAL '1 day') d
  LEFT JOIN (
    SELECT DATE(created_at) AS dt, SUM(amount) AS total
    FROM consumption_records
    WHERE (p_store_id IS NULL OR store_id = p_store_id)
      AND created_at >= v_start AND created_at < v_end + INTERVAL '1 day'
    GROUP BY DATE(created_at)
  ) s ON d = s.dt;
  
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 12. 会员增长统计 ----------
CREATE OR REPLACE FUNCTION rpc_member_growth_stats(
  p_store_id UUID DEFAULT NULL,
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB := '[]'::JSONB;
  v_start DATE;
  v_end DATE;
BEGIN
  v_start := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
  v_end := COALESCE(p_end_date, CURRENT_DATE);
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object('period', d::text, 'count', COALESCE(s.cnt, 0))),'[]'::JSONB)
  INTO v_result
  FROM generate_series(v_start, v_end, INTERVAL '1 day') d
  LEFT JOIN (
    SELECT DATE(created_at) AS dt, COUNT(*) AS cnt
    FROM members
    WHERE (p_store_id IS NULL OR store_id = p_store_id)
      AND created_at >= v_start AND created_at < v_end + INTERVAL '1 day'
      AND status = 'active'
    GROUP BY DATE(created_at)
  ) s ON d = s.dt;
  
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 13. 热门服务统计 ----------
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
    GROUP BY service_name ORDER BY cnt DESC LIMIT 10
  ) sub;
  
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 14. 财务汇总 ----------
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
    'net_income', v_consumption
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------- 15. 每日对账单 ----------
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
    FROM recharge_records WHERE (p_store_id IS NULL OR store_id = p_store_id)
    GROUP BY DATE(created_at)
  ) r ON d.dt = r.dt
  LEFT JOIN (
    SELECT DATE(created_at) AS dt, COUNT(*) AS cnt, SUM(amount) AS total
    FROM consumption_records WHERE (p_store_id IS NULL OR store_id = p_store_id)
    GROUP BY DATE(created_at)
  ) c ON d.dt = c.dt;
  
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 第五部分：种子数据
-- =============================================

-- 默认超级管理员（密码: admin123，bcrypt hash）
INSERT INTO admins (username, password_hash, name, role, store_id)
VALUES (
  'admin',
  crypt('admin123', gen_salt('bf', 10)),
  '超级管理员',
  'super_admin',
  NULL
) ON CONFLICT (username) DO NOTHING;

-- 示例门店
INSERT INTO stores (id, name, address, phone, status)
VALUES (
  'a0000000-0000-0000-0000-000000000001',
  '总店',
  '深圳市南山区科技路1号',
  '0755-88888001',
  'active'
) ON CONFLICT DO NOTHING;

-- 示例门店管理员（密码: store123）
INSERT INTO admins (username, password_hash, name, role, store_id)
VALUES (
  'store_admin_1',
  crypt('store123', gen_salt('bf', 10)),
  '总店店长',
  'store_admin',
  'a0000000-0000-0000-0000-000000000001'
) ON CONFLICT (username) DO NOTHING;

-- =============================================
-- 完成
-- =============================================
SELECT '✅ 数据库部署完成！RPC 函数已就绪。' AS result;
