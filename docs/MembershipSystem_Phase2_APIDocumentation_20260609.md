# MembershipSystemJava REST API 文档

> **项目版本**: Phase 2  
> **文档生成时间**: 2026-06-09  
> **API 基础路径**: `/api/v1`  
> **认证方式**: JWT (JSON Web Token)  
> **数据格式**: JSON

---

## 目录

1. [API 概览](#1-api-概览)
2. [认证说明](#2-认证说明)
3. [错误码说明](#3-错误码说明)
4. [认证管理 API](#4-认证管理-api)
5. [会员管理 API](#5-会员管理-api)
6. [通用响应格式](#6-通用响应格式)
7. [请求示例](#7-请求示例)

---

## 1. API 概览

### 1.1 接口统计

| 模块 | 接口数量 | 描述 |
|------|---------|------|
| 认证管理 | 2 | 管理员登录、会员登录 |
| 会员管理 | 5 | 会员列表、详情、创建、更新、删除 |

### 1.2 接口列表

#### 认证管理 (`/api/v1/auth`)

| HTTP 方法 | 端点 | 描述 | 认证要求 |
|----------|------|------|---------|
| POST | `/admin/login` | 管理员登录 | 无需认证 |
| POST | `/member/login` | 会员登录 | 无需认证 |

#### 会员管理 (`/api/v1/members`)

| HTTP 方法 | 端点 | 描述 | 认证要求 | 权限要求 |
|----------|------|------|---------|---------|
| GET | `/` | 分页查询会员列表 | 需要 JWT Token | 商户权限 |
| GET | `/{id}` | 获取会员详情 | 需要 JWT Token | 商户权限 |
| POST | `/` | 创建新会员 | 需要 JWT Token | 商户权限 |
| PUT | `/{id}` | 更新会员信息 | 需要 JWT Token | 商户权限 |
| DELETE | `/{id}` | 删除会员（逻辑删除） | 需要 JWT Token | 商户权限 |

---

## 2. 认证说明

### 2.1 JWT Token 认证机制

本项目使用 JWT (JSON Web Token) 进行无状态认证。

#### 认证流程

1. **登录获取 Token**: 客户端调用登录接口（`/api/v1/auth/admin/login` 或 `/api/v1/auth/member/login`）
2. **服务器返回 Token**: 认证成功后，服务器返回 JWT Token
3. **后续请求携带 Token**: 客户端在后续请求的 HTTP Header 中携带 Token
4. **服务器验证 Token**: `JwtAuthFilter` 拦截请求，验证 Token 的有效性
5. **注入认证信息**: 验证通过后，将用户身份信息注入 Spring Security 上下文

#### Token 传递方式

在 HTTP 请求头中添加：

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwicm9sZSI6IkFETUlOIiwic3RvcmVJZCI6InN0b3JlMDAxIn0.xxxxx
```

#### Token 中包含的信息

根据 `JwtAuthFilter` 的实现，JWT Token 解析后包含以下信息：

| 字段 | 描述 | 示例值 |
|------|------|--------|
| `userId` | 用户ID | `admin001` / `member001` |
| `role` | 角色 | `ADMIN` / `MEMBER` |
| `storeId` | 商户ID | `store001` |

#### Spring Security 权限映射

JWT 中的 `role` 字段会自动转换为 Spring Security 的权限标识：

- `ADMIN` → `ROLE_ADMIN`
- `MEMBER` → `ROLE_MEMBER`
- `STORE_ADMIN` → `ROLE_STORE_ADMIN`

权限前缀 `ROLE_` 由 `JwtAuthFilter` 自动添加。

### 2.2 认证失败处理

- **Token 缺失**: 返回 `401 Unauthorized`
- **Token 无效/过期**: 返回 `401 Unauthorized`
- **权限不足**: 返回 `403 Forbidden`

---

## 3. 错误码说明

### 3.1 HTTP 状态码

| 状态码 | 说明 | 使用场景 |
|--------|------|---------|
| 200 | 成功 | 请求成功处理 |
| 400 | 请求参数错误 | 参数校验失败（如缺失必填字段、格式错误） |
| 401 | 未认证 | Token 缺失、无效或过期 |
| 403 | 无权限 | 当前用户无权限访问该资源 |
| 404 | 资源不存在 | 查询的会员不存在 |
| 500 | 服务器内部错误 | 系统异常 |

### 3.2 业务错误码

响应体中的 `code` 字段表示业务错误码：

| 错误码 | 说明 | 示例场景 |
|--------|------|---------|
| 200 | 成功 | 操作成功 |
| 400 | 请求参数错误 | 手机格式错误、密码长度不足 |
| 401 | 认证失败 | 用户名或密码错误 |
| 403 | 权限不足 | 无权限操作其他商户的会员 |
| 404 | 资源不存在 | 会员ID不存在 |

### 3.3 错误处理示例

**示例 1: Token 无效**

```json
{
  "code": 401,
  "message": "Unauthorized",
  "data": null
}
```

**示例 2: 请求参数校验失败**

```json
{
  "code": 400,
  "message": "参数校验失败: 手机号格式不正确",
  "data": null
}
```

**示例 3: 资源不存在**

```json
{
  "code": 404,
  "message": "会员不存在",
  "data": null
}
```

---

## 4. 认证管理 API

### 4.1 管理员登录

获取管理员访问令牌。

**端点**: `POST /api/v1/auth/admin/login`

**认证要求**: 无需认证

**接口描述**: 管理员使用用户名和密码登录系统，返回 JWT Token 和管理员基本信息。登录 IP 地址会被记录用于审计和安全分析。

#### 请求参数

**Request Body**: `LoginRequest`

| 参数名 | 类型 | 必填 | 描述 | 示例值 |
|--------|------|------|------|--------|
| username | String | 是 | 管理员用户名 | `admin` |
| password | String | 是 | 管理员密码 | `password123` |

**请求示例**:

```bash
curl -X POST http://localhost:8080/api/v1/auth/admin/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "password123"
  }'
```

#### 响应参数

**Response Body**: `Result<LoginResponse>`

| 参数名 | 类型 | 描述 |
|--------|------|------|
| code | Integer | 业务错误码，200 表示成功 |
| message | String | 响应消息 |
| data | Object | 响应数据，类型为 `LoginResponse` |

**`LoginResponse` 结构**:

| 字段名 | 类型 | 描述 | 示例值 |
|--------|------|------|--------|
| token | String | JWT 访问令牌 | `eyJhbGciOiJIUzI1NiJ9...` |
| username | String | 管理员用户名 | `admin` |
| role | String | 角色 | `ADMIN` |
| storeId | String | 商户ID | `store001` |
| expiresIn | Long | Token 过期时间（秒） | `86400` |

**响应示例**:

```json
{
  "code": 200,
  "message": "登录成功",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJhZG1pbiIsInJvbGUiOiJBRE1JTiIsInN0b3JlSWQiOiJzdG9yZTAwMSJ9.xxxxx",
    "username": "admin",
    "role": "ADMIN",
    "storeId": "store001",
    "expiresIn": 86400
  }
}
```

#### 错误响应

**401 - 用户名或密码错误**:

```json
{
  "code": 401,
  "message": "用户名或密码错误",
  "data": null
}
```

---

### 4.2 会员登录

获取会员访问令牌。

**端点**: `POST /api/v1/auth/member/login`

**认证要求**: 无需认证

**接口描述**: 会员使用手机号和密码登录系统，返回 JWT Token 和会员基本信息（包括会员等级、余额、积分等）。

#### 请求参数

**Request Body**: `MemberLoginRequest`

| 参数名 | 类型 | 必填 | 描述 | 示例值 |
|--------|------|------|------|--------|
| phone | String | 是 | 会员手机号 | `13800138000` |
| password | String | 是 | 会员密码 | `password123` |

**请求示例**:

```bash
curl -X POST http://localhost:8080/api/v1/auth/member/login \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "13800138000",
    "password": "password123"
  }'
```

#### 响应参数

**Response Body**: `Result<MemberLoginResponse>`

| 参数名 | 类型 | 描述 |
|--------|------|------|
| code | Integer | 业务错误码，200 表示成功 |
| message | String | 响应消息 |
| data | Object | 响应数据，类型为 `MemberLoginResponse` |

**`MemberLoginResponse` 结构**:

| 字段名 | 类型 | 描述 | 示例值 |
|--------|------|------|--------|
| token | String | JWT 访问令牌 | `eyJhbGciOiJIUzI1NiJ9...` |
| memberId | String | 会员ID | `member001` |
| name | String | 会员姓名 | `张三` |
| phone | String | 手机号 | `13800138000` |
| level | String | 会员等级 | `GOLD` |
| balance | BigDecimal | 账户余额 | `1000.00` |
| points | Integer | 积分 | `500` |
| storeId | String | 所属商户ID | `store001` |
| expiresIn | Long | Token 过期时间（秒） | `86400` |

**响应示例**:

```json
{
  "code": 200,
  "message": "登录成功",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJtZW1iZXIwMDEiLCJyb2xlIjoiTUVNQkVSIiwic3RvcmVJZCI6InN0b3JlMDAxIn0.xxxxx",
    "memberId": "member001",
    "name": "张三",
    "phone": "13800138000",
    "level": "GOLD",
    "balance": 1000.00,
    "points": 500,
    "storeId": "store001",
    "expiresIn": 86400
  }
}
```

#### 错误响应

**401 - 手机号或密码错误**:

```json
{
  "code": 401,
  "message": "手机号或密码错误",
  "data": null
}
```

---

## 5. 会员管理 API

> **基础路径**: `/api/v1/members`  
> **认证要求**: 所有接口都需要在请求头中携带有效的 JWT Token  
> **权限要求**: 需要商户级别权限（数据范围受当前登录用户所属商户限制）

### 5.1 分页查询会员列表

获取当前商户下的会员列表，支持分页和关键词搜索。

**端点**: `GET /api/v1/members`

**认证要求**: 需要 JWT Token

**权限要求**: 商户权限（`ROLE_ADMIN` 或 `ROLE_STORE_ADMIN`）

**接口描述**: 支持按姓名或手机号关键词搜索，返回当前商户下的会员分页数据。

#### 请求参数

**Query Parameters**:

| 参数名 | 类型 | 必填 | 默认值 | 描述 | 示例值 |
|--------|------|------|--------|------|--------|
| page | Integer | 否 | 1 | 页码，从 1 开始 | `1` |
| size | Integer | 否 | 20 | 每页记录数 | `20` |
| keyword | String | 否 | null | 搜索关键词（姓名/手机号） | `张三` |

**请求示例**:

```bash
curl -X GET "http://localhost:8080/api/v1/members?page=1&size=20&keyword=张三" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..." \
  -H "Content-Type: application/json"
```

#### 响应参数

**Response Body**: `Result<IPage<Member>>`

| 参数名 | 类型 | 描述 |
|--------|------|------|
| code | Integer | 业务错误码，200 表示成功 |
| message | String | 响应消息 |
| data | Object | 分页数据，类型为 `IPage<Member>` |

**`IPage<Member>` 结构**:

| 字段名 | 类型 | 描述 |
|--------|------|------|
| records | Array\<Member\> | 当前页的会员列表 |
| total | Long | 总记录数 |
| size | Long | 每页记录数 |
| current | Long | 当前页码 |
| pages | Long | 总页数 |

**`Member` 结构**:

| 字段名 | 类型 | 描述 | 示例值 |
|--------|------|------|--------|
| id | String | 会员ID | `member001` |
| name | String | 会员姓名 | `张三` |
| phone | String | 手机号 | `13800138000` |
| gender | String | 性别 | `MALE` / `FEMALE` |
| birthday | Date | 生日 | `1990-01-01` |
| level | String | 会员等级 | `GOLD` |
| balance | BigDecimal | 账户余额 | `1000.00` |
| points | Integer | 积分 | `500` |
| storeId | String | 所属商户ID | `store001` |
| createTime | Date | 创建时间 | `2026-01-01 10:00:00` |
| updateTime | Date | 更新时间 | `2026-06-09 13:00:00` |

**响应示例**:

```json
{
  "code": 200,
  "message": "查询成功",
  "data": {
    "records": [
      {
        "id": "member001",
        "name": "张三",
        "phone": "13800138000",
        "gender": "MALE",
        "birthday": "1990-01-01",
        "level": "GOLD",
        "balance": 1000.00,
        "points": 500,
        "storeId": "store001",
        "createTime": "2026-01-01 10:00:00",
        "updateTime": "2026-06-09 13:00:00"
      },
      {
        "id": "member002",
        "name": "李四",
        "phone": "13800138001",
        "gender": "FEMALE",
        "birthday": "1992-05-15",
        "level": "SILVER",
        "balance": 500.00,
        "points": 200,
        "storeId": "store001",
        "createTime": "2026-02-01 11:00:00",
        "updateTime": "2026-06-08 15:00:00"
      }
    ],
    "total": 50,
    "size": 20,
    "current": 1,
    "pages": 3
  }
}
```

---

### 5.2 获取会员详情

根据会员ID获取会员详细信息。

**端点**: `GET /api/v1/members/{id}`

**认证要求**: 需要 JWT Token

**权限要求**: 商户权限

**接口描述**: 根据会员ID查询会员的详细信息。

#### 请求参数

**Path Parameters**:

| 参数名 | 类型 | 必填 | 描述 | 示例值 |
|--------|------|------|------|--------|
| id | String | 是 | 会员ID | `member001` |

**请求示例**:

```bash
curl -X GET "http://localhost:8080/api/v1/members/member001" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..." \
  -H "Content-Type: application/json"
```

#### 响应参数

**Response Body**: `Result<Member>`

**响应示例**:

```json
{
  "code": 200,
  "message": "查询成功",
  "data": {
    "id": "member001",
    "name": "张三",
    "phone": "13800138000",
    "gender": "MALE",
    "birthday": "1990-01-01",
    "level": "GOLD",
    "balance": 1000.00,
    "points": 500,
    "storeId": "store001",
    "createTime": "2026-01-01 10:00:00",
    "updateTime": "2026-06-09 13:00:00"
  }
}
```

#### 错误响应

**404 - 会员不存在**:

```json
{
  "code": 404,
  "message": "会员不存在",
  "data": null
}
```

---

### 5.3 创建新会员

创建新会员记录。

**端点**: `POST /api/v1/members`

**认证要求**: 需要 JWT Token

**权限要求**: 商户权限

**接口描述**: 根据传入的会员信息创建新会员记录，可设置会员基本信息（如姓名、手机号等）。

#### 请求参数

**Request Body**: `Member`

| 参数名 | 类型 | 必填 | 描述 | 示例值 |
|--------|------|------|------|--------|
| name | String | 是 | 会员姓名 | `王五` |
| phone | String | 是 | 手机号 | `13800138002` |
| gender | String | 否 | 性别 | `MALE` / `FEMALE` |
| birthday | Date | 否 | 生日 | `1995-03-20` |
| level | String | 否 | 会员等级 | `NORMAL` |
| balance | BigDecimal | 否 | 账户余额 | `0.00` |
| points | Integer | 否 | 积分 | `0` |

**请求示例**:

```bash
curl -X POST http://localhost:8080/api/v1/members \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "name": "王五",
    "phone": "13800138002",
    "gender": "MALE",
    "birthday": "1995-03-20",
    "level": "NORMAL",
    "balance": 0.00,
    "points": 0
  }'
```

#### 响应参数

**Response Body**: `Result<Member>`

**响应示例**:

```json
{
  "code": 200,
  "message": "创建成功",
  "data": {
    "id": "member003",
    "name": "王五",
    "phone": "13800138002",
    "gender": "MALE",
    "birthday": "1995-03-20",
    "level": "NORMAL",
    "balance": 0.00,
    "points": 0,
    "storeId": "store001",
    "createTime": "2026-06-09 13:08:00",
    "updateTime": "2026-06-09 13:08:00"
  }
}
```

#### 错误响应

**400 - 请求参数错误**:

```json
{
  "code": 400,
  "message": "参数校验失败: 手机号格式不正确",
  "data": null
}
```

---

### 5.4 更新会员信息

根据会员ID更新会员信息。

**端点**: `PUT /api/v1/members/{id}`

**认证要求**: 需要 JWT Token

**权限要求**: 商户权限

**接口描述**: 对指定会员的信息进行更新，传入的会员对象中包含需要修改的字段值。

#### 请求参数

**Path Parameters**:

| 参数名 | 类型 | 必填 | 描述 | 示例值 |
|--------|------|------|------|--------|
| id | String | 是 | 会员ID | `member001` |

**Request Body**: `Member`

| 参数名 | 类型 | 必填 | 描述 | 示例值 |
|--------|------|------|------|--------|
| name | String | 否 | 会员姓名 | `张三（新）` |
| phone | String | 否 | 手机号 | `13800138000` |
| gender | String | 否 | 性别 | `MALE` |
| birthday | Date | 否 | 生日 | `1990-01-01` |
| level | String | 否 | 会员等级 | `PLATINUM` |
| balance | BigDecimal | 否 | 账户余额 | `2000.00` |
| points | Integer | 否 | 积分 | `1000` |

**请求示例**:

```bash
curl -X PUT "http://localhost:8080/api/v1/members/member001" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "name": "张三（新）",
    "level": "PLATINUM",
    "balance": 2000.00,
    "points": 1000
  }'
```

#### 响应参数

**Response Body**: `Result<Member>`

**响应示例**:

```json
{
  "code": 200,
  "message": "更新成功",
  "data": {
    "id": "member001",
    "name": "张三（新）",
    "phone": "13800138000",
    "gender": "MALE",
    "birthday": "1990-01-01",
    "level": "PLATINUM",
    "balance": 2000.00,
    "points": 1000,
    "storeId": "store001",
    "createTime": "2026-01-01 10:00:00",
    "updateTime": "2026-06-09 13:10:00"
  }
}
```

#### 错误响应

**404 - 会员不存在**:

```json
{
  "code": 404,
  "message": "会员不存在",
  "data": null
}
```

**400 - 请求参数错误**:

```json
{
  "code": 400,
  "message": "参数校验失败: 会员等级不正确",
  "data": null
}
```

---

### 5.5 删除会员（逻辑删除）

根据会员ID删除会员（逻辑删除）。

**端点**: `DELETE /api/v1/members/{id}`

**认证要求**: 需要 JWT Token

**权限要求**: 商户权限

**接口描述**: 对指定会员执行逻辑删除操作，而非物理删除，数据仍保留在数据库中。

#### 请求参数

**Path Parameters**:

| 参数名 | 类型 | 必填 | 描述 | 示例值 |
|--------|------|------|------|--------|
| id | String | 是 | 会员ID | `member001` |

**请求示例**:

```bash
curl -X DELETE "http://localhost:8080/api/v1/members/member001" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..." \
  -H "Content-Type: application/json"
```

#### 响应参数

**Response Body**: `Result<Void>`

**响应示例**:

```json
{
  "code": 200,
  "message": "删除成功",
  "data": null
}
```

#### 错误响应

**404 - 会员不存在**:

```json
{
  "code": 404,
  "message": "会员不存在",
  "data": null
}
```

---

## 6. 通用响应格式

### 6.1 响应包装类：`Result<T>`

所有 API 响应都使用统一的包装类 `Result<T>` 返回数据。

**结构定义**:

| 字段名 | 类型 | 描述 | 必填 |
|--------|------|------|------|
| code | Integer | 业务错误码 | 是 |
| message | String | 响应消息 | 是 |
| data | T | 响应数据（泛型） | 否 |

**TypeScript 类型定义**:

```typescript
interface Result<T> {
  code: number;
  message: string;
  data: T | null;
}
```

---

## 7. 请求示例

### 7.1 完整流程示例

#### 场景：管理员登录并查询会员列表

**步骤 1: 管理员登录**

```bash
curl -X POST http://localhost:8080/api/v1/auth/admin/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "password123"
  }'
