# 理发店会员管理系统 — Java 重构 PRD

## 1. 项目概述

### 1.1 背景

现有系统基于 Supabase (PostgreSQL + RPC Functions) 后端 + React 前端，存在以下问题：
- Supabase 托管在海外，国内访问延迟高且域名被墙
- RPC 函数散落在 SQL 文件中，维护困难，调试不便
- 纯 RPC 无 ORM，业务逻辑与数据访问耦合在 SQL 中
- 缺少标准化的 API 文档和接口规范

### 1.2 目标

将后端重构为 **Java + Spring Boot + MySQL**，前端重构为独立项目对接 RESTful API，实现：
- 自主部署，消除网络访问障碍
- 标准分层架构，业务逻辑可维护可测试
- RESTful API，前端对接清晰
- 保持与现有系统的功能完全对等

### 1.3 约束

- **前端重构**：React 前端独立为新项目 `MmbershipJavaWeb`，移除 Supabase 依赖，改用 axios 对接 REST API
- **功能对等**：所有现有功能必须 100% 覆盖，不增不减
- **数据迁移**：提供从 Supabase PostgreSQL 到 MySQL 的数据迁移方案
- **自主部署**：后端可部署在任意 Linux 服务器

### 1.4 项目路径

| 项目 | 路径 | 说明 |
|------|------|------|
| **后端** | `E:\学习\会员系统\MembershioSystemJava` | Java + Spring Boot + MySQL |
| **前端** | `E:\学习\会员系统\MmbershipJavaWeb` | React + TypeScript + Vite（移除 Supabase，改用 axios） |

---

## 2. 技术选型

| 层次 | 技术 | 版本 | 说明 |
|------|------|------|------|
| **语言** | Java | 17+ | LTS |
| **框架** | Spring Boot | 3.2+ | 主框架 |
| **ORM** | MyBatis-Plus | 3.5+ | 单表 CRUD 零 SQL，复杂查询写 XML |
| **数据库** | MySQL | 8.0+ | InnoDB，utf8mb4 |
| **认证** | Spring Security + JWT | — | 替代 Supabase Auth |
| **密码** | BCrypt | — | Spring Security 内置，兼容现有 bcrypt 哈希 |
| **API 文档** | SpringDoc (Swagger) | 2.x | OpenAPI 3.0 |
| **构建** | Maven | 3.9+ | 标准化管理依赖 |
| **参数校验** | Jakarta Validation | — | @NotBlank/@NotNull 等 |

---

## 3. 数据库设计

### 3.1 ER 关系

```
stores 1──N admins (store_id)
stores 1──N members (store_id)
stores 1──N barbers (store_id)
stores 1──N services (store_id)
stores 1──N service_types (store_id)
stores 1──N recharge_packages (store_id)
stores 1──N recharge_records (store_id)
stores 1──N consumption_records (store_id)
stores 1──N appointments (store_id)

members 1──N recharge_records (member_id)
members 1──N consumption_records (member_id)
members 1──N appointments (member_id)

barbers 1──N appointments (barber_id)
services 1──N appointments (service_id)
```

### 3.2 表结构

#### stores（门店）

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | CHAR(36) | PK | UUID |
| name | VARCHAR(100) | NOT NULL | 门店名称 |
| address | VARCHAR(255) | | 地址 |
| phone | VARCHAR(20) | | 电话 |
| manager | VARCHAR(50) | | 店长姓名 |
| status | ENUM('active','inactive') | NOT NULL DEFAULT 'active' | 状态 |
| created_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP | 创建时间 |
| updated_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | 更新时间 |

#### admins（管理员）

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | CHAR(36) | PK | UUID |
| username | VARCHAR(50) | NOT NULL UNIQUE | 用户名 |
| password_hash | VARCHAR(255) | NOT NULL | bcrypt 哈希 |
| name | VARCHAR(50) | NOT NULL | 姓名 |
| phone | VARCHAR(20) | | 手机号 |
| role | ENUM('super_admin','store_admin') | NOT NULL DEFAULT 'store_admin' | 角色 |
| store_id | CHAR(36) | | 所属门店（store_admin 必填） |
| status | ENUM('active','inactive') | NOT NULL DEFAULT 'active' | 状态 |
| created_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP | |
| updated_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | |

外键：`store_id → stores.id`

