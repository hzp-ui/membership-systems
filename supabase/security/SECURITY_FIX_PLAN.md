# 理发店会员管理系统 — 安全修复方案

> 项目：理发店会员管理系统  
> 前端：`E:\学习\会员系统\MmbershipWeb`（React + Vite + TypeScript + Ant Design）  
> 后端：Supabase PostgreSQL RPC（`yknvmkzgsoirjfchabov`）  
> 生产地址：https://membership-system-nine.vercel.app  
> 编写日期：2026-05-23  

---

## 漏洞总览

| # | 级别 | 漏洞 | 修复阶段 |
|---|------|------|----------|
| 1 | Critical | 身份验证形同虚设（p_admin_id 客户端可伪造） | Phase 1+2 |
| 2 | Critical | IDOR 越权（伪造 ID 可操作任意门店） | Phase 2 |
| 3 | Critical | RPC 裸露公网（anon key + RLS USING(true)） | Phase 4 |
| 4 | Critical | 明文密码回退路径 | Phase 3 |
| 5 | High | 无暴力破解防护 | Phase 6 |
| 6 | High | 登录函数无 p_admin_id 校验 | Phase 2 |
| 7 | High | 密码策略弱 | Phase 3 |
| 8 | High | 会员注册无权限控制 | Phase 2 |
| 9 | High | 会话永不过期 | Phase 5 |
| 10 | Medium | CORS 宽松 | Phase 6 |
| 11 | Medium | RLS 实质禁用 | Phase 4 |
| 12 | Medium | localStorage 存储 admin 对象 | Phase 5 |
| 13 | Medium | audit_logs 表无写入 | Phase 6 |
| 14 | Medium | 充值/消费无二次确认 | Phase 6 |
| 15 | Low | 枚举类型残留 | Phase 3 |
| 16 | Low | seed 密码硬编码 | Phase 3 |

**根因：`p_admin_id` 从客户端传入 = 没有认证。所有漏洞从此长出。**

---

## Phase 1: 认证基建

### 目标
引入 Supabase Auth 原生 JWT 认证，建立"登录 → JWT → RPC 验证身份"的完整链路。

### 修复思路

1. **admins 表加 `auth_user_id` 列**，关联 `auth.users(id)`
2. **members 表加 `auth_user_id` 列**，关联 `auth.users(id)`
3. **Supabase Dashboard 关闭 email confirmation**（Auth → Settings → 关闭 "Enable email confirmations"）
4. **用 `username@membership.internal` 虚拟邮箱**绕过 Supabase Auth 的 email 唯一约束，不需要真实邮箱
5. **写迁移脚本**，用 service_role key 批量为已有 admin/member 创建 `auth.users` 记录，并回填 `auth_user_id`

### 数据库变更 SQL

```sql
-- Phase 1: 认证基建
-- 执行方式：Supabase Dashboard → SQL Editor → 粘贴 → Run

-- 1. admins 表加 auth_user_id
ALTER TABLE admins ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_admins_auth_user ON admins(auth_user_id);

-- 2. members 表加 auth_user_id
ALTER TABLE members ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_members_auth_user ON members(auth_user_id);
```

### 迁移脚本

文件：`MembershipSystem/supabase/migrate_to_auth.mjs`

```js
import { createClient } from '@supabase/supabase-js'

// ⚠️ service_role key 从 Dashboard → Settings → API 取，执行后删除此脚本
const SUPABASE_URL = 'https://yknvmkzgsoirjfchabov.supabase.co'
const SERVICE_ROLE_KEY = 'YOUR_SERVICE_ROLE_KEY' // 替换为实际值

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false }
})

async function migrateAdmins() {
  const { data: admins, error } = await supabase.from('admins').select('*')
  if (error) { console.error('查询管理员失败:', error); return }

  for (const admin of admins) {
    const email = `${admin.username}@membership.internal`

    // 检查是否已存在 auth.users
    const { data: existing } = await supabase.auth.admin.listUsers()
    const found = existing?.users?.find(u => u.email === email)
    if (found) {
      console.log(`已存在: ${admin.username} → ${found.id}`)
      await supabase.from('admins').update({ auth_user_id: found.id }).eq('id', admin.id)
      continue
    }

    // 创建 auth.users，用临时密码（首次登录后强制修改）
    const { data: user, error: createErr } = await supabase.auth.admin.createUser({
      email,
      password: 'TempPass_' + admin.id.toString().slice(0, 8) + '!',
      email_confirm: true,
    })
    if (createErr) { console.error(`创建失败: ${admin.username}`, createErr); continue }

    await supabase.from('admins').update({ auth_user_id: user.id }).eq('id', admin.id)
    console.log(`迁移成功: ${admin.username} → ${user.id}`)
  }
}

async function migrateMembers() {
  const { data: members, error } = await supabase.from('members').select('*')
  if (error) { console.error('查询会员失败:', error); return }

  for (const member of members) {
    const email = `${member.phone}_${member.store_id}@membership.internal`

    const { data: user, error: createErr } = await supabase.auth.admin.createUser({
      email,
      password: 'MemberTemp_' + member.id.toString().slice(0, 8) + '!',
      email_confirm: true,
    })
    if (createErr) {
      if (createErr.message?.includes('already been registered')) {
        console.log(`已注册: ${member.phone}`)
        continue
      }
      console.error(`创建失败: ${member.phone}`, createErr)
      continue
    }

    await supabase.from('members').update({ auth_user_id: user.id }).eq('id', member.id)
    console.log(`迁移成功: ${member.phone} → ${user.id}`)
  }
}

// 先迁管理员，再迁会员
await migrateAdmins()
await migrateMembers()
console.log('✅ 迁移完成')
```

### 验收标准

- [ ] admins 表有 `auth_user_id` 列，所有现有 admin 已关联 `auth.users` 记录
- [ ] members 表有 `auth_user_id` 列，所有现有 member 已关联 `auth.users` 记录
- [ ] Dashboard → Authentication → Users 中能看到对应的用户记录
- [ ] Supabase Dashboard email confirmation 已关闭
- [ ] 迁移脚本执行后删除 service_role key，不留在代码中

---

## Phase 2: RPC 函数改造（移除 p_admin_id）

### 目标
所有 RPC 函数通过 `auth.uid()` 验证身份，移除客户端传入的 `p_admin_id` 参数。

### 修复思路

1. **新增辅助函数 `rpc_get_current_admin()`**：通过 `auth.uid()` 查 `admins.auth_user_id` 获取当前管理员信息
2. **新增辅助函数 `rpc_get_current_member()`**：同理获取当前会员信息
3. **所有 RPC 函数移除 `p_admin_id` 参数**，内部改调 `rpc_get_current_admin()`
4. **登录函数改造**：前端改用 `supabase.auth.signInWithPassword()`，登录成功后再调 `rpc_get_current_admin_info()` 取业务信息
5. **会员注册改造**：先 `supabase.auth.signUp()`，再写 members 表

### 数据库变更 SQL

文件：`MembershipSystem/supabase/phase2_rpc_auth.sql`

```sql
-- Phase 2: RPC 函数改造 — 移除 p_admin_id，改用 auth.uid()

-- =============================================
-- 辅助函数：获取当前管理员身份
-- =============================================
CREATE OR REPLACE FUNCTION rpc_get_current_admin()
RETURNS RECORD AS $$
DECLARE
  v_result RECORD;
BEGIN
  SELECT id, role, store_id INTO v_result
  FROM admins WHERE auth_user_id = auth.uid();
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '未认证或非管理员身份';
  END IF;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 辅助函数：获取当前会员身份
-- =============================================
CREATE OR REPLACE FUNCTION rpc_get_current_member()
RETURNS RECORD AS $$
DECLARE
  v_result RECORD;
BEGIN
  SELECT id, phone, name, level, points, balance, store_id, status INTO v_result
  FROM members WHERE auth_user_id = auth.uid();
  
  IF NOT FOUND THEN
    RAISE EXCEPTION '未认证或非会员身份';
  END IF;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 辅助函数：校验门店归属（基于 auth.uid()）
-- =============================================
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

-- =============================================
-- 辅助函数：强制门店过滤（基于 auth.uid()）
-- =============================================
CREATE OR REPLACE FUNCTION rpc_enforce_store_filter_v2(p_store_id UUID)
RETURNS UUID AS $$
DECLARE
  v_role TEXT;
  v_store_id UUID;
BEGIN
  SELECT role, store_id INTO v_role, v_store_id FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION '无效的管理员身份'; END IF;
  
  IF v_role = 'store_admin' THEN RETURN v_store_id; END IF;
  RETURN p_store_id; -- super_admin 用传入的
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 登录后取管理员信息（替代 rpc_admin_login 的业务信息返回）
-- =============================================
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

-- =============================================
-- 登录后取会员信息
-- =============================================
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
```

