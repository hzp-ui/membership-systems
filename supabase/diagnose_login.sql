-- ========================================
-- 诊断 rpc_admin_login：为什么返回 "Invalid login credentials"？
-- ========================================

-- 1. 查看 rpc_admin_login 的完整定义
SELECT '📊 rpc_admin_login 完整定义:' AS info;
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'rpc_admin_login'
  AND n.nspname = 'public';

-- 2. 查看 admins 表所有数据（包括密码哈希状态）
SELECT '📊 admins 表全部记录:' AS info;
SELECT 
  id,
  username,
  name,
  role,
  store_id,
  CASE WHEN password_hash IS NULL THEN '❌ NULL' ELSE '✅ 有值(' || LENGTH(password_hash) || '字符)' END AS password_status,
  auth_user_id
FROM admins;

-- 3. 手动测试密码验证逻辑
SELECT '📊 手动测试密码验证 (admin / admin123):' AS info;
SELECT 
  username,
  crypt('admin123', password_hash) = password_hash AS match_result
FROM admins
WHERE username = 'admin';

-- 4. 检查是否有其他 login 函数被调用
SELECT '📊 所有包含 login 的函数:' AS info;
SELECT 
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname LIKE '%login%'
  AND n.nspname = 'public';