```

**响应**:

```json
{
  "code": 200,
  "message": "登录成功",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "username": "admin",
    "role": "ADMIN",
    "storeId": "store001",
    "expiresIn": 86400
  }
}
```

**步骤 2: 使用 Token 查询会员列表**

```bash
curl -X GET "http://localhost:8080/api/v1/members?page=1&size=10" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..." \
  -H "Content-Type: application/json"
```

**响应**:

```json
{
  "code": 200,
  "message": "查询成功",
  "data": {
    "records": [
      {
        "id": "member001",
        "name": "张三",
        "phone": "13800138000",
        "level": "GOLD",
        "balance": 1000.00,
        "points": 500
      }
    ],
    "total": 1,
    "size": 10,
    "current": 1,
    "pages": 1
  }
}
```

---

### 7.2 JavaScript (Fetch API) 示例

```javascript
// 管理员登录
async function adminLogin(username, password) {
  const response = await fetch('http://localhost:8080/api/v1/auth/admin/login', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ username, password })
  });
  
  const result = await response.json();
  
  if (result.code === 200) {
    // 保存 Token 到 localStorage
    localStorage.setItem('token', result.data.token);
    return result.data;
  } else {
    throw new Error(result.message);
  }
}

// 查询会员列表
async function getMemberList(page = 1, size = 20, keyword = '') {
  const token = localStorage.getItem('token');
  
  const url = new URL('http://localhost:8080/api/v1/members');
  url.searchParams.append('page', page);
  url.searchParams.append('size', size);
  if (keyword) url.searchParams.append('keyword', keyword);
  
  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  });
  
  const result = await response.json();
  
  if (result.code === 200) {
    return result.data;
  } else {
    throw new Error(result.message);
  }
}

