-- Phase 3: 消灭 Critical — 明文密码 + 密码策略
-- 执行方式：Supabase Dashboard → SQL Editor → 粘贴 → Run

-- 1. 强制迁移所有非 bcrypt 密码
UPDATE admins SET password_hash = crypt('Ch@ngeme' || id::text, gen_salt('bf', 10))
WHERE password_hash NOT LIKE '$2%';

UPDATE members SET password_hash = crypt('Ch@ngeme' || id::text, gen_salt('bf', 10))
WHERE password_hash NOT LIKE '$2%';

-- 2. rpc_admin_login 删除明文回退
CREATE OR REPLACE FUNCTION rpc_admin_login(p_username VARCHAR, p_password VARCHAR)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
BEGIN
  SELECT a.id, a.username, a.name, a.phone, a.role, a.store_id, a.password_hash, a.auth_user_id
  INTO v_admin FROM admins a WHERE a.username = p_username;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '用户名或密码错误'); END IF;
  IF NOT (crypt(p_password, v_admin.password_hash) = v_admin.password_hash) THEN
    RETURN jsonb_build_object('error', '用户名或密码错误');
  END IF;
  RETURN jsonb_build_object('data', jsonb_build_object(
    'id', v_admin.id, 'username', v_admin.username, 'name', v_admin.name,
    'phone', v_admin.phone, 'role', v_admin.role, 'store_id', v_admin.store_id
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. rpc_member_login 删除明文回退
CREATE OR REPLACE FUNCTION rpc_member_login(p_phone VARCHAR, p_password VARCHAR, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
BEGIN
  SELECT m.id, m.phone, m.name, m.level, m.points, m.balance, m.store_id, m.password_hash, m.auth_user_id
  INTO v_member FROM members m WHERE m.phone = p_phone AND m.store_id = p_store_id AND m.status = 'active';
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '手机号或密码错误'); END IF;
  IF NOT (crypt(p_password, v_member.password_hash) = v_member.password_hash) THEN
    RETURN jsonb_build_object('error', '手机号或密码错误');
  END IF;
  RETURN jsonb_build_object('data', jsonb_build_object(
    'id', v_member.id, 'phone', v_member.phone, 'name', v_member.name,
    'level', v_member.level, 'points', v_member.points,
    'balance', v_member.balance, 'store_id', v_member.store_id
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. 修改密码函数
CREATE OR REPLACE FUNCTION rpc_change_password(p_old_password TEXT, p_new_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_member RECORD;
BEGIN
  IF LENGTH(p_new_password) < 8 THEN
    RETURN jsonb_build_object('error', '新密码至少8位');
  END IF;
  SELECT id, password_hash INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF FOUND THEN
    IF NOT (crypt(p_old_password, v_admin.password_hash) = v_admin.password_hash) THEN
      RETURN jsonb_build_object('error', '旧密码错误');
    END IF;
    UPDATE admins SET password_hash = crypt(p_new_password, gen_salt('bf', 10)) WHERE id = v_admin.id;
    UPDATE auth.users SET encrypted_password = crypt(p_new_password, gen_salt('bf', 10)) WHERE id = auth.uid();
    RETURN jsonb_build_object('data', jsonb_build_object('success', true));
  END IF;
  SELECT id, password_hash INTO v_member FROM members WHERE auth_user_id = auth.uid();
  IF FOUND THEN
    IF NOT (crypt(p_old_password, v_member.password_hash) = v_member.password_hash) THEN
      RETURN jsonb_build_object('error', '旧密码错误');
    END IF;
    UPDATE members SET password_hash = crypt(p_new_password, gen_salt('bf', 10)) WHERE id = v_member.id;
    UPDATE auth.users SET encrypted_password = crypt(p_new_password, gen_salt('bf', 10)) WHERE id = auth.uid();
    RETURN jsonb_build_object('data', jsonb_build_object('success', true));
  END IF;
  RETURN jsonb_build_object('error', '未认证');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT '✅ Phase 3: 明文密码回退已删除，密码策略已加强' AS result;
