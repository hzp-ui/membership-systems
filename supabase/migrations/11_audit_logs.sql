-- =============================================
-- 【在 Supabase Dashboard 执行】
-- SQL Editor → New Query → 粘贴全部内容 → Run
-- =============================================

-- =============================================
-- 第一部分：审计日志表
-- =============================================
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('admin', 'member')),
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
-- 第二部分：字段扩展
-- =============================================
ALTER TABLE admins ADD COLUMN IF NOT EXISTS password_upgraded_at TIMESTAMPTZ;
ALTER TABLE members ADD COLUMN IF NOT EXISTS password_upgraded_at TIMESTAMPTZ;
ALTER TABLE members ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';
ALTER TABLE recharge_packages ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';

-- =============================================
-- 第三部分：启用 RLS（逐表执行）
-- =============================================

-- admins
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS admins_all ON admins;
CREATE POLICY admins_all ON admins FOR ALL USING (true);

-- members
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS members_all ON members;
CREATE POLICY members_all ON members FOR ALL USING (true);

-- recharge_records
ALTER TABLE recharge_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS recharge_records_all ON recharge_records;
CREATE POLICY recharge_records_all ON recharge_records FOR ALL USING (true);

-- consumption_records
ALTER TABLE consumption_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS consumption_records_all ON consumption_records;
CREATE POLICY consumption_records_all ON consumption_records FOR ALL USING (true);

-- appointments
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS appointments_all ON appointments;
CREATE POLICY appointments_all ON appointments FOR ALL USING (true);

-- recharge_packages
ALTER TABLE recharge_packages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS recharge_packages_all ON recharge_packages;
CREATE POLICY recharge_packages_all ON recharge_packages FOR ALL USING (true);

-- services
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS services_all ON services;
CREATE POLICY services_all ON services FOR ALL USING (true);

-- barbers
ALTER TABLE barbers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS barbers_all ON barbers;
CREATE POLICY barbers_all ON barbers FOR ALL USING (true);

-- stores
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS stores_all ON stores;
CREATE POLICY stores_all ON stores FOR ALL USING (true);

-- audit_logs
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS audit_logs_all ON audit_logs;
CREATE POLICY audit_logs_all ON audit_logs FOR ALL USING (true);

SELECT '✅ 数据库迁移完成' AS result;