#### members（会员）

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | CHAR(36) | PK | UUID |
| phone | VARCHAR(20) | NOT NULL | 手机号 |
| password_hash | VARCHAR(255) | | 密码哈希（会员可选设密码） |
| name | VARCHAR(50) | NOT NULL | 姓名 |
| level | ENUM('normal','silver','gold','diamond') | NOT NULL DEFAULT 'normal' | 等级 |
| balance | DECIMAL(10,2) | NOT NULL DEFAULT 0.00 | 余额 |
| points | BIGINT | NOT NULL DEFAULT 0 | 积分 |
| store_id | CHAR(36) | NOT NULL | 所属门店 |
| status | ENUM('active','inactive') | NOT NULL DEFAULT 'active' | 状态 |
| created_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP | |
| updated_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | |

外键：`store_id → stores.id`
索引：`idx_members_phone (phone)`，`idx_members_store_id (store_id)`

#### barbers（理发师）

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | CHAR(36) | PK | UUID |
| name | VARCHAR(50) | NOT NULL | 姓名 |
| phone | VARCHAR(20) | | 手机号 |
| specialties | JSON | | 擅长项目，如 ["剪发","烫发"] |
| status | ENUM('active','inactive') | NOT NULL DEFAULT 'active' | 状态 |
| store_id | CHAR(36) | NOT NULL | 所属门店 |
| created_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP | |
| updated_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | |

外键：`store_id → stores.id`

#### services（服务项目）

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | CHAR(36) | PK | UUID |
| type | VARCHAR(50) | NOT NULL | 服务类型（关联 service_types.name） |
| name | VARCHAR(100) | NOT NULL | 服务名称 |
| price | DECIMAL(10,2) | NOT NULL | 原价 |
| discount_normal | DECIMAL(3,2) | NOT NULL DEFAULT 1.00 | 普通会员折扣 |
| discount_silver | DECIMAL(3,2) | NOT NULL DEFAULT 0.95 | 银卡折扣 |
| discount_gold | DECIMAL(3,2) | NOT NULL DEFAULT 0.90 | 金卡折扣 |
| discount_diamond | DECIMAL(3,2) | NOT NULL DEFAULT 0.80 | 钻石折扣 |
| store_id | CHAR(36) | NOT NULL | 所属门店 |
| created_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP | |
| updated_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | |

外键：`store_id → stores.id`

#### service_types（服务类型）

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | CHAR(36) | PK | UUID |
| name | VARCHAR(50) | NOT NULL | 类型名称 |
| store_id | CHAR(36) | | 所属门店（NULL 表示全局） |
| created_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP | |

#### recharge_packages（充值套餐）

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | CHAR(36) | PK | UUID |
| name | VARCHAR(100) | NOT NULL | 套餐名称 |
| amount | DECIMAL(10,2) | NOT NULL | 充值金额 |
| bonus | DECIMAL(10,2) | NOT NULL DEFAULT 0.00 | 赠送金额 |
| status | ENUM('active','inactive') | NOT NULL DEFAULT 'active' | 状态 |
| store_id | CHAR(36) | NOT NULL | 所属门店 |
| created_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP | |
| updated_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | |

外键：`store_id → stores.id`

#### recharge_records（充值记录）

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | CHAR(36) | PK | UUID |
| member_id | CHAR(36) | NOT NULL | 会员 ID |
| amount | DECIMAL(10,2) | NOT NULL | 充值金额 |
| bonus | DECIMAL(10,2) | NOT NULL DEFAULT 0.00 | 赠送金额 |
| package_name | VARCHAR(100) | | 套餐名称（快照） |
| store_id | CHAR(36) | NOT NULL | 门店 ID |
| created_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP | |

外键：`member_id → members.id`，`store_id → stores.id`
索引：`idx_recharge_member_created (member_id, created_at DESC)`，`idx_recharge_store_created (store_id, created_at DESC)`

#### consumption_records（消费记录）

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | CHAR(36) | PK | UUID |
| member_id | CHAR(36) | NOT NULL | 会员 ID |
| amount | DECIMAL(10,2) | NOT NULL | 实付金额 |
| original_price | DECIMAL(10,2) | NOT NULL | 原价 |
| discount | DECIMAL(3,2) | | 折扣率 |
| service_name | VARCHAR(100) | | 服务名称（快照） |
| barber_name | VARCHAR(50) | | 理发师姓名（快照） |
| points_earned | INT | NOT NULL DEFAULT 0 | 获得积分 |
| store_id | CHAR(36) | NOT NULL | 门店 ID |
| created_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP | |

外键：`member_id → members.id`，`store_id → stores.id`
索引：`idx_consumption_member_created (member_id, created_at DESC)`，`idx_consumption_store_created (store_id, created_at DESC)`

#### appointments（预约记录）

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | CHAR(36) | PK | UUID |
| member_id | CHAR(36) | NOT NULL | 会员 ID |
| barber_id | CHAR(36) | NOT NULL | 理发师 ID |
| service_id | CHAR(36) | NOT NULL | 服务项目 ID |
| appointment_time | DATETIME | NOT NULL | 预约时间 |
| status | ENUM('pending','confirmed','completed','cancelled') | NOT NULL DEFAULT 'pending' | 状态 |
| store_id | CHAR(36) | NOT NULL | 门店 ID |
| created_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP | |
| updated_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | |

外键：`member_id → members.id`，`barber_id → barbers.id`，`service_id → services.id`，`store_id → stores.id`
索引：`idx_appointment_store_time (store_id, appointment_time DESC)`

#### login_attempts（登录限流）

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK AUTO_INCREMENT | |
| phone | VARCHAR(20) | NOT NULL | 手机号/用户名 |
| success | TINYINT(1) | NOT NULL DEFAULT 0 | 是否成功 |
| ip_address | VARCHAR(45) | | 客户端 IP |
| attempt_time | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP | |

索引：`idx_login_attempts_phone_success (phone, success)`

#### audit_logs（审计日志）

| 列名 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK AUTO_INCREMENT | |
| user_id | CHAR(36) | | 操作人 ID |
| user_role | VARCHAR(20) | | 操作人角色 |
| action | VARCHAR(50) | NOT NULL | 操作类型 |
| target_type | VARCHAR(50) | | 目标类型 |
| target_id | CHAR(36) | | 目标 ID |
| detail | TEXT | | 详情 |
| store_id | CHAR(36) | | 门店 ID |
| ip_address | VARCHAR(45) | | 客户端 IP |
| created_at | DATETIME | NOT NULL DEFAULT CURRENT_TIMESTAMP | |

索引：`idx_audit_logs_user_created (user_id, created_at DESC)`，`idx_audit_logs_created (created_at DESC)`

---

## 4. API 设计

### 4.1 通用约定

- **Base URL**：`/api/v1`
- **认证方式**：`Authorization: Bearer <JWT>`
- **统一响应格式**：

```json
{
  "code": 200,
  "message": "success",
  "data": { ... }
}
```

错误响应：
```json
{
  "code": 401,
  "message": "用户名或密码错误",
  "data": null
}
```

- **分页参数**：`page`（从1开始）、`size`（默认20，最大100）
- **门店隔离**：`store_admin` 强制使用自身 store_id，`super_admin` 可选传 storeId 参数

### 4.2 认证接口

#### POST `/api/v1/auth/admin/login`

管理员登录。

**请求**：
```json
{
  "username": "admin",
  "password": "admin123"
}
```

**响应**：
```json
{
  "code": 200,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "admin": {
      "id": "uuid",
      "username": "admin",
      "name": "超级管理员",
      "phone": "13800000000",
      "role": "super_admin",
      "store_id": null
    }
  }
}
```

**业务规则**：
- 密码用 BCrypt 验证
- 登录失败记录 login_attempts，5 分钟内连续失败 5 次锁定 30 分钟
- 登录成功写入 audit_logs
- 兼容现有 bcrypt 哈希（从 Supabase 迁移的密码无需重置）

#### POST `/api/v1/auth/member/login`

会员登录。

**请求**：
```json
{
  "phone": "13800001111",
  "password": "123456",
  "store_id": "uuid"
}
```

#### POST `/api/v1/auth/member/register`

会员注册。

**请求**：
```json
{
  "phone": "13800001111",
  "password": "123456",
  "name": "张三",
  "store_id": "uuid"
}
```

### 4.3 门店接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/stores` | 门店列表 | 需登录 |
| GET | `/api/v1/stores/{id}` | 门店详情 | 需登录 |
| POST | `/api/v1/stores` | 创建门店 | super_admin |
| PUT | `/api/v1/stores/{id}` | 更新门店 | super_admin |
| DELETE | `/api/v1/stores/{id}` | 删除门店 | super_admin |

**GET /stores 响应**：
```json
{
  "code": 200,
  "data": [
    {
      "id": "uuid",
      "name": "国贸分店",
      "address": "北京市朝阳区...",
      "phone": "010-12345678",
      "manager": "张经理",
      "status": "active",
      "created_at": "2026-05-18T10:00:00"
    }
  ]
}
```

**POST /stores 请求**：
```json
{
  "name": "国贸分店",
  "address": "北京市朝阳区...",
  "phone": "010-12345678",
  "manager": "张经理"
}
```

### 4.4 管理员接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/admins` | 管理员列表 | 需登录，store_admin 只看本店 |
| POST | `/api/v1/admins` | 创建管理员 | super_admin |
| PUT | `/api/v1/admins/{id}` | 更新管理员 | super_admin |
| DELETE | `/api/v1/admins/{id}` | 删除管理员 | super_admin |