// 创建会员
async function createMember(memberData) {
  const token = localStorage.getItem('token');
  
  const response = await fetch('http://localhost:8080/api/v1/members', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(memberData)
  });
  
  const result = await response.json();
  
  if (result.code === 200) {
    return result.data;
  } else {
    throw new Error(result.message);
  }
}

// 使用示例
(async () => {
  try {
    // 登录
    const loginData = await adminLogin('admin', 'password123');
    console.log('登录成功:', loginData);
    
    // 查询会员列表
    const memberList = await getMemberList(1, 10);
    console.log('会员列表:', memberList);
    
    // 创建会员
    const newMember = await createMember({
      name: '测试会员',
      phone: '13800138099',
      gender: 'MALE',
      level: 'NORMAL'
    });
    console.log('创建成功:', newMember);
    
  } catch (error) {
    console.error('操作失败:', error.message);
  }
})();
```

---

### 7.3 Python (requests) 示例

```python
import requests

# 基础配置
BASE_URL = 'http://localhost:8080/api/v1'
token = None

def admin_login(username, password):
    """管理员登录"""
    global token
    url = f'{BASE_URL}/auth/admin/login'
    data = {
        'username': username,
        'password': password
    }
    
    response = requests.post(url, json=data)
    result = response.json()
    
    if result['code'] == 200:
        token = result['data']['token']
        return result['data']
    else:
        raise Exception(result['message'])

