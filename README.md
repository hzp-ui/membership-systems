# 理发店会员管理系统 - 后端

基于 Supabase PostgreSQL 的会员管理后端，采用纯 RPC 函数架构。

## 项目结构

```
MembershipSystem/
├── supabase/
│   ├── migrations/          # 数据库迁移（表结构定义）
│   │   ├── 01_stores.sql           # 门店表
│   │   ├── 02_admins.sql           # 管理员表
│   │   ├── 03_members.sql          # 会员表
│   │   ├── 04_barbers.sql          # 理发师表
│   │   ├── 05_services.sql         # 服务项目表
│   │   ├── 06_recharge_packages.sql # 充值套餐表
│   │   ├── 07_recharge_records.sql # 充值记录表
│   │   ├── 08_consumption_records.sql # 消费记录表
│   │   ├── 09_appointments.sql     # 预约表
│   │   ├── 10_rls.sql              # RLS 策略（已废弃）
│   │   ├── 11_audit_logs.sql       # 审计日志表
│   │   └── 12_service_types.sql    # 服务类型枚举
│   ├── security/            # 安全修复脚本
│   │   ├── phase1_auth_infra.sql   # 认证基础设施
│   │   ├── phase2_batch0_helpers.sql # 辅助函数
│   │   ├── phase3_critical_fix.sql # 关键漏洞修复
│   │   ├── phase4_rls.sql          # RLS 策略（未启用）
│   │   └── phase6_hardening.sql    # 加固：限流+审计
│   ├── seed/                # 种子数据
│   │   ├── seed.sql               # 初始数据
│   │   └── seed_packages.sql      # 充值套餐数据
│   ├── archive/             # 历史版本（已废弃）
│   ├── functions/           # Edge Functions（已废弃）
│   ├── deploy_crud_rpc_v4.sql     # 核心 RPC 函数（生产环境）
│   ├── optimize_indexes.sql       # 性能优化索引
│   └── config.toml                # Supabase 配置
├── test_*.js/mjs           # RPC 函数测试脚本
├── SECURITY_FIX_PLAN.md    # 安全修复计划
└── DEPLOYMENT.md           # 部署指南
```

## 技术架构

### 认证方案

**纯 RPC 登录**（不依赖 Supabase Auth）

```
前端 → rpc_admin_login(username, password) → JWT Token
```

- 密码：bcrypt 哈希存储
- Token：前端 localStorage 存储，RPC 请求通过 `setSession()` 注入
- 数据隔离：前端 `resolveStoreId()` + RPC 层门店过滤

### 数据隔离

| 角色 | 数据范围 |
|------|----------|
| `super_admin` | 全部门店数据 |
| `store_admin` | 仅自己门店数据 |

实现方式：
- RPC 函数内部根据 `admins.role` 判断权限
- `store_admin` 强制使用 `admins.store_id` 过滤
- `super_admin` 可选传 `p_store_id` 参数或查全部

### 安全特性

| Phase | 内容 | 状态 |
|-------|------|------|
| Phase 1 | 认证基础设施 | ✅ |
| Phase 2 | 辅助函数 | ✅ |
| Phase 3 | 漏洞修复 | ✅ |
| Phase 4 | RLS 策略 | ⏸️ 已废弃 |
| Phase 5 | bcrypt 密码升级 | ✅ |
| Phase 6 | 限流 + 审计日志 | ✅ |

## 核心 RPC 函数

### 认证相关

```sql
-- 管理员登录（含限流 + 审计）
rpc_admin_login(p_username, p_password)
→ { success, admin: { id, username, role, store_id, ... }, token }

-- 会员登录
rpc_member_login(p_phone, p_password)
→ { success, member: { id, name, phone, ... }, token }
```

### 门店管理

```sql
rpc_get_stores(p_admin_id)        → [stores]
rpc_create_store(p_admin_id, p_name, p_address, ...)
rpc_update_store(p_admin_id, p_store_id, ...)
rpc_delete_store(p_admin_id, p_store_id)
```

### 会员管理

```sql
rpc_get_members(p_admin_id, p_store_id?)  → [members]
rpc_create_member(p_admin_id, p_name, p_phone, ...)
rpc_update_member(p_admin_id, p_member_id, ...)
rpc_delete_member(p_admin_id, p_member_id)
```

### 充值管理

```sql
rpc_get_recharge_records(p_admin_id, p_store_id?) → [records]
rpc_create_recharge_record(p_admin_id, p_member_id, p_amount, ...)
```

### 消费管理

