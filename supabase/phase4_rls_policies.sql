-- ========================================
-- Phase 4: 激活 RLS + 策略
-- ========================================
-- 目标: 为所有表激活 Row Level Security，创建策略实现行级权限控制
-- 策略逻辑: super_admin 可访问所有数据，store_admin 只能访问自己门店的数据

-- ========================================
-- 辅助函数：获取当前管理员角色
-- ========================================
CREATE OR REPLACE FUNCTION get_current_admin_role()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  admin_role text;
BEGIN
  SELECT role INTO admin_role
  FROM admins
  WHERE auth_user_id = auth.uid();
  
  RETURN admin_role;
END;
$$;

-- ========================================
-- 辅助函数：获取当前管理员门店ID
-- ========================================
CREATE OR REPLACE FUNCTION get_current_admin_store_id()
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  admin_store_id uuid;
BEGIN
  SELECT store_id INTO admin_store_id
  FROM admins
  WHERE auth_user_id = auth.uid();
  
  RETURN admin_store_id;
END;
$$;

-- ========================================
-- 1. admins 表
-- ========================================
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;

-- 删除已有策略（如果有）
DROP POLICY IF EXISTS "Super admin can access all" ON admins;
DROP POLICY IF EXISTS "Store admin can access own row" ON admins;

-- super_admin 可访问所有
CREATE POLICY "Super admin can access all" ON admins
  FOR ALL USING (
    get_current_admin_role() = 'super_admin'
  );

-- store_admin 只能访问自己
CREATE POLICY "Store admin can access own row" ON admins
  FOR ALL USING (
    auth_user_id = auth.uid()
  );

-- ========================================
-- 2. members 表
-- ========================================
ALTER TABLE members ENABLE ROW LEVEL SECURITY;

-- 删除已有策略（如果有）
DROP POLICY IF EXISTS "Super admin can access all members" ON members;
DROP POLICY IF EXISTS "Store admin can access own store members" ON members;

-- super_admin 可访问所有会员
CREATE POLICY "Super admin can access all members" ON members
  FOR ALL USING (
    get_current_admin_role() = 'super_admin'
  );

-- store_admin 只能访问自己门店的会员
CREATE POLICY "Store admin can access own store members" ON members
  FOR ALL USING (
    store_id = get_current_admin_store_id()
  );

-- ========================================
-- 3. stores 表
-- ========================================
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;

-- 删除已有策略（如果有）
DROP POLICY IF EXISTS "Super admin can access all stores" ON stores;
DROP POLICY IF EXISTS "Store admin can access own store" ON stores;

-- super_admin 可访问所有门店
CREATE POLICY "Super admin can access all stores" ON stores
  FOR ALL USING (
    get_current_admin_role() = 'super_admin'
  );

-- store_admin 只能访问自己门店
CREATE POLICY "Store admin can access own store" ON stores
  FOR ALL USING (
    id = get_current_admin_store_id()
  );

-- ========================================
-- 4. barbers 表
-- ========================================
ALTER TABLE barbers ENABLE ROW LEVEL SECURITY;

-- 删除已有策略（如果有）
DROP POLICY IF EXISTS "Super admin can access all barbers" ON barbers;
DROP POLICY IF EXISTS "Store admin can access own store barbers" ON barbers;

-- super_admin 可访问所有理发师
CREATE POLICY "Super admin can access all barbers" ON barbers
  FOR ALL USING (
    get_current_admin_role() = 'super_admin'
  );

-- store_admin 只能访问自己门店的理发师
CREATE POLICY "Store admin can access own store barbers" ON barbers
  FOR ALL USING (
    store_id = get_current_admin_store_id()
  );

-- ========================================
-- 5. services 表
-- ========================================
ALTER TABLE services ENABLE ROW LEVEL SECURITY;

-- 删除已有策略（如果有）
DROP POLICY IF EXISTS "Super admin can access all services" ON services;
DROP POLICY IF EXISTS "Store admin can access own store services" ON services;

-- super_admin 可访问所有服务
CREATE POLICY "Super admin can access all services" ON services
  FOR ALL USING (
    get_current_admin_role() = 'super_admin'
  );

-- store_admin 只能访问自己门店的服务
CREATE POLICY "Store admin can access own store services" ON services
  FOR ALL USING (
    store_id = get_current_admin_store_id()
  );