def get_member_list(page=1, size=20, keyword=None):
    """查询会员列表"""
    url = f'{BASE_URL}/members'
    headers = {
        'Authorization': f'Bearer {token}'
    }
    params = {
        'page': page,
        'size': size
    }
    if keyword:
        params['keyword'] = keyword
    
    response = requests.get(url, headers=headers, params=params)
    result = response.json()
    
    if result['code'] == 200:
        return result['data']
    else:
        raise Exception(result['message'])

def create_member(member_data):
    """创建会员"""
    url = f'{BASE_URL}/members'
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    
    response = requests.post(url, headers=headers, json=member_data)
    result = response.json()
    
    if result['code'] == 200:
        return result['data']
    else:
        raise Exception(result['message'])

# 使用示例
if __name__ == '__main__':
    try:
        # 登录
        login_data = admin_login('admin', 'password123')
        print(f'登录成功: {login_data}')
        
        # 查询会员列表
        member_list = get_member_list(page=1, size=10)
        print(f'会员列表: {member_list}')
        
        # 创建会员
        new_member = create_member({
            'name': '测试会员',
            'phone': '13800138099',
            'gender': 'MALE',
            'level': 'NORMAL'
        })
        print(f'创建成功: {new_member}')
        
    except Exception as e:
        print(f'操作失败: {e}')
