-- 数据库性能优化索引
-- 执行时间：< 1秒

-- ========== 1. login_attempts 限流查询优化 ==========
-- 问题：限流查询 WHERE phone = ? AND success = false 每次全表扫
CREATE INDEX IF NOT EXISTS idx_login_attempts_phone_success ON login_attempts(phone, success);
-- 清理过期数据（可选，保留最近7天即可）
DELETE FROM login_attempts WHERE attempt_time < now() - interval '7 days';

-- ========== 2. audit_logs 审计查询优化 ==========
-- 问题：按 user_id 和 created_at 排序查询审计记录
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_created ON audit_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC);

-- ========== 3. members 会员列表优化 ==========
-- 问题：store_admin 查询自己门店会员，store_id 过滤频繁
CREATE INDEX IF NOT EXISTS idx_members_store_id ON members(store_id);
CREATE INDEX IF NOT EXISTS idx_members_phone ON members(phone);

-- ========== 4. consumptions 消费记录优化 ==========
-- 问题：按门店/会员/时间范围查询消费记录
CREATE INDEX IF NOT EXISTS idx_consumptions_store_created ON consumptions(store_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_consumptions_member_created ON consumptions(member_id, created_at DESC);

-- ========== 5. recharges 充值记录优化 ==========
-- 问题：按门店/会员/时间范围查询充值记录
CREATE INDEX IF NOT EXISTS idx_recharges_store_created ON recharges(store_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_recharges_member_created ON recharges(member_id, created_at DESC);

-- ========== 6. appointments 预约列表优化 ==========
-- 问题：按门店查询预约记录
CREATE INDEX IF NOT EXISTS idx_appointments_store_time ON appointments(store_id, appointment_time DESC);

-- ========== 7. recharge_packages 套餐查询优化 ==========
-- 问题：按门店查询可用套餐
CREATE INDEX IF NOT EXISTS idx_packages_store_status ON recharge_packages(store_id, status);

-- ========== 验证索引创建 ==========
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan AS scan_count
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
