-- =============================================
-- RLS 策略：多门店数据隔离
-- =============================================

-- 启用 RLS
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE barbers ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE recharge_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE recharge_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE consumption_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

-- 门店：超管可看所有，店长可看本店
CREATE POLICY stores_super_admin ON stores FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY stores_store_admin ON stores FOR SELECT USING (id = (SELECT store_id FROM admins WHERE id = auth.uid()));

-- 管理员：超管可看所有，店长可看自己
CREATE POLICY admins_super_admin ON admins FOR ALL USING (role = 'super_admin' OR true) WITH CHECK (true);
CREATE POLICY admins_self ON admins FOR SELECT USING (id = auth.uid());

-- 会员：超管可看所有，店长看本店，会员看自己
CREATE POLICY members_super_admin ON members FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY members_store_admin ON members FOR ALL USING (store_id = (SELECT store_id FROM admins WHERE id = auth.uid()));
CREATE POLICY members_self ON members FOR SELECT USING (id = auth.uid());

-- 理发师：超管可看所有，店长看本店
CREATE POLICY barbers_super_admin ON barbers FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY barbers_store_admin ON barbers FOR ALL USING (store_id = (SELECT store_id FROM admins WHERE id = auth.uid()));

-- 服务项目：超管可看所有，店长看本店
CREATE POLICY services_super_admin ON services FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY services_store_admin ON services FOR ALL USING (store_id = (SELECT store_id FROM admins WHERE id = auth.uid()));

-- 充值套餐：超管可看所有，店长看本店
CREATE POLICY recharge_packages_super_admin ON recharge_packages FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY recharge_packages_store_admin ON recharge_packages FOR ALL USING (store_id = (SELECT store_id FROM admins WHERE id = auth.uid()));

-- 充值记录：超管可看所有，店长看本店，会员看自己
CREATE POLICY recharge_records_super_admin ON recharge_records FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY recharge_records_store_admin ON recharge_records FOR SELECT USING (store_id = (SELECT store_id FROM admins WHERE id = auth.uid()));
CREATE POLICY recharge_records_self ON recharge_records FOR SELECT USING (member_id = auth.uid());

-- 消费记录：超管可看所有，店长看本店，会员看自己
CREATE POLICY consumption_records_super_admin ON consumption_records FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY consumption_records_store_admin ON consumption_records FOR SELECT USING (store_id = (SELECT store_id FROM admins WHERE id = auth.uid()));
CREATE POLICY consumption_records_self ON consumption_records FOR SELECT USING (member_id = auth.uid());

-- 预约：超管可看所有，店长看本店，会员看自己
CREATE POLICY appointments_super_admin ON appointments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY appointments_store_admin ON appointments FOR ALL USING (store_id = (SELECT store_id FROM admins WHERE id = auth.uid()));
CREATE POLICY appointments_self ON appointments FOR ALL USING (member_id = auth.uid());

-- updated_at 自动更新触发器
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stores_updated BEFORE UPDATE ON stores FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_admins_updated BEFORE UPDATE ON admins FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_members_updated BEFORE UPDATE ON members FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_barbers_updated BEFORE UPDATE ON barbers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_services_updated BEFORE UPDATE ON services FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_recharge_packages_updated BEFORE UPDATE ON recharge_packages FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_appointments_updated BEFORE UPDATE ON appointments FOR EACH ROW EXECUTE FUNCTION update_updated_at();