```sql
rpc_get_consumption_records(p_admin_id, p_store_id?) → [records]
rpc_create_consumption_record(p_admin_id, p_member_id, p_amount, ...)
```

### 统计报表

```sql
rpc_get_dashboard_stats(p_admin_id, p_store_id?) → { stats }
rpc_get_finance_report(p_admin_id, p_store_id?, p_start_date, p_end_date)
```

## 数据库表结构

### 核心表

| 表名 | 说明 | 关键字段 |
|------|------|----------|
| `stores` | 门店 | id, name, address, status |
| `admins` | 管理员 | id, username, password_hash, role, store_id |
| `members` | 会员 | id, name, phone, balance, store_id |
| `barbers` | 理发师 | id, name, store_id, commission_rate |
| `services` | 服务项目 | id, name, price, store_id |
| `recharge_packages` | 充值套餐 | id, name, amount, bonus, store_id |
| `recharge_records` | 充值记录 | id, member_id, amount, bonus |
| `consumption_records` | 消费记录 | id, member_id, amount, service_id |
| `appointments` | 预约 | id, member_id, barber_id, time |
| `audit_logs` | 审计日志 | id, action, operator_id, details |

### 审计与安全

| 表名 | 说明 |
|------|------|
| `audit_logs` | 操作审计日志 |
| `login_attempts` | 登录尝试记录（限流用） |

## 部署指南

### 1. 创建 Supabase 项目

1. 访问 https://supabase.com/
2. 创建新项目，记录 `project ref`

### 2. 执行迁移脚本

按顺序在 SQL Editor 中执行：

```sql
-- 1. 表结构
supabase/migrations/01_stores.sql
supabase/migrations/02_admins.sql
...
supabase/migrations/12_service_types.sql

-- 2. 种子数据
supabase/seed/seed.sql
supabase/seed/seed_packages.sql

-- 3. RPC 函数
supabase/deploy_crud_rpc_v4.sql

-- 4. 性能优化
supabase/optimize_indexes.sql
```

### 3. 配置环境变量

前端 `.env` 文件：

```env
VITE_SUPABASE_URL=https://<project-ref>.supabase.co
VITE_SUPABASE_ANON_KEY=<anon-key>
```

### 4. 创建管理员账号

调用 RPC 函数：

```sql
SELECT rpc_create_admin(
  'admin'::uuid,           -- 操作者 ID（首次用任意 UUID）
  'admin'::text,           -- 用户名
  'admin123'::text,        -- 密码
  'super_admin'::text,     -- 角色
  NULL::uuid               -- 门店 ID（super_admin 可为 NULL）
);
```

## 安全加固

### 登录限流

- 5 次失败后锁定 15 分钟
- 基于 IP + 用户名双重限制
- 实现：`check_login_rate_limit()` 函数

### 审计日志

所有敏感操作自动记录：
- 登录成功/失败
- 会员创建/修改/删除
- 充值/消费记录
- 管理员操作

### 密码安全

- bcrypt 哈希存储（cost factor: 10）
- 自动升级：SHA256 → bcrypt（登录时自动转换）
- 密码策略：最少 6 位

## 性能优化

### 数据库索引

```sql
-- 已创建的索引
CREATE INDEX idx_members_store_id ON members(store_id);
CREATE INDEX idx_members_phone ON members(phone);
CREATE INDEX idx_recharge_records_member_id ON recharge_records(member_id);
CREATE INDEX idx_consumption_records_member_id ON consumption_records(member_id);
CREATE INDEX idx_login_attempts_username ON login_attempts(username);
CREATE INDEX idx_audit_logs_operator_id ON audit_logs(operator_id);
```

### RPC 函数优化

- 使用 `SECURITY DEFINER` 提升权限
- 避免 `SELECT *`，只查必要字段
- 批量操作使用 `unnest()` 减少往返

## 测试

```bash
# 安装依赖
npm install

# 测试所有 RPC 函数
node test_all_rpc_v4.js

# 测试登录流程
node test_login_flow.mjs

# 测试认证
node test_auth_login.mjs
```

## 已知问题

1. **RLS 策略未启用**：纯 RPC 方案下 `auth.uid()` 返回 NULL，改用前端 `resolveStoreId()` 做隔离
2. **Edge Functions 废弃**：CLI 下载失败，改用 RPC 直接访问数据库

## 前端仓库

- GitHub: https://github.com/hzp-ui/membership-system
- 技术栈: React + Vite + TypeScript + Ant Design

## 许可证

MIT
