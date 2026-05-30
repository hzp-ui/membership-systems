-- ========================================
-- 诊断：rpc_admin_login 和 rpc_get_members 完整定义
-- 目的: 确认数据隔离问题根因
-- 日期: 2026-05-28
-- ========================================

SELECT '===== rpc_admin_login =====' AS info;
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'rpc_admin_login' AND n.nspname = 'public';

SELECT '' AS separator;

SELECT '===== rpc_get_members =====' AS info;
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'rpc_get_members' AND n.nspname = 'public';

SELECT '' AS separator;

SELECT '===== rpc_get_stores =====' AS info;
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'rpc_get_stores' AND n.nspname = 'public';