-- ========================================
-- 6. service_types 表
-- ========================================
ALTER TABLE service_types ENABLE ROW LEVEL SECURITY;

-- 删除已有策略（如果有）
DROP POLICY IF EXISTS "Super admin can access all service types" ON service_types;
DROP POLICY IF EXISTS "Store admin can access own store service types" ON service_types;
DROP POLICY IF EXISTS "Store admin can access global service types" ON service_types;

-- super_admin 可访问所有服务类型
CREATE POLICY "Super admin can access all service types" ON service_types
  FOR ALL USING (
    get_current_admin_role() = 'super_admin'
  );

-- store_admin 只能访问自己门店的服务类型 + 全局服务类型
CREATE POLICY "Store admin can access own store service types" ON service_types
  FOR ALL USING (
    store_id = get_current_admin_store_id()
    OR store_id IS NULL
  );

-- ========================================
-- 7. recharge_packages 表
-- ========================================
ALTER TABLE recharge_packages ENABLE ROW LEVEL SECURITY;

-- 删除已有策略（如果有）
DROP POLICY IF EXISTS "Super admin can access all packages" ON recharge_packages;
DROP POLICY IF EXISTS "Store admin can access own store packages" ON recharge_packages;

-- super_admin 可访问所有套餐
CREATE POLICY "Super admin can access all packages" ON recharge_packages
  FOR ALL USING (
    get_current_admin_role() = 'super_admin'
  );

-- store_admin 只能访问自己门店的套餐
CREATE POLICY "Store admin can access own store packages" ON recharge_packages
  FOR ALL USING (
    store_id = get_current_admin_store_id()
  );

-- ========================================
-- 8. recharge_records 表
-- ========================================
ALTER TABLE recharge_records ENABLE ROW LEVEL SECURITY;

-- 删除已有策略（如果有）
DROP POLICY IF EXISTS "Super admin can access all recharge records" ON recharge_records;
DROP POLICY IF EXISTS "Store admin can access own store recharge records" ON recharge_records;

-- super_admin 可访问所有充值记录
CREATE POLICY "Super admin can access all recharge records" ON recharge_records
  FOR ALL USING (
    get_current_admin_role() = 'super_admin'
  );

-- store_admin 只能访问自己门店的充值记录
CREATE POLICY "Store admin can access own store recharge records" ON recharge_records
  FOR ALL USING (
    store_id = get_current_admin_store_id()
  );

-- ========================================
-- 9. consumption_records 表
-- ========================================
ALTER TABLE consumption_records ENABLE ROW LEVEL SECURITY;

-- 删除已有策略（如果有）
DROP POLICY IF EXISTS "Super admin can access all consumption records" ON consumption_records;
DROP POLICY IF EXISTS "Store admin can access own store consumption records" ON consumption_records;

-- super_admin 可访问所有消费记录
CREATE POLICY "Super admin can access all consumption records" ON consumption_records
  FOR ALL USING (
    get_current_admin_role() = 'super_admin'
  );

-- store_admin 只能访问自己门店的消费记录
CREATE POLICY "Store admin can access own store consumption records" ON consumption_records
  FOR ALL USING (
    store_id = get_current_admin_store_id()
  );

-- ========================================
-- 10. appointments 表
-- ========================================
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

-- 删除已有策略（如果有）
DROP POLICY IF EXISTS "Super admin can access all appointments" ON appointments;
DROP POLICY IF EXISTS "Store admin can access own store appointments" ON appointments;

-- super_admin 可访问所有预约
CREATE POLICY "Super admin can access all appointments" ON appointments
  FOR ALL USING (
    get_current_admin_role() = 'super_admin'
  );

-- store_admin 只能访问自己门店的预约
CREATE POLICY "Store admin can access own store appointments" ON appointments
  FOR ALL USING (
    store_id = get_current_admin_store_id()
  );

-- ========================================
-- 完成提示
-- ========================================
DO $$
BEGIN
  RAISE NOTICE '✅ Phase 4 RLS 激活 + 策略创建完成';
  RAISE NOTICE '   - 10 个表已激活 RLS';
  RAISE NOTICE '   - 20 个策略已创建（每个表 2 个策略）';
  RAISE NOTICE '   - super_admin 可访问所有数据';
  RAISE NOTICE '   - store_admin 只能访问自己门店的数据';
END;
$$;
