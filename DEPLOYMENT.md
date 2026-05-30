# 会员系统安全加固 - 部署指南

## 一、数据库迁移（Supabase Dashboard）

### 操作步骤

1. 登录 [Supabase Dashboard](https://app.supabase.com)
2. 选择你的项目
3. 左侧菜单 → **SQL Editor**
4. 点击 **New Query**
5. 复制下方 SQL 并粘贴

```sql
-- =============================================
-- 会员系统安全加固 - 数据库迁移
-- =============================================

-- 第一部分：审计日志表
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('admin', 'member')),
  action VARCHAR(50) NOT NULL,
  resource_type VARCHAR(50) NOT NULL,
  resource_id UUID,
  details JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC);

-- 第二部分：字段扩展
ALTER TABLE admins ADD COLUMN IF NOT EXISTS password_upgraded_at TIMESTAMPTZ;
ALTER TABLE members ADD COLUMN IF NOT EXISTS password_upgraded_at TIMESTAMPTZ;
ALTER TABLE members ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';
ALTER TABLE recharge_packages ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';

-- 第三部分：启用 RLS
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE recharge_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE consumption_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE recharge_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE barbers ENABLE ROW LEVEL SECURITY;
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- 第四部分：创建 RLS 策略（允许所有操作 - 认证由 Edge Functions 处理）
DROP POLICY IF EXISTS admins_all ON admins;
CREATE POLICY admins_all ON admins FOR ALL USING (true);

DROP POLICY IF EXISTS members_all ON members;
CREATE POLICY members_all ON members FOR ALL USING (true);

DROP POLICY IF EXISTS recharge_records_all ON recharge_records;
CREATE POLICY recharge_records_all ON recharge_records FOR ALL USING (true);

DROP POLICY IF EXISTS consumption_records_all ON consumption_records;
CREATE POLICY consumption_records_all ON consumption_records FOR ALL USING (true);

DROP POLICY IF EXISTS appointments_all ON appointments;
CREATE POLICY appointments_all ON appointments FOR ALL USING (true);

DROP POLICY IF EXISTS recharge_packages_all ON recharge_packages;
CREATE POLICY recharge_packages_all ON recharge_packages FOR ALL USING (true);

DROP POLICY IF EXISTS services_all ON services;
CREATE POLICY services_all ON services FOR ALL USING (true);

DROP POLICY IF EXISTS barbers_all ON barbers;
CREATE POLICY barbers_all ON barbers FOR ALL USING (true);

DROP POLICY IF EXISTS stores_all ON stores;
CREATE POLICY stores_all ON stores FOR ALL USING (true);

DROP POLICY IF EXISTS audit_logs_all ON audit_logs;
CREATE POLICY audit_logs_all ON audit_logs FOR ALL USING (true);

SELECT '✅ 数据库迁移完成' AS result;
```

6. 点击 **Run**

---

## 二、配置生产域名

找到每个 Edge Function 文件，修改 `ALLOWED_ORIGINS` 数组：

### 文件列表

- `supabase/functions/auth/index.ts`
- `supabase/functions/recharge/index.ts`
- `supabase/functions/consume/index.ts`
- `supabase/functions/appointment/index.ts`
- `supabase/functions/statistics/index.ts`
- `supabase/functions/finance/index.ts`

### 修改方式

将：
```typescript
const ALLOWED_ORIGINS = [
  'http://localhost:5173',
  'http://localhost:3000',
]
```

改为：
```typescript
const ALLOWED_ORIGINS = [
  'http://localhost:5173',           // 开发环境
  'http://localhost:3000',          // 开发环境
  'https://your-frontend-domain.com', // 改成你的前端域名
]
```

---

## 三、环境变量检查

在 Supabase Dashboard 检查：

1. 进入 **Settings** → **Edge Functions**
2. 确认以下环境变量已设置：
   - `SUPABASE_URL`（通常自动设置）
   - `SUPABASE_SERVICE_ROLE_KEY`（通常自动设置）

---

## 四、前端环境变量

在 `MmbershipWeb` 项目的 `.env` 文件中配置：

```env
VITE_API_URL=https://your-project.supabase.co/functions/v1
```

---

## 五、验证清单

### 数据库
- [ ] 审计日志表创建成功
- [ ] 新字段已添加
- [ ] RLS 已启用

### Edge Functions
- [ ] 所有函数已部署新版本
- [ ] CORS 白名单已配置
- [ ] JWT 验证已启用

### 前端
- [ ] 环境变量已配置
- [ ] 已重新构建部署

---

## 六、测试验证

### 1. 管理员登录
```bash
curl -X POST https://your-project.supabase.co/functions/v1/auth \
  -H "Content-Type: application/json" \
  -d '{"action":"admin_login","username":"superadmin","password":"admin123"}'
```

预期：返回 token 和管理员信息

### 2. Token 验证
用返回的 token 调用其他接口：
```bash
curl -X POST https://your-project.supabase.co/functions/v1/recharge \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{"member_id":"xxx","package_id":"xxx"}'
```

预期：无 token → 401 未授权

### 3. IDOR 测试
- 用会员 A 的 token 为会员 B 充值
- 预期：403 权限不足

---

## 七、回滚方案

如果出现问题，禁用 RLS：

```sql
-- 禁用所有表的 RLS
ALTER TABLE admins DISABLE ROW LEVEL SECURITY;
ALTER TABLE members DISABLE ROW LEVEL SECURITY;
ALTER TABLE recharge_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE consumption_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE appointments DISABLE ROW LEVEL SECURITY;
ALTER TABLE recharge_packages DISABLE ROW LEVEL SECURITY;
ALTER TABLE services DISABLE ROW LEVEL SECURITY;
ALTER TABLE barbers DISABLE ROW LEVEL SECURITY;
ALTER TABLE stores DISABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs DISABLE ROW LEVEL SECURITY;
```

同时将 `config.toml` 中的 `verify_jwt` 改回 `false`。
