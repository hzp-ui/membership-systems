# Supabase Auth 迁移完成 - 2026-05-19

## ✅ 已完成

### 数据库迁移 SQL
- [x] 启用 pgcrypto 扩展
- [x] 添加 auth_user_id 字段（admins、members）
- [x] 创建 handle_new_user() 触发器
- [x] 更新 RLS 策略

### 前端代码
- [x] 安装依赖：`npm install @supabase/supabase-js`
- [x] 创建 `src/lib/supabase.ts` - Supabase 客户端
- [x] 修改 `src/stores/auth.ts` - 使用 Supabase Auth
- [x] 修改 `src/services/api.ts` - 使用 Supabase Client
- [x] 修改 `src/pages/admin/Login/index.tsx` - Supabase Auth 登录
- [x] 修改 `src/pages/user/Login/index.tsx` - Supabase Auth 登录/注册

## 📋 待执行

### 1. 数据库迁移（Supabase Dashboard）
在 SQL Editor 执行 `secure_rpc_functions.sql` 或上面提供的迁移 SQL。

### 2. 安装前端依赖
```bash
cd E:\学习\会员系统\MmbershipWeb
npm install @supabase/supabase-js
```

### 3. 配置环境变量
创建/修改 `.env` 文件：
```env
VITE_SUPABASE_URL=https://yknvmkzgsoirjfchabov.supabase.co
VITE_SUPABASE_ANON_KEY=your_anon_key_here
```

### 4. 创建管理员账户（Supabase Auth）
在 Supabase Dashboard → Authentication → Users → Add user

## 📁 修改的文件清单

```
E:\学习\会员系统\MmbershipWeb\
├── .env                          ← 需创建
├── src\
│   ├── lib\
│   │   └── supabase.ts           ← 新建
│   ├── stores\
│   │   └── auth.ts               ← 已修改
│   ├── services\
│   │   └── api.ts                ← 已修改
│   └── pages\
│       ├── admin\Login\index.tsx  ← 已修改
│       └── user\Login\index.tsx   ← 已修改
```

## 🔑 重要说明

### 管理员账户
现有管理员需要重新创建 Supabase Auth 账户：
1. Supabase Dashboard → Authentication → Users
2. 添加新用户（邮箱 + 密码）
3. 关联到 admins 表（通过 auth_user_id）

### 会员注册
会员通过前端注册页面注册，会自动：
1. 创建 Supabase Auth 用户
2. 通过触发器创建 members 记录
3. 关联 auth_user_id

## 📞 测试步骤

1. **管理员登录测试**
   - 在 Supabase Dashboard 创建管理员用户
   - 在前端登录页面测试登录

2. **会员注册测试**
   - 在会员注册页面注册新会员
   - 验证 members 表是否有新记录

3. **权限测试**
   - 验证店长只能操作本店数据
   - 验证会员只能操作自己的数据
