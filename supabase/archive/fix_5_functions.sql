-- 最小修复：只重建报错的 4 个函数 + 依赖
-- 在 Supabase Dashboard SQL Editor 执行此文件

-- 辅助函数（幂等，可重复执行）
CREATE OR REPLACE FUNCTION rpc_check_admin(p_admin_id UUID)
RETURNS VOID AS $$
DECLARE
  v_role TEXT;
BEGIN
  SELECT role INTO v_role FROM admins WHERE id = p_admin_id;
  IF NOT FOUND THEN RAISE EXCEPTION '无效的管理员身份'; END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rpc_enforce_store_filter(p_admin_id UUID, p_store_id UUID)
RETURNS UUID AS $$
DECLARE
  v_role TEXT;
  v_store_id UUID;
BEGIN
  SELECT role, store_id INTO v_role, v_store_id FROM admins WHERE id = p_admin_id;
  IF NOT FOUND THEN RAISE EXCEPTION '无效的管理员身份'; END IF;
  IF v_role = 'store_admin' THEN RETURN v_store_id; END IF;
  RETURN p_store_id;
END;
$$ LANGUAGE plpgsql;

-- 1. 服务项目列表
DROP FUNCTION IF EXISTS rpc_get_services(UUID, UUID);
CREATE OR REPLACE FUNCTION rpc_get_services(p_admin_id UUID, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'type', t.type, 'name', t.name, 'price', t.price,
    'discount_normal', t.discount_normal, 'discount_silver', t.discount_silver,
    'discount_gold', t.discount_gold, 'discount_diamond', t.discount_diamond,
    'store_id', t.store_id, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT sv.id, sv.type, sv.name, sv.price, sv.discount_normal, sv.discount_silver,
           sv.discount_gold, sv.discount_diamond, sv.store_id, sv.created_at, s.name AS store_name
    FROM services sv LEFT JOIN stores s ON sv.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR sv.store_id = v_actual_store_id)
    ORDER BY sv.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. 服务类型列表
DROP FUNCTION IF EXISTS rpc_get_service_types(UUID, UUID);
CREATE OR REPLACE FUNCTION rpc_get_service_types(p_admin_id UUID, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'name', t.name, 'store_id', t.store_id, 'is_global', t.is_global, 'created_at', t.created_at
  ) ORDER BY t.is_global DESC, t.name), '[]'::jsonb) INTO v_result
  FROM (
    SELECT st.id, st.name, st.store_id, st.created_at,
           CASE WHEN st.store_id IS NULL THEN true ELSE false END AS is_global
    FROM service_types st
    WHERE (v_actual_store_id IS NULL OR st.store_id IS NULL OR st.store_id = v_actual_store_id)
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 财务汇总
DROP FUNCTION IF EXISTS rpc_finance_summary(UUID, UUID, DATE, DATE);
CREATE OR REPLACE FUNCTION rpc_finance_summary(p_admin_id UUID, p_store_id UUID, p_start_date DATE, p_end_date DATE)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_recharge DECIMAL;
  v_consumption DECIMAL;
BEGIN
  PERFORM rpc_check_admin(p_admin_id);
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  SELECT COALESCE(SUM(amount + bonus), 0) INTO v_recharge FROM recharge_records
  WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day');
  SELECT COALESCE(SUM(amount), 0) INTO v_consumption FROM consumption_records
  WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day');
  RETURN jsonb_build_object('data', jsonb_build_object(
    'recharge_income', v_recharge,
    'consumption_income', v_consumption,
    'net_income', v_consumption - v_recharge
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. 每日流水
DROP FUNCTION IF EXISTS rpc_daily_statements(UUID, UUID, DATE, DATE);
CREATE OR REPLACE FUNCTION rpc_daily_statements(p_admin_id UUID, p_store_id UUID, p_start_date DATE, p_end_date DATE)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  PERFORM rpc_check_admin(p_admin_id);
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'date', d.dt,
    'recharge_count', COALESCE(r.cnt, 0),
    'recharge_amount', COALESCE(r.total, 0),
    'consumption_count', COALESCE(c.cnt, 0),
    'consumption_amount', COALESCE(c.total, 0)
  )),'[]'::JSONB) INTO v_result
  FROM generate_series(
    COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days'),
    COALESCE(p_end_date, CURRENT_DATE),
    INTERVAL '1 day'
  ) d(dt)
  LEFT JOIN (
    SELECT DATE(created_at) AS dt, COUNT(*) AS cnt, SUM(amount + bonus) AS total
    FROM recharge_records WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
    GROUP BY DATE(created_at)
  ) r ON d.dt = r.dt
  LEFT JOIN (
    SELECT DATE(created_at) AS dt, COUNT(*) AS cnt, SUM(amount) AS total
    FROM consumption_records WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
    GROUP BY DATE(created_at)
  ) c ON d.dt = c.dt;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. 门店列表（补漏）
DROP FUNCTION IF EXISTS rpc_get_stores(UUID, UUID);
CREATE OR REPLACE FUNCTION rpc_get_stores(p_admin_id UUID, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  IF v_actual_store_id IS NOT NULL THEN
    SELECT to_jsonb(s) INTO v_result FROM stores s WHERE id = v_actual_store_id;
    RETURN jsonb_build_object('data', v_result);
  END IF;
  SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO v_result
  FROM (SELECT * FROM stores ORDER BY created_at DESC) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT '✅ 5 个函数修复完成' AS result;
