
> fix_rpc_security.sql:416:CREATE OR REPLACE FUNCTION rpc_get_services(p_admin_id UUID, p_store_id UUID)
  fix_rpc_security.sql:417:RETURNS JSONB AS $$
  fix_rpc_security.sql:418:DECLARE
  fix_rpc_security.sql:419:  v_actual_store_id UUID;
  fix_rpc_security.sql:420:  v_result JSONB;
  fix_rpc_security.sql:421:BEGIN
  fix_rpc_security.sql:422:  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  fix_rpc_security.sql:423:  
  fix_rpc_security.sql:424:  SELECT COALESCE(jsonb_agg(jsonb_build_object(
  fix_rpc_security.sql:425:    'id', t.id, 'type', t.type, 'name', t.name, 'price', t.price,
  fix_rpc_security.sql:426:    'discount_normal', t.discount_normal, 'discount_silver', t.discount_silver,
  fix_rpc_security.sql:427:    'discount_gold', t.discount_gold, 'discount_diamond', t.discount_diamond,
  fix_rpc_security.sql:428:    'store_id', t.store_id, 'store_name', t.store_name, 'created_at', t.created_at
  fix_rpc_security.sql:429:  )), '[]'::jsonb) INTO v_result
  fix_rpc_security.sql:430:  FROM (
  fix_rpc_security.sql:431:    SELECT sv.id, sv.type, sv.name, sv.price, sv.discount_normal, sv.discount_silver,
  fix_rpc_security.sql:432:           sv.discount_gold, sv.discount_diamond, sv.store_id, sv.created_at, s.name AS stor
e_name
  fix_rpc_security.sql:433:    FROM services sv LEFT JOIN stores s ON sv.store_id = s.id
  fix_rpc_security.sql:434:    WHERE (v_actual_store_id IS NULL OR sv.store_id = v_actual_store_id)
  fix_rpc_security.sql:435:    ORDER BY sv.created_at DESC
  fix_rpc_security.sql:436:  ) t;
  fix_rpc_security.sql:437:  RETURN jsonb_build_object('data', v_result);
  fix_rpc_security.sql:438:END;
  fix_rpc_security.sql:439:$$ LANGUAGE plpgsql SECURITY DEFINER;
  fix_rpc_security.sql:440:
  fix_rpc_security.sql:441:DROP FUNCTION IF EXISTS rpc_create_service;
  fix_rpc_security.sql:442:CREATE OR REPLACE FUNCTION rpc_create_service(p_admin_id UUID, p_type TEXT, p_name TEXT, p_p
rice DECIMAL, p_discount_normal DECIMAL, p_discount_silver DECIMAL, p_discount_gold DECIMAL, p_discount_diamond DECIMAL
, p_store_id UUID)
  fix_rpc_security.sql:443:RETURNS JSONB AS $$
  fix_rpc_security.sql:444:DECLARE
  fix_rpc_security.sql:445:  v_record RECORD;
  fix_rpc_security.sql:446:BEGIN
> fix_rpc_security.sql:988:CREATE OR REPLACE FUNCTION rpc_finance_summary(p_admin_id UUID, p_store_id UUID, p_start_dat
e DATE, p_end_date DATE)
  fix_rpc_security.sql:989:RETURNS JSONB AS $$
  fix_rpc_security.sql:990:DECLARE
  fix_rpc_security.sql:991:  v_actual_store_id UUID;
  fix_rpc_security.sql:992:  v_recharge DECIMAL;
  fix_rpc_security.sql:993:  v_consumption DECIMAL;
  fix_rpc_security.sql:994:BEGIN
  fix_rpc_security.sql:995:  PERFORM rpc_check_admin(p_admin_id);
  fix_rpc_security.sql:996:  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  fix_rpc_security.sql:997:  
  fix_rpc_security.sql:998:  SELECT COALESCE(SUM(amount + bonus), 0) INTO v_recharge FROM recharge_records
  fix_rpc_security.sql:999:  WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
  fix_rpc_security.sql:1000:    AND (p_start_date IS NULL OR created_at >= p_start_date)
  fix_rpc_security.sql:1001:    AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day');
  fix_rpc_security.sql:1002:  
  fix_rpc_security.sql:1003:  SELECT COALESCE(SUM(amount), 0) INTO v_consumption FROM consumption_records
  fix_rpc_security.sql:1004:  WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
  fix_rpc_security.sql:1005:    AND (p_start_date IS NULL OR created_at >= p_start_date)
  fix_rpc_security.sql:1006:    AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day');
  fix_rpc_security.sql:1007:  
  fix_rpc_security.sql:1008:  RETURN jsonb_build_object('data', jsonb_build_object(
  fix_rpc_security.sql:1009:    'recharge_income', v_recharge,
  fix_rpc_security.sql:1010:    'consumption_income', v_consumption,
  fix_rpc_security.sql:1011:    'net_income', v_consumption
  fix_rpc_security.sql:1012:  ));
  fix_rpc_security.sql:1013:END;
  fix_rpc_security.sql:1014:$$ LANGUAGE plpgsql SECURITY DEFINER;
  fix_rpc_security.sql:1015:
  fix_rpc_security.sql:1016:DROP FUNCTION IF EXISTS rpc_daily_statements;
