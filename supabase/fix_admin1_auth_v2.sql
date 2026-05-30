-- ========================================
-- 为 admin1 补建 auth.users 记录（基于实际表结构）
-- ========================================

-- 1. 先获取 admin1 的 id
DO $$
DECLARE
  v_admin_id UUID;
  v_auth_uid UUID;
BEGIN
  SELECT id INTO v_admin_id FROM admins WHERE username = 'admin1';
  
  IF v_admin_id IS NULL THEN
    RAISE NOTICE '❌ admin1 不存在于 admins 表';
    RETURN;
  END IF;

  -- 2. 在 auth.users 中创建记录（只填必填/关键列，其余用默认值）
  INSERT INTO auth.users (
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'admin1@membership.internal',
    crypt('admin123', gen_salt('bf')),
    NOW(),
    '{"provider":"email","name":"admin1"}'::jsonb,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_auth_uid;

  -- 3. 更新 admins 表的 auth_user_id
  UPDATE admins SET auth_user_id = v_auth_uid WHERE id = v_admin_id;

  RAISE NOTICE '✅ ================================';
  RAISE NOTICE '✅ admin1 auth.users 记录已创建';
  RAISE NOTICE '✅ auth_user_id: %', v_auth_uid;
  RAISE NOTICE '✅ 邮箱: admin1@membership.internal';
  RAISE NOTICE '✅ 密码: admin123';
  RAISE NOTICE '✅ 请用 admin1/admin123 登录测试';
  RAISE NOTICE '✅ ================================';
END;
$$;

-- 4. 验证
SELECT 
  a.username,
  a.auth_user_id,
  au.email,
  CASE WHEN au.id IS NOT NULL THEN '✅ 已关联' ELSE '❌ 缺失' END AS status
FROM admins a
LEFT JOIN auth.users au ON a.auth_user_id = au.id
WHERE a.username = 'admin1';