**GET /admins?storeId=xxx 响应**：
```json
{
  "code": 200,
  "data": [
    {
      "id": "uuid",
      "username": "admin1",
      "name": "李店长",
      "phone": "13800001111",
      "role": "store_admin",
      "store_id": "uuid",
      "store_name": "国贸分店",
      "created_at": "2026-05-18T10:00:00"
    }
  ]
}
```

**POST /admins 请求**：
```json
{
  "username": "admin2",
  "password": "admin123",
  "name": "王店长",
  "phone": "13800002222",
  "role": "store_admin",
  "store_id": "uuid"
}
```

业务规则：`store_admin` 角色必须绑定 `store_id`。

### 4.5 会员接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/members` | 会员列表 | 需登录，store_admin 只看本店 |
| GET | `/api/v1/members/{id}` | 会员详情 | 需登录 |
| POST | `/api/v1/members` | 创建会员 | 需登录 |
| PUT | `/api/v1/members/{id}` | 更新会员 | 需登录 |
| DELETE | `/api/v1/members/{id}` | 删除会员 | super_admin |

**GET /members?storeId=xxx 响应**：
```json
{
  "code": 200,
  "data": [
    {
      "id": "uuid",
      "phone": "13800001111",
      "name": "张三",
      "level": "silver",
      "balance": 500.00,
      "points": 200,
      "store_id": "uuid",
      "store_name": "国贸分店",
      "status": "active",
      "created_at": "2026-05-18T10:00:00"
    }
  ]
}
```

### 4.6 理发师接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/barbers` | 理发师列表 | 需登录 |
| GET | `/api/v1/barbers/{id}` | 理发师详情 | 需登录 |
| POST | `/api/v1/barbers` | 创建理发师 | 需登录 |
| PUT | `/api/v1/barbers/{id}` | 更新理发师 | 需登录 |
| DELETE | `/api/v1/barbers/{id}` | 删除理发师 | 需登录 |

### 4.7 服务项目接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/services` | 服务列表 | 需登录 |
| POST | `/api/v1/services` | 创建服务 | 需登录 |
| PUT | `/api/v1/services/{id}` | 更新服务 | 需登录 |
| DELETE | `/api/v1/services/{id}` | 删除服务 | 需登录 |

### 4.8 服务类型接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/service-types` | 服务类型列表 | 需登录 |
| POST | `/api/v1/service-types` | 创建服务类型 | 需登录 |
| DELETE | `/api/v1/service-types/{id}` | 删除服务类型 | 需登录 |

### 4.9 充值套餐接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/packages` | 套餐列表 | 需登录 |
| POST | `/api/v1/packages` | 创建套餐 | 需登录 |
| PUT | `/api/v1/packages/{id}` | 更新套餐 | 需登录 |
| DELETE | `/api/v1/packages/{id}` | 删除套餐 | 需登录 |

### 4.10 充值记录接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/recharge-records` | 充值记录列表 | 需登录，store_admin 只看本店 |
| POST | `/api/v1/recharge-records` | 创建充值记录 | 需登录 |

**POST /recharge-records 请求**（原子操作：充值+加余额+加积分）：
```json
{
  "member_id": "uuid",
  "amount": 500.00,
  "bonus": 50.00,
  "package_name": "标准卡"
}
```

业务规则：
- 充值金额 + 赠送金额 → 会员 balance 增加
- 每 1 元充值 = 1 积分 → 会员 points 增加
- 原子操作，事务保证一致性

### 4.11 消费记录接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/consumption-records` | 消费记录列表 | 需登录，store_admin 只看本店 |
| POST | `/api/v1/consumption-records` | 创建消费记录 | 需登录 |

**POST /consumption-records 请求**（原子操作：消费+扣余额+加积分）：
```json
{
  "member_id": "uuid",
  "service_id": "uuid",
  "barber_id": "uuid"
}
```

业务规则：
- 根据 service.price × 会员等级折扣率 = 实付金额
- 扣减会员 balance（余额不足拒绝）
- 积分：每 1 元消费 = 1 积分
- 原子操作，事务保证一致性

### 4.12 预约接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/appointments` | 预约列表 | 需登录 |
| POST | `/api/v1/appointments` | 创建预约 | 需登录 |
| PUT | `/api/v1/appointments/{id}/confirm` | 确认预约 | 需登录 |
| PUT | `/api/v1/appointments/{id}/complete` | 完成预约 | 需登录 |
| PUT | `/api/v1/appointments/{id}/cancel` | 取消预约 | 需登录 |

### 4.13 统计接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/stats/revenue` | 营收统计 | 需登录 |
| GET | `/api/v1/stats/member-growth` | 会员增长统计 | 需登录 |
| GET | `/api/v1/stats/hot-services` | 热门服务排行 | 需登录 |

**GET /stats/revenue?storeId=xxx&startDate=2026-05-01&endDate=2026-05-31&dimension=day**：
```json
{
  "code": 200,
  "data": [
    { "date": "2026-05-28", "revenue": 3500.00, "count": 15 }
  ]
}
```

### 4.14 财务接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/finance/summary` | 财务汇总 | 需登录 |
| GET | `/api/v1/finance/daily-statements` | 每日对账单 | 需登录 |

**GET /finance/summary?storeId=xxx&startDate=2026-05-01&endDate=2026-05-31**：
```json
{
  "code": 200,
  "data": {
    "recharge_income": 25000.00,
    "consumption_income": 18000.00,
    "refund_amount": 500.00,
    "net_income": 17500.00
  }
}
```

---

## 5. 项目结构

```
MembershipSystemJava/
├── pom.xml
├── src/
│   ├── main/
│   │   ├── java/com/membership/
│   │   │   ├── MembershipApplication.java          # 启动类
│   │   │   │
│   │   │   ├── config/                             # 配置
│   │   │   │   ├── SecurityConfig.java             # Spring Security + JWT
│   │   │   │   ├── MyBatisPlusConfig.java          # MyBatis-Plus 配置
│   │   │   │   ├── CorsConfig.java                 # 跨域配置
│   │   │   │   └── SwaggerConfig.java              # API 文档配置
│   │   │   │
│   │   │   ├── security/                           # 认证授权
│   │   │   │   ├── JwtTokenProvider.java           # JWT 生成/解析
│   │   │   │   ├── JwtAuthFilter.java              # JWT 过滤器
│   │   │   │   └── StoreAccessChecker.java         # 门店权限校验
│   │   │   │
│   │   │   ├── common/                             # 通用
│   │   │   │   ├── Result.java                     # 统一响应
│   │   │   │   ├── BusinessException.java          # 业务异常
│   │   │   │   └── GlobalExceptionHandler.java     # 全局异常处理
│   │   │   │
│   │   │   ├── controller/                         # 控制层
│   │   │   │   ├── AuthController.java
│   │   │   │   ├── StoreController.java
│   │   │   │   ├── AdminController.java
│   │   │   │   ├── MemberController.java
│   │   │   │   ├── BarberController.java
│   │   │   │   ├── ServiceController.java
│   │   │   │   ├── ServiceTypeController.java
│   │   │   │   ├── PackageController.java
│   │   │   │   ├── RechargeRecordController.java
│   │   │   │   ├── ConsumptionRecordController.java
│   │   │   │   ├── AppointmentController.java
│   │   │   │   ├── StatsController.java
│   │   │   │   └── FinanceController.java
│   │   │   │
│   │   │   ├── service/                            # 服务层
│   │   │   │   ├── AuthService.java
│   │   │   │   ├── StoreService.java
│   │   │   │   ├── AdminService.java
│   │   │   │   ├── MemberService.java
│   │   │   │   ├── BarberService.java
│   │   │   │   ├── ServiceService.java
│   │   │   │   ├── PackageService.java
│   │   │   │   ├── RechargeRecordService.java
│   │   │   │   ├── ConsumptionRecordService.java
│   │   │   │   ├── AppointmentService.java
│   │   │   │   ├── StatsService.java
│   │   │   │   └── FinanceService.java
│   │   │   │
│   │   │   ├── mapper/                             # 数据访问层
│   │   │   │   ├── StoreMapper.java
│   │   │   │   ├── AdminMapper.java
│   │   │   │   ├── MemberMapper.java
│   │   │   │   ├── BarberMapper.java
│   │   │   │   ├── ServiceMapper.java
│   │   │   │   ├── ServiceTypeMapper.java
│   │   │   │   ├── PackageMapper.java
│   │   │   │   ├── RechargeRecordMapper.java
│   │   │   │   ├── ConsumptionRecordMapper.java
│   │   │   │   ├── AppointmentMapper.java
│   │   │   │   ├── LoginAttemptMapper.java
│   │   │   │   └── AuditLogMapper.java
│   │   │   │
│   │   │   ├── entity/                             # 实体类
│   │   │   │   ├── Store.java
│   │   │   │   ├── Admin.java
│   │   │   │   ├── Member.java
│   │   │   │   ├── Barber.java
│   │   │   │   ├── Service.java
│   │   │   │   ├── ServiceType.java
│   │   │   │   ├── RechargePackage.java
│   │   │   │   ├── RechargeRecord.java
│   │   │   │   ├── ConsumptionRecord.java
│   │   │   │   ├── Appointment.java
│   │   │   │   ├── LoginAttempt.java
│   │   │   │   └── AuditLog.java
│   │   │   │
│   │   │   └── dto/                                # 数据传输对象
│   │   │       ├── request/
│   │   │       │   ├── LoginRequest.java
│   │   │       │   ├── MemberRegisterRequest.java
│   │   │       │   ├── StoreCreateRequest.java
│   │   │       │   ├── AdminCreateRequest.java
│   │   │       │   ├── RechargeRequest.java
│   │   │       │   ├── ConsumeRequest.java
│   │   │       │   └── AppointmentRequest.java
│   │   │       └── response/
│   │   │           ├── LoginResponse.java
│   │   │           ├── AdminVO.java
│   │   │           ├── MemberVO.java
│   │   │           ├── FinanceSummaryVO.java
│   │   │           └── DailyStatementVO.java
│   │   │
│   │   └── resources/
│   │       ├── application.yml                     # 主配置
│   │       ├── application-dev.yml                 # 开发环境
│   │       ├── application-prod.yml                # 生产环境
│   │       ├── db/
│   │       │   └── schema.sql                      # DDL（建表语句）
│   │       │   └── seed.sql                        # 初始数据
│   │       └── mapper/                             # MyBatis XML（复杂查询）
│   │           ├── StatsMapper.xml
│   │           └── FinanceMapper.xml
│   │
│   └── test/
│       └── java/com/membership/
│           ├── service/
│           └── controller/
│
├── docs/
│   ├── PRD.md                                      # 本文档
│   ├── API.md                                      # API 详细文档
│   └── MIGRATION.md                                # 数据迁移指南
│
└── scripts/
    └── migrate_from_supabase.sh                    # 数据迁移脚本
```

---

## 6. 核心业务逻辑

### 6.1 认证流程

```
1. 前端 POST /api/v1/auth/admin/login { username, password }
2. 后端查询 admins 表 WHERE username = ?
3. BCrypt.checkpw(password, admin.passwordHash)
4. 检查 login_attempts 限流（5次/5分钟 → 锁定30分钟）
5. 生成 JWT（payload: adminId, role, storeId），有效期 24h
6. 写入 audit_logs
7. 返回 { token, admin }
8. 前端后续请求携带 Authorization: Bearer <token>
```

### 6.2 门店数据隔离

```java
// StoreAccessChecker.java
public String resolveStoreId(Admin admin, String requestedStoreId) {
    if ("super_admin".equals(admin.getRole())) {
        return requestedStoreId; // 超管可传可不传
    }
    return admin.getStoreId(); // 店长强制用自己门店
}
```

所有列表查询接口调用 `resolveStoreId()` 后，将结果作为 WHERE 条件：
- 返回非 null → `WHERE store_id = ?`
- 返回 null → 不加 store_id 过滤（超管查全部）

### 6.3 充值原子操作

```java
@Transactional
public RechargeRecord recharge(String memberId, BigDecimal amount, BigDecimal bonus, String packageName) {
    // 1. 创建充值记录
    RechargeRecord record = new RechargeRecord();
    record.setMemberId(memberId);
    record.setAmount(amount);
    record.setBonus(bonus);
    record.setPackageName(packageName);
    rechargeRecordMapper.insert(record);

    // 2. 更新会员余额和积分
    Member member = memberMapper.selectById(memberId);
    member.setBalance(member.getBalance().add(amount).add(bonus));
    member.setPoints(member.getPoints() + amount.intValue());
    memberMapper.updateById(member);

    return record;
}
```

### 6.4 消费原子操作

```java
@Transactional
public ConsumptionRecord consume(String memberId, String serviceId, String barberId) {
    Member member = memberMapper.selectByIdForUpdate(memberId); // 悲观锁防并发
    Service service = serviceMapper.selectById(serviceId);

    // 1. 计算折扣
    BigDecimal discountRate = getDiscountRate(member.getLevel(), service);
    BigDecimal actualAmount = service.getPrice().multiply(discountRate);

    // 2. 校验余额
    if (member.getBalance().compareTo(actualAmount) < 0) {
        throw new BusinessException("余额不足");
    }

    // 3. 扣减余额 + 加积分
    member.setBalance(member.getBalance().subtract(actualAmount));
    member.setPoints(member.getPoints() + actualAmount.intValue());
    memberMapper.updateById(member);

    // 4. 创建消费记录
    ConsumptionRecord record = new ConsumptionRecord();
    record.setMemberId(memberId);
    record.setAmount(actualAmount);
    record.setOriginalPrice(service.getPrice());
    record.setDiscount(discountRate);
    record.setServiceName(service.getName());
    // barberName 快照
    record.setPointsEarned(actualAmount.intValue());
    consumptionRecordMapper.insert(record);

    return record;
}
```