> fix_rpc_security.sql:1017:CREATE OR REPLACE FUNCTION rpc_daily_statements(p_admin_id UUID, p_store_id UUID, p_start_d
ate DATE, p_end_date DATE)
  fix_rpc_security.sql:1018:RETURNS JSONB AS $$
  fix_rpc_security.sql:1019:DECLARE
  fix_rpc_security.sql:1020:  v_actual_store_id UUID;
  fix_rpc_security.sql:1021:  v_result JSONB;
  fix_rpc_security.sql:1022:BEGIN
  fix_rpc_security.sql:1023:  PERFORM rpc_check_admin(p_admin_id);
  fix_rpc_security.sql:1024:  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  fix_rpc_security.sql:1025:  
  fix_rpc_security.sql:1026:  SELECT COALESCE(jsonb_agg(jsonb_build_object(
  fix_rpc_security.sql:1027:    'date', d.dt,
  fix_rpc_security.sql:1028:    'recharge_count', COALESCE(r.cnt, 0),
  fix_rpc_security.sql:1029:    'recharge_amount', COALESCE(r.total, 0),
  fix_rpc_security.sql:1030:    'consumption_count', COALESCE(c.cnt, 0),
  fix_rpc_security.sql:1031:    'consumption_amount', COALESCE(c.total, 0)
  fix_rpc_security.sql:1032:  )),'[]'::JSONB)
  fix_rpc_security.sql:1033:  INTO v_result
  fix_rpc_security.sql:1034:  FROM generate_series(
  fix_rpc_security.sql:1035:    COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days'),
  fix_rpc_security.sql:1036:    COALESCE(p_end_date, CURRENT_DATE),
  fix_rpc_security.sql:1037:    INTERVAL '1 day'
  fix_rpc_security.sql:1038:  ) d(dt)
  fix_rpc_security.sql:1039:  LEFT JOIN (
  fix_rpc_security.sql:1040:    SELECT DATE(created_at) AS dt, COUNT(*) AS cnt, SUM(amount + bonus) AS total
  fix_rpc_security.sql:1041:    FROM recharge_records WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
  fix_rpc_security.sql:1042:    GROUP BY DATE(created_at)
  fix_rpc_security.sql:1043:  ) r ON d.dt = r.dt
  fix_rpc_security.sql:1044:  LEFT JOIN (
  fix_rpc_security.sql:1045:    SELECT DATE(created_at) AS dt, COUNT(*) AS cnt, SUM(amount) AS total
  fix_rpc_security.sql:1046:    FROM consumption_records WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_
id)
  fix_rpc_security.sql:1047:    GROUP BY DATE(created_at)