**以下为所有 RPC 函数的改造（移除 p_admin_id），分批提交到 Supabase Dashboard：**

### 第 1 批：管理员 CRUD

```sql
-- 第 1 批：管理员 CRUD（移除 p_admin_id）

DROP FUNCTION IF EXISTS rpc_get_admins;
CREATE OR REPLACE FUNCTION rpc_get_admins(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  SELECT id, role, store_id INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  
  IF v_admin.role = 'store_admin' THEN
    v_actual_store_id := v_admin.store_id;
  ELSE
    v_actual_store_id := p_store_id;
  END IF;
  
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'username', t.username, 'name', t.name,
    'phone', t.phone, 'role', t.role, 'store_id', t.store_id,
    'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT a.id, a.username, a.name, a.phone, a.role, a.store_id, a.created_at, s.name AS store_name
    FROM admins a LEFT JOIN stores s ON a.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR a.store_id = v_actual_store_id)
    ORDER BY a.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_create_admin;
CREATE OR REPLACE FUNCTION rpc_create_admin(p_username TEXT, p_password TEXT, p_name TEXT, p_phone TEXT, p_role TEXT, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_auth_user UUID;
  v_record RECORD;
BEGIN
  SELECT id, role, store_id INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  IF v_admin.role != 'super_admin' THEN
    RETURN jsonb_build_object('error', '只有超级管理员才能创建管理员账号');
  END IF;
  IF p_role = 'store_admin' AND p_store_id IS NULL THEN
    RETURN jsonb_build_object('error', '店长必须绑定门店');
  END IF;
  
  -- 先在 auth.users 创建账号
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, confirmation_token, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, aud, role)
  VALUES (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000000',
    p_username || '@membership.internal',
    crypt(p_password, gen_salt('bf', 10)),
    now(),
    encode(gen_random_bytes(32), 'hex'),
    '{"provider":"email","providers":["email"]}',
    '{}',
    now(), now(), 'authenticated', 'authenticated'
  ) RETURNING id INTO v_auth_user;
  
  INSERT INTO admins (username, password_hash, name, phone, role, store_id, auth_user_id)
  VALUES (p_username, crypt(p_password, gen_salt('bf', 10)), p_name, NULLIF(p_phone, ''), NULLIF(p_role, ''), p_store_id, v_auth_user)
  RETURNING id, username, name, phone, role, store_id, created_at INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_update_admin;
CREATE OR REPLACE FUNCTION rpc_update_admin(p_id UUID, p_name TEXT, p_phone TEXT, p_role TEXT, p_store_id UUID, p_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_record RECORD;
BEGIN
  SELECT id, role INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  IF v_admin.role != 'super_admin' THEN
    RETURN jsonb_build_object('error', '只有超级管理员才能修改管理员信息');
  END IF;
  IF v_admin.id = p_id AND p_role IS NOT NULL AND p_role != (SELECT role FROM admins WHERE id = p_id) THEN
    RETURN jsonb_build_object('error', '不能修改自己的角色');
  END IF;
  
  IF p_password IS NOT NULL AND p_password != '' THEN
    UPDATE admins SET
      name = COALESCE(NULLIF(p_name, ''), name),
      phone = COALESCE(NULLIF(p_phone, ''), phone),
      role = COALESCE(NULLIF(p_role, ''), role),
      store_id = COALESCE(p_store_id, store_id),
      password_hash = crypt(p_password, gen_salt('bf', 10))
    WHERE id = p_id
    RETURNING id, username, name, phone, role, store_id, created_at INTO v_record;
  ELSE
    UPDATE admins SET
      name = COALESCE(NULLIF(p_name, ''), name),
      phone = COALESCE(NULLIF(p_phone, ''), phone),
      role = COALESCE(NULLIF(p_role, ''), role),
      store_id = COALESCE(p_store_id, store_id)
    WHERE id = p_id
    RETURNING id, username, name, phone, role, store_id, created_at INTO v_record;
  END IF;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '管理员不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_delete_admin;
CREATE OR REPLACE FUNCTION rpc_delete_admin(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_target_auth_id UUID;
BEGIN
  SELECT id, role INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  IF v_admin.role != 'super_admin' THEN
    RETURN jsonb_build_object('error', '只有超级管理员才能删除管理员');
  END IF;
  IF v_admin.id = p_id THEN
    RETURN jsonb_build_object('error', '不能删除自己的账号');
  END IF;
  
  SELECT auth_user_id INTO v_target_auth_id FROM admins WHERE id = p_id;
  DELETE FROM admins WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '管理员不存在'); END IF;
  
  -- 同时删除 auth.users 记录
  IF v_target_auth_id IS NOT NULL THEN
    DELETE FROM auth.users WHERE id = v_target_auth_id;
  END IF;
  
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 第 2 批：门店 + 会员 CRUD

```sql
-- 第 2 批：门店 + 会员 CRUD

