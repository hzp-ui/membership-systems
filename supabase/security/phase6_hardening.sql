-- Phase 6: 加固 — 暴力破解防护 + 审计日志
-- 执行方式：Supabase Dashboard → SQL Editor → 粘贴 → Run

-- 1. 登录失败计数表
CREATE TABLE IF NOT EXISTS login_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier TEXT NOT NULL,
  ip_address INET,
  success BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_login_attempts_id_time ON login_attempts(identifier, created_at DESC);

-- 2. 清理 24h 前的记录（可定期执行或用 pg_cron）
DELETE FROM login_attempts WHERE created_at < now() - INTERVAL '24 hours';

-- 3. rpc_admin_login 添加暴力破解防护（需在 Phase 3 基础上重写）
CREATE OR REPLACE FUNCTION rpc_admin_login(p_username VARCHAR, p_password VARCHAR)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_fail_count INT;
BEGIN
  -- 暴力破解防护：15分钟内5次失败则锁定
  SELECT COUNT(*) INTO v_fail_count FROM login_attempts
  WHERE identifier = p_username AND success = false
    AND created_at > now() - INTERVAL '15 minutes';
  IF v_fail_count >= 5 THEN
    RETURN jsonb_build_object('error', '登录失败次数过多，请15分钟后重试');
  END IF;
  
  SELECT a.id, a.username, a.name, a.phone, a.role, a.store_id, a.password_hash, a.auth_user_id
  INTO v_admin FROM admins a WHERE a.username = p_username;
  IF NOT FOUND THEN
    INSERT INTO login_attempts (identifier, success) VALUES (p_username, false);
    RETURN jsonb_build_object('error', '用户名或密码错误');
  END IF;
  
  IF NOT (crypt(p_password, v_admin.password_hash) = v_admin.password_hash) THEN
    INSERT INTO login_attempts (identifier, success) VALUES (p_username, false);
    RETURN jsonb_build_object('error', '用户名或密码错误');
  END IF;
  
  INSERT INTO login_attempts (identifier, success) VALUES (p_username, true);
  RETURN jsonb_build_object('data', jsonb_build_object(
    'id', v_admin.id, 'username', v_admin.username, 'name', v_admin.name,
    'phone', v_admin.phone, 'role', v_admin.role, 'store_id', v_admin.store_id
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. rpc_member_login 添加暴力破解防护
CREATE OR REPLACE FUNCTION rpc_member_login(p_phone VARCHAR, p_password VARCHAR, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
  v_fail_count INT;
  v_identifier TEXT;
BEGIN
  v_identifier := p_phone || '@' || COALESCE(p_store_id::text, '');
  
  SELECT COUNT(*) INTO v_fail_count FROM login_attempts
  WHERE identifier = v_identifier AND success = false
    AND created_at > now() - INTERVAL '15 minutes';
  IF v_fail_count >= 5 THEN
    RETURN jsonb_build_object('error', '登录失败次数过多，请15分钟后重试');
  END IF;
  
  SELECT m.id, m.phone, m.name, m.level, m.points, m.balance, m.store_id, m.password_hash, m.auth_user_id
  INTO v_member FROM members m WHERE m.phone = p_phone AND m.store_id = p_store_id AND m.status = 'active';
  IF NOT FOUND THEN
    INSERT INTO login_attempts (identifier, success) VALUES (v_identifier, false);
    RETURN jsonb_build_object('error', '手机号或密码错误');
  END IF;
  
  IF NOT (crypt(p_password, v_member.password_hash) = v_member.password_hash) THEN
    INSERT INTO login_attempts (identifier, success) VALUES (v_identifier, false);
    RETURN jsonb_build_object('error', '手机号或密码错误');
  END IF;
  
  INSERT INTO login_attempts (identifier, success) VALUES (v_identifier, true);
  RETURN jsonb_build_object('data', jsonb_build_object(
    'id', v_member.id, 'phone', v_member.phone, 'name', v_member.name,
    'level', v_member.level, 'points', v_member.points,
    'balance', v_member.balance, 'store_id', v_member.store_id
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT '✅ Phase 6: 暴力破解防护已添加' AS result;