> fix_rpc_security.sql:1058:CREATE OR REPLACE FUNCTION rpc_get_service_types(p_admin_id UUID, p_store_id UUID)
  fix_rpc_security.sql:1059:RETURNS JSONB AS $$
  fix_rpc_security.sql:1060:DECLARE
  fix_rpc_security.sql:1061:  v_actual_store_id UUID;
  fix_rpc_security.sql:1062:  v_result JSONB;
  fix_rpc_security.sql:1063:BEGIN
  fix_rpc_security.sql:1064:  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  fix_rpc_security.sql:1065:  
  fix_rpc_security.sql:1066:  SELECT COALESCE(jsonb_agg(jsonb_build_object(
  fix_rpc_security.sql:1067:    'id', t.id, 'name', t.name, 'store_id', t.store_id, 'is_global', t.is_global, 'created_
at', t.created_at
  fix_rpc_security.sql:1068:  ) ORDER BY t.is_global DESC, t.name), '[]'::jsonb) INTO v_result
  fix_rpc_security.sql:1069:  FROM (
  fix_rpc_security.sql:1070:    SELECT st.id, st.name, st.store_id, st.created_at,
  fix_rpc_security.sql:1071:           CASE WHEN st.store_id IS NULL THEN true ELSE false END AS is_global
  fix_rpc_security.sql:1072:    FROM service_types st
  fix_rpc_security.sql:1073:    WHERE (v_actual_store_id IS NULL OR st.store_id IS NULL OR st.store_id = v_actual_store
_id)
  fix_rpc_security.sql:1074:  ) t;
  fix_rpc_security.sql:1075:  RETURN jsonb_build_object('data', v_result);
  fix_rpc_security.sql:1076:END;
  fix_rpc_security.sql:1077:$$ LANGUAGE plpgsql SECURITY DEFINER;
  fix_rpc_security.sql:1078:
  fix_rpc_security.sql:1079:DROP FUNCTION IF EXISTS rpc_create_service_type;
  fix_rpc_security.sql:1080:CREATE OR REPLACE FUNCTION rpc_create_service_type(p_admin_id UUID, p_name TEXT, p_store_id
 UUID)
  fix_rpc_security.sql:1081:RETURNS JSONB AS $$
  fix_rpc_security.sql:1082:DECLARE
  fix_rpc_security.sql:1083:  v_role TEXT;
  fix_rpc_security.sql:1084:  v_admin_store_id UUID;
  fix_rpc_security.sql:1085:  v_record RECORD;
  fix_rpc_security.sql:1086:BEGIN
  fix_rpc_security.sql:1087:  SELECT role, store_id INTO v_role, v_admin_store_id FROM admins WHERE id = p_admin_id;
  fix_rpc_security.sql:1088:  IF NOT FOUND THEN RETURN jsonb_build_object('error', '无效的管理员身份'); END IF;
> fix_rpc_security.sql:1142:CREATE OR REPLACE FUNCTION rpc_get_stores(p_admin_id UUID, p_store_id UUID)
  fix_rpc_security.sql:1143:RETURNS JSONB AS $$
  fix_rpc_security.sql:1144:DECLARE
  fix_rpc_security.sql:1145:  v_actual_store_id UUID;
  fix_rpc_security.sql:1146:  v_result JSONB;
  fix_rpc_security.sql:1147:BEGIN
  fix_rpc_security.sql:1148:  v_actual_store_id := rpc_enforce_store_filter(p_admin_id, p_store_id);
  fix_rpc_security.sql:1149:
  fix_rpc_security.sql:1150:  IF v_actual_store_id IS NOT NULL THEN
  fix_rpc_security.sql:1151:    SELECT to_jsonb(s) INTO v_result FROM stores s WHERE id = v_actual_store_id;
  fix_rpc_security.sql:1152:    RETURN jsonb_build_object('data', v_result);
  fix_rpc_security.sql:1153:  END IF;
  fix_rpc_security.sql:1154:
  fix_rpc_security.sql:1155:  SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO v_result
  fix_rpc_security.sql:1156:  FROM (SELECT * FROM stores ORDER BY created_at DESC) t;
  fix_rpc_security.sql:1157:  RETURN jsonb_build_object('data', v_result);
  fix_rpc_security.sql:1158:END;
  fix_rpc_security.sql:1159:$$ LANGUAGE plpgsql SECURITY DEFINER;
  fix_rpc_security.sql:1160:
  fix_rpc_security.sql:1161:
  fix_rpc_security.sql:1162:-- =============================================
  fix_rpc_security.sql:1163:-- 完成
  fix_rpc_security.sql:1164:-- =============================================
  fix_rpc_security.sql:1165:SELECT '✅ RPC 权限安全加固完成！所有函数已添加管理员身份校验和门店隔离。' AS result;
  fix_rpc_security.sql:1166:
  fix_rpc_security.sql:1167:
  fix_rpc_security.sql:1168:


