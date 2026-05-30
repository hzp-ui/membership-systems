-- 修复 RLS：放行所有表的 anon 查询，权限由 RPC (SECURITY DEFINER) 控制
-- 在 Supabase Dashboard → SQL Editor 执行

-- 清除所有旧策略
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

-- 所有表对所有角色完全放行（权限控制在 RPC 层）
CREATE POLICY stores_all ON stores FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY admins_all ON admins FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY members_all ON members FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY barbers_all ON barbers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY services_all ON services FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY recharge_packages_all ON recharge_packages FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY recharge_records_all ON recharge_records FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY consumption_records_all ON consumption_records FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY appointments_all ON appointments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY audit_logs_all ON audit_logs FOR ALL USING (true) WITH CHECK (true);

SELECT '✅ RLS 策略已更新' AS result;