DROP FUNCTION IF EXISTS rpc_get_stores;
CREATE OR REPLACE FUNCTION rpc_get_stores(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  SELECT role, store_id INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  
  v_actual_store_id := CASE WHEN v_admin.role = 'store_admin' THEN v_admin.store_id ELSE p_store_id END;
  
  IF v_actual_store_id IS NOT NULL THEN
    SELECT to_jsonb(s) INTO v_result FROM stores s WHERE id = v_actual_store_id;
    RETURN jsonb_build_object('data', v_result);
  END IF;
  
  SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO v_result
  FROM (SELECT * FROM stores ORDER BY created_at DESC) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_create_store;
CREATE OR REPLACE FUNCTION rpc_create_store(p_name TEXT, p_address TEXT, p_phone TEXT, p_manager TEXT)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_record RECORD;
BEGIN
  SELECT role INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  IF v_admin.role != 'super_admin' THEN
    RETURN jsonb_build_object('error', '只有超级管理员才能创建门店');
  END IF;
  INSERT INTO stores (name, address, phone, manager)
  VALUES (p_name, NULLIF(p_address, ''), NULLIF(p_phone, ''), NULLIF(p_manager, ''))
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_update_store;
CREATE OR REPLACE FUNCTION rpc_update_store(p_id UUID, p_name TEXT, p_address TEXT, p_phone TEXT, p_manager TEXT, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_record RECORD;
BEGIN
  SELECT role INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  IF v_admin.role != 'super_admin' THEN
    RETURN jsonb_build_object('error', '只有超级管理员才能修改门店');
  END IF;
  UPDATE stores SET
    name = COALESCE(NULLIF(p_name, ''), name),
    address = COALESCE(NULLIF(p_address, ''), address),
    phone = COALESCE(NULLIF(p_phone, ''), phone),
    manager = COALESCE(NULLIF(p_manager, ''), manager),
    status = COALESCE(NULLIF(p_status, ''), status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '门店不存在'); END IF;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 会员
DROP FUNCTION IF EXISTS rpc_get_members;
CREATE OR REPLACE FUNCTION rpc_get_members(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter_v2(p_store_id);
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'phone', t.phone, 'name', t.name, 'level', t.level,
    'points', t.points, 'balance', t.balance, 'store_id', t.store_id,
    'status', t.status, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT m.id, m.phone, m.name, m.level, m.points, m.balance, m.store_id,
           m.status, m.created_at, s.name AS store_name
    FROM members m LEFT JOIN stores s ON m.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR m.store_id = v_actual_store_id)
    ORDER BY m.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_update_member;
CREATE OR REPLACE FUNCTION rpc_update_member(p_id UUID, p_name TEXT, p_phone TEXT, p_level TEXT, p_points BIGINT, p_balance DECIMAL, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_member_store_id UUID;
  v_record RECORD;
BEGIN
  SELECT store_id INTO v_member_store_id FROM members WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在'); END IF;
  PERFORM rpc_check_store_access_v2(v_member_store_id);
  UPDATE members SET
    name = COALESCE(NULLIF(p_name, ''), name),
    phone = COALESCE(NULLIF(p_phone, ''), phone),
    level = COALESCE(NULLIF(p_level, ''), level),
    points = COALESCE(p_points, points),
    balance = COALESCE(p_balance, balance),
    status = COALESCE(NULLIF(p_status, ''), status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 第 3 批：理发师 + 服务 + 服务类型

```sql
-- 第 3 批：理发师 + 服务 + 服务类型

-- 理发师
DROP FUNCTION IF EXISTS rpc_get_barbers;
CREATE OR REPLACE FUNCTION rpc_get_barbers(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter_v2(p_store_id);
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'name', t.name, 'phone', t.phone,
    'specialties', t.specialties, 'status', t.status,
    'store_id', t.store_id, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT b.id, b.name, b.phone, b.specialties, b.status, b.store_id, b.created_at, s.name AS store_name
    FROM barbers b LEFT JOIN stores s ON b.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR b.store_id = v_actual_store_id)
    ORDER BY b.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_create_barber;
CREATE OR REPLACE FUNCTION rpc_create_barber(p_name TEXT, p_phone TEXT, p_specialties JSONB, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_record RECORD;
BEGIN
  SELECT role, store_id INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  PERFORM rpc_check_store_access_v2(p_store_id);
  IF p_store_id IS NULL THEN p_store_id := v_admin.store_id; END IF;
  INSERT INTO barbers (name, phone, specialties, store_id)
  VALUES (p_name, NULLIF(p_phone, ''), p_specialties::text[], p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_update_barber;
CREATE OR REPLACE FUNCTION rpc_update_barber(p_id UUID, p_name TEXT, p_phone TEXT, p_specialties JSONB, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_barber_store_id UUID;
  v_record RECORD;
BEGIN
  SELECT store_id INTO v_barber_store_id FROM barbers WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '理发师不存在'); END IF;
  PERFORM rpc_check_store_access_v2(v_barber_store_id);
  UPDATE barbers SET
    name = COALESCE(NULLIF(p_name, ''), name),
    phone = COALESCE(NULLIF(p_phone, ''), phone),
    specialties = COALESCE(p_specialties::text[], specialties),
    status = COALESCE(NULLIF(p_status, ''), status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_delete_barber;
CREATE OR REPLACE FUNCTION rpc_delete_barber(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_barber_store_id UUID;
BEGIN
  SELECT store_id INTO v_barber_store_id FROM barbers WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '理发师不存在'); END IF;
  PERFORM rpc_check_store_access_v2(v_barber_store_id);
  DELETE FROM barbers WHERE id = p_id;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 服务项目
DROP FUNCTION IF EXISTS rpc_get_services;
CREATE OR REPLACE FUNCTION rpc_get_services(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter_v2(p_store_id);
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

DROP FUNCTION IF EXISTS rpc_create_service;
CREATE OR REPLACE FUNCTION rpc_create_service(p_type TEXT, p_name TEXT, p_price DECIMAL, p_discount_normal DECIMAL, p_discount_silver DECIMAL, p_discount_gold DECIMAL, p_discount_diamond DECIMAL, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_record RECORD;
BEGIN
  SELECT role, store_id INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  PERFORM rpc_check_store_access_v2(p_store_id);
  IF p_store_id IS NULL THEN p_store_id := v_admin.store_id; END IF;
  INSERT INTO services (type, name, price, discount_normal, discount_silver, discount_gold, discount_diamond, store_id)
  VALUES (p_type, p_name, p_price, p_discount_normal, p_discount_silver, p_discount_gold, p_discount_diamond, p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_update_service;
CREATE OR REPLACE FUNCTION rpc_update_service(p_id UUID, p_type TEXT, p_name TEXT, p_price DECIMAL, p_discount_normal DECIMAL, p_discount_silver DECIMAL, p_discount_gold DECIMAL, p_discount_diamond DECIMAL)
RETURNS JSONB AS $$
DECLARE
  v_service_store_id UUID;
  v_record RECORD;
BEGIN
  SELECT store_id INTO v_service_store_id FROM services WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '服务项目不存在'); END IF;
  PERFORM rpc_check_store_access_v2(v_service_store_id);
  UPDATE services SET
    type = COALESCE(NULLIF(p_type, ''), type),
    name = COALESCE(NULLIF(p_name, ''), name),
    price = COALESCE(p_price, price),
    discount_normal = COALESCE(p_discount_normal, discount_normal),
    discount_silver = COALESCE(p_discount_silver, discount_silver),
    discount_gold = COALESCE(p_discount_gold, discount_gold),
    discount_diamond = COALESCE(p_discount_diamond, discount_diamond)
  WHERE id = p_id
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_delete_service;
CREATE OR REPLACE FUNCTION rpc_delete_service(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_service_store_id UUID;
BEGIN
  SELECT store_id INTO v_service_store_id FROM services WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '服务项目不存在'); END IF;
  PERFORM rpc_check_store_access_v2(v_service_store_id);
  DELETE FROM services WHERE id = p_id;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 服务类型
DROP FUNCTION IF EXISTS rpc_get_service_types;
CREATE OR REPLACE FUNCTION rpc_get_service_types(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter_v2(p_store_id);
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

DROP FUNCTION IF EXISTS rpc_create_service_type;
CREATE OR REPLACE FUNCTION rpc_create_service_type(p_name TEXT, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_record RECORD;
BEGIN
  SELECT role, store_id INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  IF p_store_id IS NULL AND v_admin.role != 'super_admin' THEN
    p_store_id := v_admin.store_id;
  END IF;
  IF p_store_id IS NOT NULL THEN PERFORM rpc_check_store_access_v2(p_store_id); END IF;
  INSERT INTO service_types (name, store_id) VALUES (p_name, p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_delete_service_type;
CREATE OR REPLACE FUNCTION rpc_delete_service_type(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_type_store_id UUID;
BEGIN
  SELECT role, store_id INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  SELECT store_id INTO v_type_store_id FROM service_types WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '服务类型不存在'); END IF;
  IF v_admin.role = 'store_admin' THEN
    IF v_type_store_id IS NULL THEN RETURN jsonb_build_object('error', '店长不能删除全局服务类型'); END IF;
    IF v_type_store_id != v_admin.store_id THEN RETURN jsonb_build_object('error', '无权删除此服务类型'); END IF;
  END IF;
  DELETE FROM service_types WHERE id = p_id;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 第 4 批：充值套餐 + 充值/消费/预约 + 记录查询

```sql
-- 第 4 批：充值套餐 + 充值/消费/预约 + 记录查询

-- 充值套餐
DROP FUNCTION IF EXISTS rpc_get_packages;
CREATE OR REPLACE FUNCTION rpc_get_packages(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter_v2(p_store_id);
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'name', t.name, 'amount', t.amount,
    'bonus', t.bonus, 'status', t.status,
    'store_id', t.store_id, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT rp.id, rp.name, rp.amount, rp.bonus, rp.status, rp.store_id, rp.created_at, s.name AS store_name
    FROM recharge_packages rp LEFT JOIN stores s ON rp.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR rp.store_id = v_actual_store_id)
    ORDER BY rp.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_create_package;
CREATE OR REPLACE FUNCTION rpc_create_package(p_name TEXT, p_amount DECIMAL, p_bonus DECIMAL, p_status TEXT, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_record RECORD;
BEGIN
  SELECT role, store_id INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  PERFORM rpc_check_store_access_v2(p_store_id);
  IF p_store_id IS NULL THEN p_store_id := v_admin.store_id; END IF;
  INSERT INTO recharge_packages (name, amount, bonus, status, store_id)
  VALUES (p_name, p_amount, p_bonus, NULLIF(p_status, ''), p_store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_update_package;
CREATE OR REPLACE FUNCTION rpc_update_package(p_id UUID, p_name TEXT, p_amount DECIMAL, p_bonus DECIMAL, p_status TEXT)
RETURNS JSONB AS $$
DECLARE
  v_pkg_store_id UUID;
  v_record RECORD;
BEGIN
  SELECT store_id INTO v_pkg_store_id FROM recharge_packages WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '充值套餐不存在'); END IF;
  PERFORM rpc_check_store_access_v2(v_pkg_store_id);
  UPDATE recharge_packages SET
    name = COALESCE(NULLIF(p_name, ''), name),
    amount = COALESCE(p_amount, amount),
    bonus = COALESCE(p_bonus, bonus),
    status = COALESCE(NULLIF(p_status, ''), status)
  WHERE id = p_id
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', to_jsonb(v_record));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_delete_package;
CREATE OR REPLACE FUNCTION rpc_delete_package(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_pkg_store_id UUID;
BEGIN
  SELECT store_id INTO v_pkg_store_id FROM recharge_packages WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '充值套餐不存在'); END IF;
  PERFORM rpc_check_store_access_v2(v_pkg_store_id);
  DELETE FROM recharge_packages WHERE id = p_id;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 充值/消费/预约操作
DROP FUNCTION IF EXISTS rpc_recharge;
CREATE OR REPLACE FUNCTION rpc_recharge(p_member_id UUID, p_package_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_member RECORD;
  v_pkg RECORD;
  v_new_balance DECIMAL;
  v_record RECORD;
BEGIN
  SELECT id, role, store_id INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  SELECT * INTO v_member FROM members WHERE id = p_member_id AND status = 'active' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在或已冻结'); END IF;
  PERFORM rpc_check_store_access_v2(v_member.store_id);
  SELECT * INTO v_pkg FROM recharge_packages WHERE id = p_package_id AND status = 'active';
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '充值套餐不存在或已下架'); END IF;
  IF v_pkg.store_id != v_member.store_id THEN RETURN jsonb_build_object('error', '套餐不适用于此门店'); END IF;
  v_new_balance := v_member.balance + v_pkg.amount + v_pkg.bonus;
  UPDATE members SET balance = v_new_balance WHERE id = p_member_id;
  INSERT INTO recharge_records (member_id, amount, bonus, package_name, store_id)
  VALUES (p_member_id, v_pkg.amount, v_pkg.bonus, v_pkg.name, v_member.store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', jsonb_build_object(
    'record_id', v_record.id, 'new_balance', v_new_balance,
    'recharge_amount', v_pkg.amount, 'bonus', v_pkg.bonus
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_custom_recharge;
CREATE OR REPLACE FUNCTION rpc_custom_recharge(p_member_id UUID, p_amount DECIMAL, p_bonus DECIMAL)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_member RECORD;
  v_new_balance DECIMAL;
  v_record RECORD;
BEGIN
  SELECT id, role, store_id INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  IF p_amount <= 0 THEN RETURN jsonb_build_object('error', '充值金额必须大于0'); END IF;
  SELECT * INTO v_member FROM members WHERE id = p_member_id AND status = 'active' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在或已冻结'); END IF;
  PERFORM rpc_check_store_access_v2(v_member.store_id);
  v_new_balance := v_member.balance + p_amount + p_bonus;
  UPDATE members SET balance = v_new_balance WHERE id = p_member_id;
  INSERT INTO recharge_records (member_id, amount, bonus, package_name, store_id)
  VALUES (p_member_id, p_amount, p_bonus, '自定义充值', v_member.store_id)
  RETURNING * INTO v_record;
  RETURN jsonb_build_object('data', jsonb_build_object(
    'record_id', v_record.id, 'new_balance', v_new_balance,
    'recharge_amount', p_amount, 'bonus', p_bonus
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_consume;
CREATE OR REPLACE FUNCTION rpc_consume(p_member_id UUID, p_service_id UUID, p_barber_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_member RECORD;
  v_service RECORD;
  v_barber_name VARCHAR;
  v_discount DECIMAL;
  v_amount DECIMAL;
  v_points INT;
  v_new_balance DECIMAL;
  v_new_points INT;
BEGIN
  SELECT id, role, store_id INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  SELECT * INTO v_member FROM members WHERE id = p_member_id AND status = 'active' FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在或已冻结'); END IF;
  PERFORM rpc_check_store_access_v2(v_member.store_id);
  SELECT * INTO v_service FROM services WHERE id = p_service_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '服务项目不存在'); END IF;
  v_discount := CASE v_member.level
    WHEN 'normal' THEN v_service.discount_normal
    WHEN 'silver' THEN v_service.discount_silver
    WHEN 'gold' THEN v_service.discount_gold
    WHEN 'diamond' THEN v_service.discount_diamond
    ELSE 1.00
  END;
  v_amount := ROUND(v_service.price * v_discount, 2);
  IF v_member.balance < v_amount THEN
    RETURN jsonb_build_object('error', '余额不足', 'current_balance', v_member.balance, 'required', v_amount);
  END IF;
  IF p_barber_id IS NOT NULL THEN SELECT name INTO v_barber_name FROM barbers WHERE id = p_barber_id; END IF;
  v_points := FLOOR(v_amount)::INT;
  v_new_balance := v_member.balance - v_amount;
  v_new_points := v_member.points + v_points;
  UPDATE members SET balance = v_new_balance, points = v_new_points WHERE id = p_member_id;
  INSERT INTO consumption_records (member_id, amount, original_price, discount, service_id, service_name, barber_id, barber_name, points_earned, store_id)
  VALUES (p_member_id, v_amount, v_service.price, v_discount, p_service_id, v_service.name, p_barber_id, v_barber_name, v_points, v_member.store_id);
  UPDATE members SET level = CASE
    WHEN v_new_points >= 5000 THEN 'diamond'
    WHEN v_new_points >= 2000 THEN 'gold'
    WHEN v_new_points >= 500 THEN 'silver'
    ELSE 'normal'
  END WHERE id = p_member_id;
  RETURN jsonb_build_object('data', jsonb_build_object(
    'new_balance', v_new_balance, 'amount', v_amount,
    'original_price', v_service.price, 'discount', v_discount,
    'points_earned', v_points, 'total_points', v_new_points
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 预约
DROP FUNCTION IF EXISTS rpc_create_appointment;
CREATE OR REPLACE FUNCTION rpc_create_appointment(p_member_id UUID, p_barber_id UUID, p_service_id UUID, p_appointment_time TIMESTAMPTZ)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_member RECORD;
  v_appointment RECORD;
BEGIN
  SELECT id, role, store_id INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '未认证'); END IF;
  SELECT * INTO v_member FROM members WHERE id = p_member_id AND status = 'active';
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '会员不存在'); END IF;
  PERFORM rpc_check_store_access_v2(v_member.store_id);
  IF p_appointment_time < NOW() THEN RETURN jsonb_build_object('error', '预约时间不能是过去'); END IF;
  INSERT INTO appointments (member_id, barber_id, service_id, appointment_time, status, store_id)
  VALUES (p_member_id, p_barber_id, p_service_id, p_appointment_time, 'pending', v_member.store_id)
  RETURNING * INTO v_appointment;
  RETURN jsonb_build_object('data', to_jsonb(v_appointment));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_confirm_appointment;
CREATE OR REPLACE FUNCTION rpc_confirm_appointment(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_appt_store_id UUID;
BEGIN
  SELECT store_id INTO v_appt_store_id FROM appointments WHERE id = p_id AND status = 'pending';
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '预约不存在或状态不允许确认'); END IF;
  PERFORM rpc_check_store_access_v2(v_appt_store_id);
  UPDATE appointments SET status = 'confirmed', updated_at = now() WHERE id = p_id;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id, 'status', 'confirmed'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_cancel_appointment;
CREATE OR REPLACE FUNCTION rpc_cancel_appointment(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_appt_store_id UUID;
BEGIN
  SELECT store_id INTO v_appt_store_id FROM appointments WHERE id = p_id AND status IN ('pending', 'confirmed');
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '预约不存在或状态不允许取消'); END IF;
  PERFORM rpc_check_store_access_v2(v_appt_store_id);
  UPDATE appointments SET status = 'cancelled', updated_at = now() WHERE id = p_id;
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id, 'status', 'cancelled'));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_complete_appointment;
CREATE OR REPLACE FUNCTION rpc_complete_appointment(p_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_appt RECORD;
  v_result JSONB;
BEGIN
  SELECT * INTO v_appt FROM appointments WHERE id = p_id AND status = 'confirmed';
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '预约不存在或状态不允许完成'); END IF;
  PERFORM rpc_check_store_access_v2(v_appt.store_id);
  UPDATE appointments SET status = 'completed', updated_at = now() WHERE id = p_id;
  v_result := rpc_consume(v_appt.member_id, v_appt.service_id, v_appt.barber_id);
  RETURN jsonb_build_object('data', jsonb_build_object('id', p_id, 'status', 'completed', 'consumption', v_result));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 记录查询
DROP FUNCTION IF EXISTS rpc_get_recharge_records;
CREATE OR REPLACE FUNCTION rpc_get_recharge_records(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter_v2(p_store_id);
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'member_id', t.member_id, 'member_name', t.member_name,
    'member_phone', t.member_phone, 'amount', t.amount, 'bonus', t.bonus,
    'package_name', t.package_name, 'store_id', t.store_id,
    'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT r.id, r.member_id, m.name AS member_name, m.phone AS member_phone,
           r.amount, r.bonus, r.package_name, r.store_id, r.created_at, s.name AS store_name
    FROM recharge_records r LEFT JOIN members m ON r.member_id = m.id LEFT JOIN stores s ON r.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR r.store_id = v_actual_store_id)
    ORDER BY r.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_get_consumption_records;
CREATE OR REPLACE FUNCTION rpc_get_consumption_records(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter_v2(p_store_id);
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'member_id', t.member_id, 'member_name', t.member_name,
    'member_phone', t.member_phone, 'amount', t.amount, 'original_price', t.original_price,
    'discount', t.discount, 'service_name', t.service_name,
    'barber_name', t.barber_name, 'points_earned', t.points_earned,
    'store_id', t.store_id, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT c.id, c.member_id, m.name AS member_name, m.phone AS member_phone,
           c.amount, c.original_price, c.discount, c.service_name,
           c.barber_name, c.points_earned, c.store_id, c.created_at, s.name AS store_name
    FROM consumption_records c LEFT JOIN members m ON c.member_id = m.id LEFT JOIN stores s ON c.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR c.store_id = v_actual_store_id)
    ORDER BY c.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_get_appointments;
CREATE OR REPLACE FUNCTION rpc_get_appointments(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter_v2(p_store_id);
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', t.id, 'member_id', t.member_id, 'member_name', t.member_name,
    'member_phone', t.member_phone, 'barber_id', t.barber_id, 'barber_name', t.barber_name,
    'service_id', t.service_id, 'service_name', t.service_name,
    'appointment_time', t.appointment_time, 'status', t.status,
    'store_id', t.store_id, 'store_name', t.store_name, 'created_at', t.created_at
  )), '[]'::jsonb) INTO v_result
  FROM (
    SELECT a.id, a.member_id, m.name AS member_name, m.phone AS member_phone,
           a.barber_id, b.name AS barber_name, a.service_id, sv.name AS service_name,
           a.appointment_time, a.status, a.store_id, a.created_at, s.name AS store_name
    FROM appointments a
    LEFT JOIN members m ON a.member_id = m.id LEFT JOIN barbers b ON a.barber_id = b.id
    LEFT JOIN services sv ON a.service_id = sv.id LEFT JOIN stores s ON a.store_id = s.id
    WHERE (v_actual_store_id IS NULL OR a.store_id = v_actual_store_id)
    ORDER BY a.created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 第 5 批：统计 + 财务

```sql
-- 第 5 批：统计 + 财务

DROP FUNCTION IF EXISTS rpc_revenue_stats;
CREATE OR REPLACE FUNCTION rpc_revenue_stats(p_store_id UUID, p_start_date DATE, p_end_date DATE, p_dimension TEXT)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB := '[]'::JSONB;
  v_start DATE;
  v_end DATE;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter_v2(p_store_id);
  v_start := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
  v_end := COALESCE(p_end_date, CURRENT_DATE);
  SELECT COALESCE(jsonb_agg(jsonb_build_object('period', d::text, 'total_amount', COALESCE(s.total, 0))),'[]'::JSONB)
  INTO v_result
  FROM generate_series(v_start, v_end, INTERVAL '1 day') d
  LEFT JOIN (
    SELECT DATE(created_at) AS dt, SUM(amount) AS total FROM consumption_records
    WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
      AND created_at >= v_start AND created_at < v_end + INTERVAL '1 day'
    GROUP BY DATE(created_at)
  ) s ON d = s.dt;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_member_growth_stats;
CREATE OR REPLACE FUNCTION rpc_member_growth_stats(p_store_id UUID, p_start_date DATE, p_end_date DATE, p_dimension TEXT)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB := '[]'::JSONB;
  v_start DATE;
  v_end DATE;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter_v2(p_store_id);
  v_start := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
  v_end := COALESCE(p_end_date, CURRENT_DATE);
  SELECT COALESCE(jsonb_agg(jsonb_build_object('period', d::text, 'count', COALESCE(s.cnt, 0))),'[]'::JSONB)
  INTO v_result
  FROM generate_series(v_start, v_end, INTERVAL '1 day') d
  LEFT JOIN (
    SELECT DATE(created_at) AS dt, COUNT(*) AS cnt FROM members
    WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
      AND created_at >= v_start AND created_at < v_end + INTERVAL '1 day' AND status = 'active'
    GROUP BY DATE(created_at)
  ) s ON d = s.dt;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_hot_services_stats;
CREATE OR REPLACE FUNCTION rpc_hot_services_stats(p_store_id UUID, p_start_date DATE, p_end_date DATE)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter_v2(p_store_id);
  SELECT COALESCE(jsonb_agg(jsonb_build_object('service_name', service_name, 'count', cnt)),'[]'::JSONB)
  INTO v_result
  FROM (
    SELECT service_name, COUNT(*) AS cnt FROM consumption_records
    WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
      AND (p_start_date IS NULL OR created_at >= p_start_date)
      AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day')
    GROUP BY service_name ORDER BY cnt DESC LIMIT 10
  ) sub;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_finance_summary;
CREATE OR REPLACE FUNCTION rpc_finance_summary(p_store_id UUID, p_start_date DATE, p_end_date DATE)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_recharge DECIMAL;
  v_consumption DECIMAL;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter_v2(p_store_id);
  SELECT COALESCE(SUM(amount + bonus), 0) INTO v_recharge FROM recharge_records
  WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day');
  SELECT COALESCE(SUM(amount), 0) INTO v_consumption FROM consumption_records
  WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id)
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at < p_end_date + INTERVAL '1 day');
  RETURN jsonb_build_object('data', jsonb_build_object(
    'recharge_income', v_recharge, 'consumption_income', v_consumption, 'net_income', v_consumption
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP FUNCTION IF EXISTS rpc_daily_statements;
CREATE OR REPLACE FUNCTION rpc_daily_statements(p_store_id UUID, p_start_date DATE, p_end_date DATE)
RETURNS JSONB AS $$
DECLARE
  v_actual_store_id UUID;
  v_result JSONB;
BEGIN
  v_actual_store_id := rpc_enforce_store_filter_v2(p_store_id);
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'date', d.dt, 'recharge_count', COALESCE(r.cnt, 0), 'recharge_amount', COALESCE(r.total, 0),
    'consumption_count', COALESCE(c.cnt, 0), 'consumption_amount', COALESCE(c.total, 0)
  )),'[]'::JSONB) INTO v_result
  FROM generate_series(COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days'), COALESCE(p_end_date, CURRENT_DATE), INTERVAL '1 day') d(dt)
  LEFT JOIN (SELECT DATE(created_at) AS dt, COUNT(*) AS cnt, SUM(amount + bonus) AS total FROM recharge_records WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id) GROUP BY DATE(created_at)) r ON d.dt = r.dt
  LEFT JOIN (SELECT DATE(created_at) AS dt, COUNT(*) AS cnt, SUM(amount) AS total FROM consumption_records WHERE (v_actual_store_id IS NULL OR store_id = v_actual_store_id) GROUP BY DATE(created_at)) c ON d.dt = c.dt;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 会员注册改造（加入 auth.users）

```sql
-- 会员注册改造：先创建 auth.users，再写 members
DROP FUNCTION IF EXISTS rpc_member_register;
CREATE OR REPLACE FUNCTION rpc_member_register(p_phone TEXT, p_password TEXT, p_name TEXT, p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_auth_user UUID;
  v_member RECORD;
BEGIN
  IF p_phone IS NULL OR p_password IS NULL OR p_store_id IS NULL THEN
    RETURN jsonb_build_object('error', '缺少必填字段');
  END IF;
  IF p_phone !~ '^1[3-9]\d{9}$' THEN
    RETURN jsonb_build_object('error', '手机号格式不正确');
  END IF;
  IF LENGTH(p_password) < 8 THEN
    RETURN jsonb_build_object('error', '密码至少8位');
  END IF;
  IF EXISTS (SELECT 1 FROM members WHERE phone = p_phone AND store_id = p_store_id) THEN
    RETURN jsonb_build_object('error', '该手机号已注册');
  END IF;
  
  -- 创建 auth.users
  INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, confirmation_token, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, aud, role)
  VALUES (
    gen_random_uuid(), '00000000-0000-0000-0000-000000000000',
    p_phone || '_' || p_store_id || '@membership.internal',
    crypt(p_password, gen_salt('bf', 10)), now(),
    encode(gen_random_bytes(32), 'hex'),
    '{"provider":"email","providers":["email"]}', '{}',
    now(), now(), 'authenticated', 'authenticated'
  ) RETURNING id INTO v_auth_user;
  
  INSERT INTO members (phone, password_hash, name, store_id, level, points, balance, status, auth_user_id)
  VALUES (p_phone, crypt(p_password, gen_salt('bf', 10)), p_name, p_store_id, 'normal', 0, 0, 'active', v_auth_user)
  RETURNING id, phone, name, level, points, balance, store_id INTO v_member;
  
  RETURN jsonb_build_object('data', to_jsonb(v_member));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 验收标准

- [ ] 所有 RPC 函数签名中不再有 `p_admin_id` 参数
- [ ] 未认证（无 JWT）调用任何业务 RPC 返回错误
- [ ] 伪造 admin ID 无法绕过权限（因为身份从 JWT 取，不从参数取）
- [ ] 店长只能看到/操作自己门店的数据
- [ ] 超管可以看到/操作所有门店数据
- [ ] `rpc_get_current_admin_info()` 在认证后返回正确的管理员信息
- [ ] 会员注册同时创建 auth.users 记录

---

## Phase 3: 消灭 Critical — 明文密码 + 密码策略 + 枚举清理

### 目标
彻底消灭明文密码回退路径，加强密码策略，清理残留枚举强转。

### 修复思路

1. **删除 login 函数中的 ELSE 分支**，不再接受非 bcrypt 密码
2. **强制迁移所有非 bcrypt 密码**为 bcrypt
3. **密码最少 8 位**，管理员和会员统一
4. **清理 crud_rpc_v3.sql 中的枚举强转**（已在 fix_enum_types.sql 中修过，确认数据库已部署）

### 数据库变更 SQL

```sql
-- Phase 3: 消灭 Critical

-- 1. 检查是否有非 bcrypt 密码
SELECT 'admins 非bcrypt:' AS check_type, COUNT(*) AS cnt FROM admins WHERE password_hash NOT LIKE '$2%'
UNION ALL
SELECT 'members 非bcrypt:', COUNT(*) FROM members WHERE password_hash NOT LIKE '$2%';

-- 2. 强制迁移所有非 bcrypt 密码（设为强制重置状态）
UPDATE admins SET password_hash = crypt('Ch@ngeme' || id::text, gen_salt('bf', 10))
WHERE password_hash NOT LIKE '$2%';

UPDATE members SET password_hash = crypt('Ch@ngeme' || id::text, gen_salt('bf', 10))
WHERE password_hash NOT LIKE '$2%';

-- 3. rpc_admin_login 删除明文回退（重写）
CREATE OR REPLACE FUNCTION rpc_admin_login(p_username VARCHAR, p_password VARCHAR)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
BEGIN
  SELECT a.id, a.username, a.name, a.phone, a.role, a.store_id, a.password_hash, a.auth_user_id
  INTO v_admin FROM admins a WHERE a.username = p_username;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', '用户名或密码错误'); END IF;
  
  -- 只接受 bcrypt，不再有明文回退
  IF NOT (crypt(p_password, v_admin.password_hash) = v_admin.password_hash) THEN
    RETURN jsonb_build_object('error', '用户名或密码错误');
  END IF;
  
  RETURN jsonb_build_object('data', jsonb_build_object(
    'id', v_admin.id, 'username', v_admin.username, 'name', v_admin.name,
    'phone', v_admin.phone, 'role', v_admin.role, 'store_id', v_admin.store_id
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. rpc_member_login 同样删除明文回退
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

-- 5. 修改密码函数（新增）
CREATE OR REPLACE FUNCTION rpc_change_password(p_old_password TEXT, p_new_password TEXT)
RETURNS JSONB AS $$
DECLARE
  v_admin RECORD;
  v_member RECORD;
BEGIN
  IF LENGTH(p_new_password) < 8 THEN
    RETURN jsonb_build_object('error', '新密码至少8位');
  END IF;
  
  -- 先查管理员
  SELECT id, password_hash INTO v_admin FROM admins WHERE auth_user_id = auth.uid();
  IF FOUND THEN
    IF NOT (crypt(p_old_password, v_admin.password_hash) = v_admin.password_hash) THEN
      RETURN jsonb_build_object('error', '旧密码错误');
    END IF;
    UPDATE admins SET password_hash = crypt(p_new_password, gen_salt('bf', 10)) WHERE id = v_admin.id;
    -- 同步更新 auth.users
    UPDATE auth.users SET encrypted_password = crypt(p_new_password, gen_salt('bf', 10)) WHERE id = auth.uid();
    RETURN jsonb_build_object('data', jsonb_build_object('success', true));
  END IF;
  
  -- 再查会员
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
```

### 验收标准

- [ ] 数据库中 0 条非 bcrypt 密码记录
- [ ] `rpc_admin_login` / `rpc_member_login` 无 ELSE 分支
- [ ] 尝试用明文密码登录返回错误（即使数据库中意外存在非 bcrypt hash）
- [ ] 新密码最少 8 位
- [ ] `rpc_change_password` 验证旧密码后可修改
- [ ] 修改密码同时更新 `admins.password_hash` 和 `auth.users.encrypted_password`

---

## Phase 4: RLS 激活

### 目标
激活 RLS，业务表禁止 anon 直接查表，所有访问走 RPC（SECURITY DEFINER 自动绕过 RLS）。

### 修复思路

1. **清除所有现有 RLS 策略**
2. **业务表 RLS 全部 `USING(false)`**，即禁止直接 SQL 访问
3. **RPC 函数用 `SECURITY DEFINER` 自动绕过 RLS**
4. **保留必要的公开查询**（如门店列表、活跃服务——用于 C 端浏览）

### 数据库变更 SQL

```sql
-- Phase 4: RLS 激活

-- 1. 清除所有现有策略
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN (SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname = 'public') LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
  END LOOP;
END $$;

-- 2. 所有业务表启用 RLS
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE barbers ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE recharge_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE recharge_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE consumption_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_types ENABLE ROW LEVEL SECURITY;

-- 3. 业务表：authenticated 用户可读（通过 JWT 验证了身份）
-- 但写操作全部通过 RPC，RLS 只允许 SELECT
CREATE POLICY authenticated_read ON stores FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON admins FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON members FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON barbers FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON services FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON recharge_packages FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON recharge_records FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON consumption_records FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON appointments FOR SELECT TO authenticated USING (true);
CREATE POLICY authenticated_read ON service_types FOR SELECT TO authenticated USING (true);

-- 4. anon 用户：只能读门店列表（C 端浏览用）
CREATE POLICY anon_stores_read ON stores FOR SELECT TO anon USING (status = 'active');
CREATE POLICY anon_services_read ON services FOR SELECT TO anon USING (true);
CREATE POLICY anon_barbers_read ON barbers FOR SELECT TO anon USING (status = 'active');
CREATE POLICY anon_packages_read ON recharge_packages FOR SELECT TO anon USING (status = 'active');

-- 5. audit_logs：只有 service_role 可写
CREATE POLICY authenticated_read_audit ON audit_logs FOR SELECT TO authenticated USING (true);

-- 6. 写操作：全部通过 RPC (SECURITY DEFINER)，RLS 禁止直接 INSERT/UPDATE/DELETE
-- 不需要显式策略，因为 RLS 默认对没有策略的操作拒绝
```

### 验收标准

- [ ] 未认证（anon key + 无 JWT）调用业务 RPC 返回错误
- [ ] 已认证用户可正常调用 RPC
- [ ] 直接 `supabase.from('members').select()` 在未认证时返回空/错误
- [ ] 已认证用户直接 `supabase.from('members').select()` 可读取（RLS 允许 SELECT）
- [ ] 已认证用户直接 `supabase.from('members').insert()` 被拒（写操作必须走 RPC）
- [ ] anon 用户可读取门店列表、服务、理发师、套餐（C 端浏览）

---

## Phase 5: 前端改造

### 目标
前端改用 Supabase Auth 原生登录，删除 `aid()` 函数，移除所有 `p_admin_id` 参数。

### 修复思路

1. **supabase.ts**：不改（anon key 仍然需要，Supabase SDK 自动管理 JWT）
2. **auth.ts**：改用 `supabase.auth.signInWithPassword` + `onAuthStateChange`
3. **api.ts**：删除 `aid()`，所有调用移除 `p_admin_id`
4. **Login 页面**：改用新的登录流程

### 代码变更

#### auth.ts 重写

```typescript
/**
 * @file auth.ts - 认证状态管理（Supabase Auth 版）
 */
import { create } from 'zustand'
import { supabase } from '@/lib/supabase'
import type { Admin, Member } from '@/types'

interface AuthState {
  admin: Admin | null
  member: Member | null
  role: 'admin' | 'member' | null
  isAuthenticated: boolean
  isLoading: boolean
  setAdmin: (admin: Admin) => void
  setMember: (member: Member) => void
  logout: () => void
  checkAuth: () => Promise<void>
  isSuperAdmin: () => boolean
  storeId: () => string | undefined
}

export const useAuthStore = create<AuthState>((set, get) => ({
  admin: null,
  member: null,
  role: null,
  isAuthenticated: false,
  isLoading: true,

  setAdmin: (admin) => set({ admin, role: 'admin', isAuthenticated: true, isLoading: false }),
  setMember: (member) => set({ member, role: 'member', isAuthenticated: true, isLoading: false }),

  logout: async () => {
    await supabase.auth.signOut()
    set({ admin: null, member: null, role: null, isAuthenticated: false, isLoading: false })
  },

  checkAuth: async () => {
    set({ isLoading: true })
    try {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) {
        set({ isAuthenticated: false, admin: null, member: null, role: null, isLoading: false })
        return
      }

      // 尝试取管理员信息
      const { data: adminResult } = await supabase.rpc('rpc_get_current_admin_info')
      if (adminResult?.data) {
        set({ admin: adminResult.data, role: 'admin', isAuthenticated: true, isLoading: false })
        return
      }

      // 尝试取会员信息
      const { data: memberResult } = await supabase.rpc('rpc_get_current_member_info')
      if (memberResult?.data) {
        set({ member: memberResult.data, role: 'member', isAuthenticated: true, isLoading: false })
        return
      }

      set({ isAuthenticated: false, admin: null, member: null, role: null, isLoading: false })
    } catch {
      set({ isAuthenticated: false, admin: null, member: null, role: null, isLoading: false })
    }
  },

  isSuperAdmin: () => get().admin?.role === 'super_admin',
  storeId: () => get().admin?.store_id || get().member?.store_id,
}))

// 监听认证状态变化
supabase.auth.onAuthStateChange((event) => {
  if (event === 'SIGNED_OUT') {
    useAuthStore.getState().logout()
  }
})
```

#### api.ts 改造（关键差异）

```typescript
// 删除 aid() 函数
// 所有 rpcCall 调用移除 p_admin_id 参数

// 认证改用 Supabase Auth
export const adminLogin = async (username: string, password: string) => {
  const { data, error } = await supabase.auth.signInWithPassword({
    email: `${username}@membership.internal`,
    password,
  })
  if (error) throw error
  
  // 登录成功后取业务信息
  const { data: adminInfo, error: infoError } = await supabase.rpc('rpc_get_current_admin_info')
  if (infoError) throw infoError
  if (adminInfo?.error) throw new Error(adminInfo.error)
  return { data: adminInfo.data }
}

export const memberLogin = async (phone: string, password: string, store_id: string) => {
  const { data, error } = await supabase.auth.signInWithPassword({
    email: `${phone}_${store_id}@membership.internal`,
    password,
  })
  if (error) throw error
  
  const { data: memberInfo, error: infoError } = await supabase.rpc('rpc_get_current_member_info')
  if (infoError) throw infoError
  if (memberInfo?.error) throw new Error(memberInfo.error)
  return { data: memberInfo.data }
}

// 会员注册
export const memberRegister = async (data: { phone: string; password: string; name: string; store_id: string }) => {
  // 先用 RPC 注册（RPC 内部同时创建 auth.users + members）
  const { data: result, error } = await supabase.rpc('rpc_member_register', {
    p_phone: data.phone,
    p_password: data.password,
    p_name: data.name,
    p_store_id: data.store_id,
  })
  if (error) throw error
  if (result?.error) throw new Error(result.error)
  
  // 注册成功后自动登录
  const { error: loginError } = await supabase.auth.signInWithPassword({
    email: `${data.phone}_${data.store_id}@membership.internal`,
    password: data.password,
  })
  if (loginError) throw loginError
  
  return { data: result.data }
}

// 修改密码
export const changePassword = (oldPassword: string, newPassword: string) =>
  rpcCall('rpc_change_password', { p_old_password: oldPassword, p_new_password: newPassword })

// 以下所有函数：删除 p_admin_id 参数，其余不变
// 示例：
export const getStores = (storeId?: string) =>
  rpcCall('rpc_get_stores', { p_store_id: storeId || null })

export const createStore = (data: Partial<Store>) =>
  rpcCall('rpc_create_store', {
    p_name: data.name,
    p_address: data.address || null,
    p_phone: data.phone || null,
    p_manager: data.manager || null,
  })

export const getMembers = (storeId?: string) =>
  rpcCall('rpc_get_members', { p_store_id: storeId || null })

// ... 其余函数同理，移除 p_admin_id，其他参数不变
// 完整版在执行时逐一修改
```

### 验收标准

- [ ] `aid()` 函数已删除
- [ ] 所有 API 函数无 `p_admin_id` 参数
- [ ] 管理员登录：`supabase.auth.signInWithPassword` + `rpc_get_current_admin_info`
- [ ] 会员登录：`supabase.auth.signInWithPassword` + `rpc_get_current_member_info`
- [ ] 登出：`supabase.auth.signOut()`
- [ ] 刷新页面后自动恢复登录状态（`checkAuth` 通过 `supabase.auth.getSession`）
- [ ] 不再往 localStorage 写 admin/member JSON 对象
- [ ] Token 过期后自动跳转登录页

---

## Phase 6: 加固

### 目标
补充暴力破解防护、审计日志、CORS 限制。

### 6.1 暴力破解防护

```sql
-- 登录失败计数表
CREATE TABLE IF NOT EXISTS login_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier TEXT NOT NULL,
  ip_address INET,
  success BOOLEAN NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_login_attempts_id_time ON login_attempts(identifier, created_at DESC);

-- 定期清理（保留 24h）
-- 可通过 pg_cron 或手动执行
DELETE FROM login_attempts WHERE created_at < now() - INTERVAL '24 hours';

-- 在 rpc_admin_login 中添加检查（放在验证逻辑之前）
DECLARE
  v_fail_count INT;
BEGIN
  SELECT COUNT(*) INTO v_fail_count FROM login_attempts
  WHERE identifier = p_username AND success = false
    AND created_at > now() - INTERVAL '15 minutes';
  IF v_fail_count >= 5 THEN
    RETURN jsonb_build_object('error', '登录失败次数过多，请15分钟后重试');
  END IF;
  
  -- ... 原有验证逻辑 ...
  
  -- 验证结束后记录
  INSERT INTO login_attempts (identifier, success) VALUES (p_username, v_login_success);
```

### 6.2 审计日志

```sql
-- 在每个写操作 RPC 末尾添加审计日志
-- 以 rpc_recharge 为例：
INSERT INTO audit_logs (user_id, user_type, action, resource_type, resource_id, details)
VALUES (v_admin_id, 'admin', 'RECHARGE', 'member', p_member_id,
  jsonb_build_object('amount', v_pkg.amount, 'bonus', v_pkg.bonus, 'package', v_pkg.name));
```

需要添加审计的 RPC 函数：
- `rpc_recharge` / `rpc_custom_recharge`
- `rpc_consume`
- `rpc_create_appointment` / `rpc_confirm_appointment` / `rpc_cancel_appointment` / `rpc_complete_appointment`
- `rpc_create_admin` / `rpc_update_admin` / `rpc_delete_admin`
- `rpc_create_store` / `rpc_update_store`
- `rpc_create_member` (如新增)
- `rpc_change_password`

### 6.3 CORS 限制

Supabase Dashboard → Authentication → URL Configuration：
- 添加 `https://membership-system-nine.vercel.app` 到 Site URL
- 添加 `https://membership-system-nine.vercel.app` 到 Redirect URLs
- 如需本地开发：添加 `http://localhost:5173`

### 验收标准

- [ ] 同一用户名 5 次登录失败后 15 分钟内无法再登录
- [ ] 所有写操作在 `audit_logs` 表有记录
- [ ] `login_attempts` 表有登录成功/失败记录
- [ ] Dashboard CORS 配置已限制

---

## 测试用例

每个 Phase 完成后执行对应测试，全部通过后进入下一 Phase。

### Phase 1 测试

```sql
-- T1.1: admins 表有 auth_user_id 列
SELECT column_name FROM information_schema.columns WHERE table_name = 'admins' AND column_name = 'auth_user_id';
-- 期望: auth_user_id

-- T1.2: members 表有 auth_user_id 列
SELECT column_name FROM information_schema.columns WHERE table_name = 'members' AND column_name = 'auth_user_id';
-- 期望: auth_user_id

-- T1.3: 所有 admin 有关联的 auth.users
SELECT COUNT(*) AS unlinked FROM admins WHERE auth_user_id IS NULL;
-- 期望: 0
```

### Phase 2 测试

```sql
-- T2.1: 未认证调用 rpc_get_members 应报错
-- 在前端测试：未登录时调用 supabase.rpc('rpc_get_members', { p_store_id: null })
-- 期望: 返回 error

-- T2.2: 认证后调用 rpc_get_members 应成功
-- 前端测试：登录 admin 后调用
-- 期望: 返回 data 数组

-- T2.3: 店长只能看自己门店
-- 用 store_admin_1 登录，调 rpc_get_members({ p_store_id: null })
-- 期望: 只返回本门店会员

-- T2.4: 超管可看所有门店
-- 用 admin 登录，调 rpc_get_members({ p_store_id: null })
-- 期望: 返回所有门店会员
```

### Phase 3 测试

```sql
-- T3.1: 无非 bcrypt 密码
SELECT COUNT(*) AS non_bcrypt FROM admins WHERE password_hash NOT LIKE '$2%';
-- 期望: 0

SELECT COUNT(*) AS non_bcrypt FROM members WHERE password_hash NOT LIKE '$2%';
-- 期望: 0

-- T3.2: 密码策略（前端测试）
-- 尝试注册密码少于 8 位的会员
-- 期望: 返回 "密码至少8位"

-- T3.3: 修改密码
-- 调 rpc_change_password({ p_old_password: 'admin123', p_new_password: 'newpass123' })
-- 期望: success: true
```

### Phase 4 测试

```sql
-- T4.1: anon 直接查 members 被拒
-- 用 anon key（无 JWT）调 supabase.from('members').select('*')
-- 期望: 返回空或错误

-- T4.2: authenticated 用户可直接 SELECT
-- 登录后调 supabase.from('members').select('*')
-- 期望: 返回数据

-- T4.3: authenticated 用户不能直接 INSERT
-- 登录后调 supabase.from('members').insert({...})
-- 期望: 返回 RLS 错误

-- T4.4: RPC 写操作正常
-- 登录后调 supabase.rpc('rpc_create_barber', {...})
-- 期望: 成功
```

### Phase 5 测试

```
T5.1: 管理员登录 → admin/admin123 → 成功跳转 Dashboard
T5.2: 会员登录 → 手机号+密码+门店 → 成功跳转 Profile
T5.3: 登出 → 跳转登录页 → 再访问 Dashboard 被拦截
T5.4: 刷新页面 → 保持登录状态
T5.5: Token 过期 → 自动跳转登录页
T5.6: 前端代码搜索 "p_admin_id" → 0 结果
T5.7: 前端代码搜索 "aid()" → 0 结果
T5.8: localStorage 无 admin/member JSON 对象
```

### Phase 6 测试

```sql
-- T6.1: 暴力破解防护
-- 连续 5 次错误密码登录 → 第 6 次返回 "登录失败次数过多"

-- T6.2: 审计日志
-- 执行一次充值操作 → audit_logs 有对应记录
SELECT * FROM audit_logs WHERE action = 'RECHARGE' ORDER BY created_at DESC LIMIT 1;
-- 期望: 有记录，details 包含金额信息

-- T6.3: CORS
-- 从非白名单域发起请求 → 被拒
```

---

## 部署上线

全部测试通过后：

1. **前端构建**
```bash
cd E:\学习\会员系统\MmbershipWeb
npm run build
```

2. **Vercel 部署**
```bash
cd E:\学习\会员系统\MmbershipWeb
vercel --prod
```

3. **验证生产环境**
- 访问 https://membership-system-nine.vercel.app
- 管理员登录 admin / admin123（或新密码）
- 核心功能全量走一遍
- 确认 Token 正确传递

---

## 执行顺序与工时

| Phase | 内容 | 预估时间 |
|-------|------|----------|
| 1 | 认证基建（加列 + 迁移 auth.users） | 30 min |
| 2 | RPC 改造（33+ 函数移除 p_admin_id） | 2-3 h |
| 3 | 消灭 Critical（明文密码 + 密码策略） | 30 min |
| 4 | RLS 激活 | 15 min |
| 5 | 前端改造（auth.ts + api.ts + Login） | 1-2 h |
| 6 | 加固（暴力破解 + 审计 + CORS） | 30 min |
| — | 回归测试 + 部署 | 1 h |
| **总计** | | **6-8 h** |

---

## ⚠️ 注意事项

1. **SQL 分批提交**：每次 1-3 个函数，避免批量执行中途报错导致后续函数未创建
2. **先测后上线**：每个 Phase 独立验收，不跳过
3. **service_role key 用完即删**：迁移脚本执行后删除，不提交到 Git
4. **admin 密码需重设**：迁移后 admin/admin123 仍然有效（bcrypt 已匹配），但建议首次登录后修改
5. **前端改造需同步**：Phase 2 的 RPC 签名变更必须与 Phase 5 的前端改动同步上线，否则前端调不通
