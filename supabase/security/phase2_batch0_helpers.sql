-- Phase 2 Batch 0: 辅助函数
-- 执行方式：Supabase Dashboard → SQL Editor → 粘贴 → Run

CREATE OR REPLACE FUNCTION rpc_get_current_admin()
RETURNS RECORD AS $$
DECLARE
  v_result RECORD;
BEGIN
  SELECT id, role, store_id INTO v_result FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION '未认证或非管理员身份'; END IF;
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_get_current_member()
RETURNS RECORD AS $$
DECLARE
  v_result RECORD;
BEGIN
  SELECT id, phone, name, level, points, balance, store_id, status INTO v_result
  FROM members WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION '未认证或非会员身份'; END IF;
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_check_store_access_v2(p_target_store_id UUID)
RETURNS VOID AS $$
DECLARE
  v_role TEXT;
  v_store_id UUID;
BEGIN
  SELECT role, store_id INTO v_role, v_store_id FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION '无效的管理员身份'; END IF;
  IF v_role = 'store_admin' THEN
    IF v_store_id IS NULL THEN RAISE EXCEPTION '店长未绑定门店'; END IF;
    IF p_target_store_id IS NOT NULL AND p_target_store_id != v_store_id THEN
      RAISE EXCEPTION '无权操作其他门店数据';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_enforce_store_filter_v2(p_store_id UUID)
RETURNS UUID AS $$
DECLARE
  v_role TEXT;
  v_store_id UUID;
BEGIN
  SELECT role, store_id INTO v_role, v_store_id FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION '无效的管理员身份'; END IF;
  IF v_role = 'store_admin' THEN RETURN v_store_id; END IF;
  RETURN p_store_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_get_current_admin_info()
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
BEGIN
  SELECT a.id, a.username, a.name, a.phone, a.role, a.store_id
  INTO v_admin FROM admins a WHERE a.auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未找到管理员信息'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_admin));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rpc_get_current_member_info()
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
BEGIN
  SELECT m.id, m.phone, m.name, m.level, m.points, m.balance, m.store_id
  INTO v_member FROM members m WHERE m.auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未找到会员信息'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_member));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT '✅ Phase 2 Batch 0: 辅助函数完成' AS result;
