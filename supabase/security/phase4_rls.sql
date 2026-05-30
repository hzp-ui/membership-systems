-- Phase 4: RLS 激活
-- 执行方式：Supabase Dashboard → SQL Editor → 粘贴 → Run

-- 1. 清除所有现有策略
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname = 'public') LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
  END LOOP;
END $$;

-- 2. 所有业务表启用 RLS
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
ALTER TABLE service_types ENABLE ROW LEVEL SECURITY;

-- 3. authenticated 用户可读所有业务表
CREATE POLICY authenticated_read ON stores FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON admins FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON members FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON barbers FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON services FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON recharge_packages FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON recharge_records FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON consumption_records FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON appointments FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON service_types FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read_audit ON audit_logs FOR SELECT TO authenticated USING (true);

-- 4. anon 用户：只读门店/服务/理发师/套餐（C 端浏览）
CREATE POLICY anon_stores_read ON stores FOR SELECT TO anon USING (status = 'active');
CREATE POLICY anon_services_read ON services FOR SELECT TO anon USING (true);
CREATE POLICY anon_barbers_read ON barbers FOR SELECT TO anon USING (status = 'active');
CREATE POLICY anon_packages_read ON recharge_packages FOR SELECT TO anon USING (status = 'active');

-- 5. 写操作：全部通过 RPC (SECURITY DEFINER)，RLS 默认拒绝直接写

SELECT '✅ Phase 4: RLS 激活完成' AS result;