```

---

## 附录 A: 数据类型说明

### A.1 会员等级 (`level`)

| 等级 | 说明 |
|------|------|
| `NORMAL` | 普通会员 |
| `SILVER` | 银卡会员 |
| `GOLD` | 金卡会员 |
| `PLATINUM` | 白金会员 |
| `DIAMOND` | 钻石会员 |

### A.2 性别 (`gender`)

| 值 | 说明 |
|-----|------|
| `MALE` | 男性 |
| `FEMALE` | 女性 |
| `UNKNOWN` | 未知 |

### A.3 角色 (`role`)

| 角色 | 说明 | Spring Security 权限 |
|------|------|---------------------|
| `ADMIN` | 系统管理员 | `ROLE_ADMIN` |
| `STORE_ADMIN` | 商户管理员 | `ROLE_STORE_ADMIN` |
| `MEMBER` | 会员 | `ROLE_MEMBER` |

---

## 附录 B: 分页说明

### B.1 分页参数

| 参数名 | 类型 | 默认值 | 描述 |
|--------|------|--------|------|
| `page` | Integer | 1 | 页码，从 1 开始 |
| `size` | Integer | 20 | 每页记录数，建议范围：1-100 |

### B.2 分页响应

分页接口返回 `IPage<T>` 结构，包含以下字段：

| 字段名 | 类型 | 描述 |
|--------|------|------|
| `records` | Array\<T\> | 当前页的数据列表 |
| `total` | Long | 总记录数 |
| `size` | Long | 每页记录数 |
| `current` | Long | 当前页码 |
| `pages` | Long | 总页数 |

---

## 文档版本历史

| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|---------|
| 1.0 | 2026-06-09 | 黄志鹏 | 初始版本，包含认证管理和会员管理 API |

---

**文档结束**
