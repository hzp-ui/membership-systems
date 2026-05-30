# 会员系统安全修复方案

## 漏洞概况
原架构存在 16 个安全漏洞（4 Critical + 5 High + 5 Medium + 2 Low），根因是 `p_admin_id` 从客户端传入，导致认证形同虚设。

## 修复阶段（6 阶段）

### Phase 1: 数据库认证绑定 ✅ 已完成
**目标**: 将 `admins` 和 `members` 表与 `auth.users` 绑定

**已完成**:
- ✅ `admins` 表添加 `auth_user_id` 列
- ✅ `members` 表添加 `auth_user_id` 列
- ✅ 创建 11 个 `auth.users` 记录
- ✅ 回填 `auth_user_id` 到现有记录

---

### Phase 2: RPC 函数改造 ✅ 已完成
**目标**: 移除 `p_admin_id` 参数，改用 `auth.uid()` 从 JWT 获取当前用户

**已完成**:
- ✅ 创建 6 个辅助函数（`rpc_get_current_admin`, `rpc_get_current_member`, `rpc_check_store_access_v2`, `rpc_enforce_store_filter_v2`, `rpc_get_current_admin_info`, `rpc_get_current_member_info`）
- ✅ 修改所有 RPC 函数（27 个），移除 `p_admin_id` 参数
- ✅ 使用 `SECURITY DEFINER` 权限执行
- ✅ 使用 `rpc_check_store_access_v2()` 实现行级权限控制

---

### Phase 3: 前端改造 ✅ 已完成
**目标**: 移除前端代码中的 `p_admin_id` 参数，适配新的 RPC 函数签名

**已完成**:
- ✅ 修改 `api.ts`，移除所有 `p_admin_id: aid()` 调用（30+ 个 RPC 调用）
- ✅ 修正 RPC 函数名（`rpc_consume` → `rpc_create_consume_record` 等）
- ✅ 修改登录流程：使用 `supabase.auth.signInWithPassword()` 获取 JWT
- ✅ 修改 `Login.tsx`：`setSession()` 设置 JWT
- ✅ 修改 `auth.ts` Store：添加 `setToken()`、`checkAuth()`、`logout()` 方法
- ✅ TypeScript 编译通过，Vite 构建成功

---

### Phase 4: 激活 RLS + 策略 (进行中)
**目标**: 为所有表激活 Row Level Security，创建策略实现行级权限控制

**RLS 策略逻辑**:
- `super_admin` 可访问所有数据
- `store_admin` 只能访问自己门店的数据

**需要激活 RLS 的表**:
1. `admins`
2. `members`
3. `stores`
4. `barbers`
5. `services`
6. `service_types`
7. `recharge_packages`
8. `recharge_records`
9. `consumption_records`
10. `appointments`

**策略模板**:
```sql
-- 启用 RLS
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;

-- 创建策略：super_admin 可访问所有
CREATE POLICY "Admins can access all" ON table_name
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM admins
      WHERE auth_user_id = auth.uid()
      AND role = 'super_admin'
    )
  );

-- 创建策略：store_admin 只能访问自己门店
CREATE POLICY "Store admins can access own store" ON table_name
  FOR ALL USING (
    store_id IN (
      SELECT store_id FROM admins
      WHERE auth_user_id = auth.uid()
    )
  );
```

---

### Phase 5: 消灭明文密码
**目标**: 将 `admins.password` 和 `members.password` 改为 bcrypt 哈希存储

**步骤**:
1. 修改 `rpc_login` 函数，使用 `crypt()` 函数验证密码
2. 修改 `rpc_change_password` 函数，使用 `crypt()` 函数生成新哈希
3. 迁移现有明文密码到 bcrypt 哈希

---

### Phase 6: 加固 + 限流
**目标**: 添加速率限制、审计日志、输入验证

**步骤**:
1. 创建 `audit_logs` 表，记录所有敏感操作
2. 使用 `pg_net` 扩展实现速率限制
3. 添加输入验证（参数长度、格式检查）

---

## 当前进度
- ✅ Phase 1: 已完成 (2026-05-23)
- ✅ Phase 2: 已完成 (2026-05-26)
- ✅ Phase 3: 已完成 (2026-05-26)
- 🔄 Phase 4: 进行中
- ⏳ Phase 5: 待执行
- ⏳ Phase 6: 待执行

---

## 测试方法
1. **Phase 4 测试**: 使用不同管理员账号登录，验证数据隔离
2. **Phase 5 测试**: 验证登录密码正确性
3. **Phase 6 测试**: 压力测试，验证速率限制

---

## 回滚方案
每个 Phase 的 SQL 脚本都包含对应的回滚脚本（`ROLLBACK_*.sql`），以便在出现问题时快速恢复。

---

**创建时间**: 2026-05-26 18:25
**创建人**: AI Agent (代可行)
**项目**: 理发店会员管理系统
