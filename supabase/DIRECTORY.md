# Supabase 目录结构说明

> 更新日期：2026-05-23

```
supabase/
│
├── config.toml                  # Supabase 项目配置（端口、数据库参数等）
│
├── migrations/                  # 表结构定义（按编号顺序执行）
│   ├── 01_stores.sql            # 门店表
│   ├── 02_admins.sql            # 管理员表
│   ├── 03_members.sql           # 会员表
│   ├── 04_barbers.sql           # 理发师表
│   ├── 05_services.sql          # 服务项目表
│   ├── 06_recharge_packages.sql # 充值套餐表
│   ├── 07_recharge_records.sql  # 充值记录表
│   ├── 08_consumption_records.sql # 消费记录表
│   ├── 09_appointments.sql      # 预约表
│   ├── 10_rls.sql               # RLS 策略
│   ├── 11_audit_logs.sql        # 审计日志表
│   └── 12_service_types.sql     # 服务类型表
│
├── deploy/                      # 🔴 当前生产部署脚本
│   └── deploy_full.sql          # 全量部署（建表+RLS+触发器+RPC函数+种子数据）
│
├── seed/                        # 种子数据
│   ├── seed.sql                 # 基础种子（管理员+门店）
│   └── seed_packages.sql        # 充值套餐种子数据
│
├── security/                    # 🔒 安全修复方案（6阶段）
│   ├── SECURITY_FIX_PLAN.md     # 完整修复方案文档（漏洞清单+SQL+测试用例）
│   ├── phase1_auth_infra.sql    # Phase 1: 加 auth_user_id 列
│   ├── phase2_batch0_helpers.sql # Phase 2: 辅助函数（rpc_get_current_admin 等）
│   ├── phase3_critical_fix.sql  # Phase 3: 删明文密码回退+密码策略+修改密码
│   ├── phase4_rls.sql           # Phase 4: RLS 激活
│   └── phase6_hardening.sql     # Phase 6: 暴力破解防护+login_attempts 表
│   # ⚠️ Phase 2 的5批RPC改造SQL内嵌在 SECURITY_FIX_PLAN.md 中
│   #    需分批复制到 Dashboard 执行
│
├── functions/                   # Edge Functions（已废弃，留档参考）
│   ├── auth/index.ts            # 认证函数
│   ├── recharge/index.ts        # 充值函数
│   ├── consume/index.ts         # 消费函数
│   ├── appointment/index.ts     # 预约函数
│   ├── finance/index.ts         # 财务函数
│   └── statistics/index.ts      # 统计函数
│
└── archive/                     # 历史迭代版本（归档，非生产使用）
    ├── crud_rpc.sql             # RPC v1 初版
    ├── crud_rpc_simple.sql      # RPC 简化版
    ├── crud_rpc_v2.sql          # RPC v2
    ├── crud_rpc_v3.sql          # RPC v3（最终权威版，已合并进 deploy_full.sql）
    ├── rpc_functions.sql        # 早期 RPC 函数集
    ├── secure_rpc_functions.sql # 早期安全版 RPC
    ├── service_types_rpc.sql    # 服务类型 RPC（已合并进 deploy_full.sql）
    ├── fix_5_functions.sql      # 补丁：修复5个函数
    ├── fix_all_broken_functions.sql  # 补丁：全量修复
    ├── fix_enum_types.sql       # 补丁：枚举类型强转修复
    ├── fix_missing_functions.sql # 补丁：缺失函数补充
    ├── fix_rls.sql              # 补丁：RLS 修复
    ├── fix_rpc_security.sql     # 补丁：RPC 安全修复
    ├── fix_rpc_update_admin.sql # 补丁：更新管理员函数修复
    └── migrate_service_type_names.sql  # 一次性迁移：服务类型英→中
```

## 使用指南

### 新环境部署
执行 `deploy/deploy_full.sql`，一键完成建表+函数+种子。

### 安全修复
按 `security/SECURITY_FIX_PLAN.md` 中的顺序，逐 Phase 执行对应 SQL。每个 Phase 有独立验收标准。

### 修改表结构
1. 在 `migrations/` 中新建递增编号的 SQL 文件
2. 在 `deploy/deploy_full.sql` 中同步更新对应表的 DDL
3. 如需新 RPC 函数，加在 `deploy/deploy_full.sql` 第四部分

### archive 说明
归档文件是开发过程中的迭代产物，仅供参考。生产环境以 `deploy/deploy_full.sql` 为准，修复以 `security/` 为准。