### 6.5 折扣率计算

```java
private BigDecimal getDiscountRate(String level, Service service) {
    return switch (level) {
        case "diamond" -> service.getDiscountDiamond();
        case "gold" -> service.getDiscountGold();
        case "silver" -> service.getDiscountSilver();
        default -> service.getDiscountNormal(); // normal = 1.00
    };
}
```

---

## 7. 安全设计

### 7.1 JWT 方案

| 配置项 | 值 |
|--------|-----|
| 签名算法 | HS256 |
| 密钥 | 配置文件中配置，至少 256 位 |
| 有效期 | 24 小时 |
| Payload | `{ "adminId": "uuid", "role": "super_admin", "storeId": "uuid" }` |

### 7.2 密码策略

- 存储：BCrypt（strength=10）
- 登录验证：`BCryptPasswordEncoder.matches()`
- 迁移兼容：从 Supabase 迁移的 bcrypt 哈希可直接验证

### 7.3 登录限流

- 同一用户名/手机号，5 分钟内连续失败 5 次，锁定 30 分钟
- 每次登录尝试（无论成功失败）记录 `login_attempts`
- 定期清理 7 天前的记录（定时任务或手动）

### 7.4 接口权限

| 权限级别 | 可访问接口 |
|----------|-----------|
| 未认证 | POST /auth/admin/login, POST /auth/member/login, POST /auth/member/register |
| 已认证（任意角色） | GET 类查询接口 |
| super_admin | POST/PUT/DELETE 类写接口 |
| store_admin | 限定自身门店的写操作 |

### 7.5 CORS

```yaml
# application.yml
cors:
  allowed-origins: "http://localhost:5174,https://你的域名"
  allowed-methods: "GET,POST,PUT,DELETE"
```

---

## 8. 配置文件

### application.yml

```yaml
server:
  port: 8080
  servlet:
    context-path: /api/v1

spring:
  datasource:
    url: jdbc:mysql://localhost:3306/membership?useUnicode=true&characterEncoding=utf8mb4&serverTimezone=Asia/Shanghai
    username: root
    password: ${DB_PASSWORD}
    driver-class-name: com.mysql.cj.jdbc.Driver
  jackson:
    date-format: yyyy-MM-dd HH:mm:ss
    time-zone: Asia/Shanghai

mybatis-plus:
  configuration:
    map-underscore-to-camel-case: true
    log-impl: org.apache.ibatis.logging.stdout.StdOutImpl  # 开发环境
  global-config:
    db-config:
      id-type: assign_uuid
      logic-delete-field: deleted
      logic-delete-value: 1
      logic-not-delete-value: 0

jwt:
  secret: ${JWT_SECRET}
  expiration: 86400000  # 24h in ms

logging:
  level:
    com.membership: DEBUG
```

---

## 9. 数据迁移方案

### 9.1 迁移步骤

1. **导出 Supabase 数据**：通过 SQL Editor 导出各表为 CSV
2. **类型映射**：

| PostgreSQL | MySQL |
|------------|-------|
| UUID | CHAR(36) |
| TIMESTAMPTZ | DATETIME |
| DECIMAL | DECIMAL(10,2) |
| TEXT | VARCHAR/TEXT |
| JSONB | JSON |
| store_status (ENUM) | ENUM('active','inactive') |
| admin_role (ENUM) | ENUM('super_admin','store_admin') |
| member_level (ENUM) | ENUM('normal','silver','gold','diamond') |

3. **密码迁移**：bcrypt 哈希原样迁移，Spring BCryptPasswordEncoder 直接兼容
4. **UUID 格式**：保持原 UUID 字符串不变
5. **ID 策略**：新记录用 MyBatis-Plus `assign_uuid` 生成

### 9.2 初始数据

迁移时需包含：
- 3 个门店（总部旗舰店、国贸分店、望京分店）
- 测试管理员（admin/admin123, admin1/admin123, admin3/admin123）
- 15 个充值套餐（3 门店 × 5 套餐）

---

## 10. 开发里程碑

### Phase 1：基础框架（2天）

- [ ] Maven 项目初始化
- [ ] Spring Boot + MyBatis-Plus 集成
- [ ] MySQL DDL 建表 + seed 数据
- [ ] 统一响应 Result + 全局异常处理
- [ ] CORS 配置

### Phase 2：认证模块（2天）

- [ ] JWT 工具类（生成/解析/验证）
- [ ] Spring Security 配置
- [ ] AuthController（admin login, member login, member register）
- [ ] 登录限流（login_attempts）
- [ ] 审计日志（audit_logs）

### Phase 3：核心 CRUD（3天）

- [ ] StoreController + Service + Mapper
- [ ] AdminController + Service + Mapper
- [ ] MemberController + Service + Mapper
- [ ] BarberController + Service + Mapper
- [ ] ServiceController + Service + Mapper
- [ ] ServiceTypeController + Service + Mapper
- [ ] PackageController + Service + Mapper

### Phase 4：业务模块（3天）

- [ ] 充值记录（原子操作：充值+加余额+加积分）
- [ ] 消费记录（原子操作：消费+扣余额+加积分+折扣计算）
- [ ] 预约管理（创建/确认/完成/取消）
- [ ] 门店数据隔离（resolveStoreId 全链路）

### Phase 5：统计与财务（2天）

- [ ] 营收统计 API
- [ ] 会员增长统计 API
- [ ] 热门服务排行 API
- [ ] 财务汇总 API
- [ ] 每日对账单 API

### Phase 6：前端重构 + 测试（3天）

- [ ] 创建 `MmbershipJavaWeb` 前端项目（从旧项目复制）
- [ ] 移除 Supabase 依赖，安装 axios
- [ ] 新建 `src/lib/axios.ts`（axios 实例 + JWT 拦截器）
- [ ] 重写 `api.ts`（rpcCall → axios 调用）
- [ ] 修改 `auth.ts`（移除 supabase，改用 axios）
- [ ] 修改 `Login/index.tsx`（改用 axios 登录）
- [ ] 端到端功能测试
- [ ] Swagger API 文档验证

### Phase 7：部署上线（1天）

- [ ] 打包 JAR
- [ ] 服务器部署（systemd / Docker）
- [ ] Nginx 反向代理 + HTTPS
- [ ] 前端部署对接后端 API

**总计：约 16 个工作日**

---

## 11. 测试账号

| 用户名 | 密码 | 角色 | 门店 |
|--------|------|------|------|
| admin | admin123 | super_admin | 全部 |
| admin1 | admin123 | store_admin | 国贸分店 |
| admin3 | admin123 | store_admin | 天河分店 |

---

## 12. 前端重构要点

前端从旧项目 `MmbershipWeb` 复制到新项目 `MmbershipJavaWeb`，移除 Supabase 依赖，改用 axios 对接 REST API。

**前端项目路径**：`E:\学习\会员系统\MmbershipJavaWeb`

### 12.1 项目初始化

```bash
# 从旧项目复制（保留页面组件、样式、类型定义）
cp -r MmbershipWeb/ MmbershipJavaWeb/
cd MmbershipJavaWeb

# 移除 Supabase 依赖
npm uninstall @supabase/supabase-js

# 安装 axios
npm install axios

# 删除 Supabase 配置文件
rm src/lib/supabase.ts
```

### 12.2 api.ts 改造

```typescript
// 之前：Supabase RPC
const { data, error } = await supabase.rpc('rpc_get_stores', { p_store_id: ... })

// 之后：REST API（axios）
import api from '@/lib/axios'
const { data } = await api.get('/stores', { params: { storeId: ... } })
```

新增 `src/lib/axios.ts`：

```typescript
import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080/api/v1',
  timeout: 10000,
})

// 请求拦截器：自动带 JWT
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('auth_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// 响应拦截器：统一错误处理
api.interceptors.response.use(
  (res) => {
    if (res.data.code !== 200) return Promise.reject(new Error(res.data.message))
    return res.data  // 直接返回 data 字段
  },
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('auth_token')
      window.location.href = '/admin/login'
    }
    return Promise.reject(err)
  }
)

export default api
```

### 12.3 auth.ts 改造

```typescript
// 之前：supabase.rpc('rpc_admin_login', ...)
// 之后：
import api from '@/lib/axios'
const res = await api.post('/auth/admin/login', { username, password })
// res.data = { token, admin }
localStorage.setItem('auth_token', res.data.token)
```

### 12.4 环境变量

```env
# .env
VITE_API_BASE_URL=http://localhost:8080/api/v1
```

生产环境：
```env
VITE_API_BASE_URL=https://你的域名/api/v1
```

### 12.5 改造清单

| 文件 | 改动 |
|------|------|
| `src/lib/axios.ts` | **新建**，axios 实例 + 拦截器 |
| `src/lib/supabase.ts` | **删除** |
| `src/services/api.ts` | **重写**，所有 rpcCall → axios 调用 |
| `src/stores/auth.ts` | **修改**，移除 supabase 依赖，改用 axios |
| `src/pages/admin/Login/index.tsx` | **修改**，改用 axios 登录 |
| `package.json` | **修改**，移除 @supabase/supabase-js，添加 axios |
| `.env` | **修改**，VITE_API_BASE_URL 替换 Supabase 配置 |
| 页面组件 | **不变** |
