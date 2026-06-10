# MembershipSystem - 会员管理系统

> 基于 Spring Boot 的会员管理系统，提供会员管理、充值消费、预约理发、数据统计等功能。

[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.4.5-brightgreen.svg)](https://spring.io/projects/spring-boot)
[![Java](https://img.shields.io/badge/Java-17-purple.svg)](https://www.oracle.com/java/)
[![MyBatis-Plus](https://img.shields.io/badge/MyBatis--Plus-3.5.12-blue.svg)](https://baomidou.com/)
[![JWT](https://img.shields.io/badge/JWT-0.11.5-orange.svg)](https://jwt.io/)

---

## 📋 目录

- [项目简介](#项目简介)
- [功能特性](#功能特性)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [配置说明](#配置说明)
- [API 文档](#api-文档)
- [使用示例](#使用示例)
- [注意事项](#注意事项)

---

## 项目简介

MembershipSystem 是一个基于 Spring Boot 的会员管理系统，提供完整的会员生命周期管理功能。系统支持多门店管理、会员等级折扣、充值消费、预约理发、数据统计分析等核心业务功能。

### 核心价值

- **提升会员体验**：会员可通过手机号快速登录，享受等级折扣和积分累积
- **提高管理效率**：提供完善的后台管理功能，支持多门店、多角色权限控制
- **数据驱动决策**：提供丰富的数据统计报表，帮助管理者做出科学决策
- **保障系统安全**：采用 JWT + Spring Security 实现认证授权，保障数据安全

---

## 功能特性

### 👥 会员管理
- ✅ 会员信息 CRUD（创建、查询、更新、删除）
- ✅ 会员等级体系（普通、银卡、金卡、钻石）
- ✅ 会员余额和积分管理
- ✅ 会员消费记录查询

### 💰 充值消费
- ✅ 会员充值（支持套餐充值和自定义金额）
- ✅ 消费扣款（自动按会员等级折扣计算）
- ✅ 充值赠送金额
- ✅ 消费积分累积

### 📅 预约管理
- ✅ 会员预约理发服务
- ✅ 预约状态流转（待确认 → 已确认 → 已完成/已取消）
- ✅ 按门店、会员、时间查询预约记录

### 📊 数据统计
- ✅ 今日营收统计
- ✅ 新增会员统计
- ✅ 热门服务项目统计
- ✅ 会员增长趋势分析

### 🔐 安全认证
- ✅ JWT Token 认证
- ✅ 登录失败锁定（5次/15分钟）
- ✅ 密码 BCrypt 加密
- ✅ 超级管理员/门店管理员角色权限控制

---

## 技术栈

### 后端技术

| 技术 | 版本 | 说明 |
|------|------|------|
| **Java** | 17 | 编程语言 |
| **Spring Boot** | 3.4.5 | 快速开发框架 |
| **MyBatis-Plus** | 3.5.12 | ORM 框架 |
| **MySQL** | 8.0+ | 关系型数据库 |
| **Lombok** | 1.18.38 | 简化 Java 代码 |
| **JWT** | 0.11.5 | 认证授权 |
| **Spring Security** | 6.x | 安全框架 |
| **SpringDoc OpenAPI** | 2.8.5 | API 文档生成 |
| **HuTool** | 5.8.34 | Java 工具库 |

### 前端技术（可选）

| 技术 | 版本 | 说明 |
|------|------|------|
| HTML5 + CSS3 + JavaScript | - | 原生前端技术 |
| Thymeleaf | 3.x | 模板引擎（可选） |
| Vue.js / React | - | 前端框架（可选） |

### 开发工具

| 工具 | 说明 |
|------|------|
| **Maven** | 项目构建工具 |
| **Git** | 版本控制 |
| **Postman** | API 测试工具 |
| **Swagger UI** | API 文档可视化 |

---

## 项目结构

```
MembershipSystemJava/
├── src/main/java/com/membership/
│   ├── MembershipApplication.java          # 启动类
│   │
│   ├── config/                           # 配置类
│   │   ├── SecurityConfig.java            # Spring Security 配置
│   │   ├── MyBatisPlusConfig.java        # MyBatis-Plus 配置
│   │   └── OpenApiConfig.java            # Swagger/OpenAPI 配置
│   │
│   ├── controller/                        # 控制器层
│   │   ├── AuthController.java            # 认证接口
│   │   ├── MemberController.java          # 会员管理接口
│   │   ├── StoreController.java           # 门店管理接口
│   │   ├── BarberController.java          # 理发师管理接口
│   │   ├── ServiceController.java         # 服务项目管理接口
│   │   ├── AppointmentController.java     # 预约管理接口
│   │   ├── ConsumptionController.java     # 消费记录接口
│   │   ├── RechargeController.java       # 充值记录接口
│   │   ├── DashboardController.java      # 数据统计接口
│   │   └── AdminController.java          # 管理员管理接口
│   │
│   ├── service/                           # 业务层接口
│   │   ├── MemberService.java
│   │   ├── StoreService.java
│   │   ├── BarberService.java
│   │   ├── ServiceItemService.java
│   │   ├── AppointmentService.java
│   │   ├── ConsumptionService.java
│   │   ├── RechargeService.java
│   │   ├── DashboardService.java
│   │   ├── AdminService.java
│   │   ├── AuthService.java
│   │   └── AuditLogService.java
│   │
│   ├── service/impl/                      # 业务层实现
│   │   ├── MemberServiceImpl.java
│   │   ├── StoreServiceImpl.java
│   │   ├── BarberServiceImpl.java
│   │   ├── ServiceItemServiceImpl.java
│   │   ├── AppointmentServiceImpl.java
│   │   ├── ConsumptionServiceImpl.java
│   │   ├── RechargeServiceImpl.java
│   │   ├── DashboardServiceImpl.java
│   │   ├── AdminServiceImpl.java
│   │   ├── AuthServiceImpl.java
│   │   └── AuditLogServiceImpl.java
│   │
│   ├── mapper/                            # 数据访问层
│   │   ├── MemberMapper.java
│   │   ├── StoreMapper.java
│   │   ├── BarberMapper.java
│   │   ├── ServiceItemMapper.java
│   │   ├── AppointmentMapper.java
│   │   ├── ConsumptionRecordMapper.java
│   │   ├── RechargeRecordMapper.java
│   │   ├── AdminMapper.java
│   │   ├── LoginAttemptMapper.java
│   │   └── AuditLogMapper.java
│   │
│   ├── entity/                            # 实体类
│   │   ├── Member.java
│   │   ├── Store.java
│   │   ├── Barber.java
│   │   ├── ServiceItem.java
│   │   ├── Appointment.java
│   │   ├── ConsumptionRecord.java
│   │   ├── RechargeRecord.java
│   │   ├── RechargePackage.java
│   │   ├── Admin.java
│   │   └── AuditLog.java
│   │
│   ├── dto/                               # 数据传输对象
│   │   ├── request/                       # 请求 DTO
│   │   │   ├── LoginRequest.java
│   │   │   ├── MemberLoginRequest.java
│   │   │   ├── ConsumeRequest.java
│   │   │   ├── RechargeRequest.java
│   │   │   └── AppointmentRequest.java
│   │   └── response/                      # 响应 DTO
│   │       ├── LoginResponse.java
│   │       ├── MemberLoginResponse.java
│   │       ├── MemberVO.java
│   │       ├── AppointmentVO.java
│   │       ├── ConsumptionRecordVO.java
│   │       └── RechargeRecordVO.java
│   │
│   ├── enums/                             # 枚举类
│   │   ├── AdminRole.java
│   │   ├── AppointmentStatus.java
│   │   ├── MemberLevel.java
│   │   └── Status.java
│   │
│   ├── security/                          # 安全相关
│   │   ├── JwtUtil.java                   # JWT 工具类
│   │   ├── JwtAuthFilter.java             # JWT 认证过滤器
│   │   ├── UnauthorizedHandler.java       # 未授权处理
│   │   └── StoreAccessUtil.java          # 门店访问权限工具
│   │
│   └── common/                            # 公共类
│       ├── Result.java                     # 统一响应结果
│       ├── BusinessException.java          # 业务异常
│       └── GlobalExceptionHandler.java     # 全局异常处理
│
├── src/main/resources/
│   ├── application.yml                    # 主配置文件
│   ├── mapper/                            # MyBatis XML 映射文件（可选）
│   └── static/                            # 静态资源
│
├── src/test/java/                         # 测试代码
│
├── pom.xml                                 # Maven 配置文件
└── README.md                              # 项目说明文档
```

---

## 快速开始

### 环境要求

| 环境 | 版本要求 | 说明 |
|------|---------|------|
| **JDK** | 17+ | Java 开发工具包 |
| **Maven** | 3.6+ | 项目构建工具 |
| **MySQL** | 8.0+ | 数据库 |
| **IDE** | IntelliJ IDEA / Eclipse | Java IDE（推荐 IDEA） |

### 安装步骤

#### 1. 克隆项目

```bash
git clone https://github.com/yourusername/MembershipSystemJava.git
cd MembershipSystemJava
```

#### 2. 创建数据库

```sql
CREATE DATABASE membership_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

#### 3. 导入数据库表结构

```bash
# 使用 MySQL 命令行
mysql -u root -p membership_system < docs/sql/schema.sql

# 或者使用 MySQL Workbench 导入
```

#### 4. 配置数据库连接

编辑 `src/main/resources/application.yml`：

```yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/membership_system?useUnicode=true&characterEncoding=utf-8&serverTimezone=Asia/Shanghai
    username: root
    password: your_password  # 修改为你的数据库密码
    driver-class-name: com.mysql.cj.jdbc.Driver
```

#### 5. 配置 JWT 密钥

编辑 `src/main/resources/application.yml`：

```yaml
jwt:
  secret: your-secret-key-here  # 修改为你的 JWT 密钥
  expiration: 86400000  # Token 有效期（毫秒），默认 24 小时
```

#### 6. 编译和运行

```bash
# 使用 Maven 编译
mvn clean package

# 运行项目
java -jar target/MembershipSystemJava-0.0.1-SNAPSHOT.jar

# 或者直接使用 Maven 运行
mvn spring-boot:run
```

#### 7. 访问项目

- **API 文档（Swagger UI）**：http://localhost:8080/swagger-ui.html
- **API 文档（OpenAPI）**：http://localhost:8080/v3/api-docs
- **H2 数据库控制台**（如果使用 H2）：http://localhost:8080/h2-console

---

## 配置说明

### 主配置文件（application.yml）

```yaml
server:
  port: 8080  # 服务器端口

spring:
  application:
    name: MembershipSystem
  
  datasource:
    url: jdbc:mysql://localhost:3306/membership_system?useUnicode=true&characterEncoding=utf-8&serverTimezone=Asia/Shanghai
    username: root
    password: your_password
    driver-class-name: com.mysql.cj.jdbc.Driver
  
  jackson:
    date-format: yyyy-MM-dd HH:mm:ss
    time-zone: Asia/Shanghai

mybatis-plus:
  configuration:
    map-underscore-to-camel-case: true  # 自动驼峰命名转换
    log-impl: org.apache.ibatis.logging.stdout.StdOutImpl  # SQL 日志
  global-config:
    db-config:
      id-type: assign_id  # 雪花算法生成 ID
      logic-delete-field: deleted  # 逻辑删除字段
      logic-delete-value: 1
      logic-not-delete-value: 0

jwt:
  secret: your-secret-key-here
  expiration: 86400000  # 24 hours

logging:
  level:
    com.membership: DEBUG
    com.membership.mapper: TRACE  # 打印 SQL 语句
```

### 生产环境配置（application-prod.yml）

```yaml
spring:
  datasource:
    url: jdbc:mysql://prod-db-server:3306/membership_system?useUnicode=true&characterEncoding=utf-8&serverTimezone=Asia/Shanghai
    username: ${DB_USERNAME}  # 从环境变量读取
    password: ${DB_PASSWORD}  # 从环境变量读取

jwt:
  secret: ${JWT_SECRET}  # 从环境变量读取
  expiration: 86400000

logging:
  level:
    com.membership: INFO  # 生产环境使用 INFO 级别
```

---

## API 文档

详细的 API 文档请参考：
- **API 文档（Markdown）**：[MembershipSystem_Phase2_APIDocumentation_20260609.md](./MembershipSystem_Phase2_APIDocumentation_20260609.md)
- **Swagger UI**：http://localhost:8080/swagger-ui.html
- **OpenAPI JSON**：http://localhost:8080/v3/api-docs

### 主要 API 端点

| 端点 | 方法 | 描述 | 权限要求 |
|------|------|------|---------|
| `/api/auth/admin/login` | POST | 管理员登录 | 公开 |
| `/api/auth/member/login` | POST | 会员登录 | 公开 |
| `/api/members` | GET | 分页查询会员列表 | ROLE_STORE_ADMIN 或 ROLE_SUPER_ADMIN |
| `/api/members` | POST | 创建会员 | ROLE_STORE_ADMIN 或 ROLE_SUPER_ADMIN |
| `/api/members/{id}` | GET | 查询会员详情 | ROLE_STORE_ADMIN 或 ROLE_SUPER_ADMIN |
| `/api/members/{id}` | PUT | 更新会员信息 | ROLE_STORE_ADMIN 或 ROLE_SUPER_ADMIN |
| `/api/members/{id}` | DELETE | 删除会员 | ROLE_SUPER_ADMIN |
| `/api/consumption/consume` | POST | 会员消费 | ROLE_STORE_ADMIN |
| `/api/recharge/recharge` | POST | 会员充值 | ROLE_STORE_ADMIN |
| `/api/appointments` | POST | 创建预约 | ROLE_STORE_ADMIN 或 ROLE_MEMBER |
| `/api/dashboard/stats` | GET | 获取统计数据 | ROLE_STORE_ADMIN 或 ROLE_SUPER_ADMIN |

---

## 使用示例

### 1. 管理员登录

**请求**：

```bash
curl -X POST http://localhost:8080/api/auth/admin/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "admin123"
  }'
```

**响应**：

```json
{
  "code": 200,
  "message": "登录成功",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "tokenType": "Bearer",
    "expiresIn": 86400,
    "admin": {
      "id": "1234567890",
      "username": "admin",
      "name": "超级管理员",
      "role": "super_admin",
      "storeId": null
    }
  }
}
```

### 2. 创建会员

**请求**：

```bash
curl -X POST http://localhost:8080/api/members \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..." \
  -d '{
    "name": "张三",
    "phone": "13800138000",
    "passwordHash": "password123",
    "level": "normal",
    "storeId": "store001"
  }'
```

**响应**：

```json
{
  "code": 200,
  "message": "创建成功",
  "data": {
    "id": "9876543210",
    "name": "张三",
    "phone": "13800138000",
    "level": "normal",
    "balance": 0,
    "points": 0,
    "storeId": "store001",
    "status": "active",
    "createdAt": "2026-06-09T13:00:00"
  }
}
```

### 3. 会员消费

**请求**：

```bash
curl -X POST http://localhost:8080/api/consumption/consume \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..." \
  -d '{
    "memberId": "9876543210",
    "serviceId": "service001",
    "barberName": "李师傅",
    "customAmount": null
  }'
```

**响应**：

```json
{
  "code": 200,
  "message": "消费成功",
  "data": {
    "id": "record001",
    "memberId": "9876543210",
    "amount": 180.00,
    "originalPrice": 200.00,
    "discount": 20.00,
    "serviceName": "剪发 + 洗头",
    "barberName": "李师傅",
    "pointsEarned": 180,
    "storeId": "store001",
    "createdAt": "2026-06-09T13:30:00"
  }
}
```

---

## 注意事项

### 安全注意事项

1. **JWT Secret 必须修改**：生产环境中必须使用强密钥，不要使用默认密钥
2. **数据库密码必须修改**：不要使用默认密码
3. **HTTPS 必须启用**：生产环境必须使用 HTTPS
4. **登录失败锁定**：系统默认锁定 5 次失败尝试，15 分钟后自动解锁
5. **密码必须加密**：用户密码必须使用 BCrypt 加密，禁止明文存储

### 性能优化建议

1. **数据库索引**：为经常查询的字段（如 phone、storeId、memberId）创建索引
2. **分页查询**：所有列表查询必须使用分页，避免一次性查询大量数据
3. **缓存策略**：对频繁访问的数据（如会员信息、服务项目）使用 Redis 缓存
4. **连接池配置**：根据实际需求配置数据库连接池大小

### 备份和恢复

1. **定期备份数据库**：建议每天备份一次
2. **备份文件存储**：备份文件应存储在安全的位置（如云存储）
3. **恢复测试**：定期测试数据库恢复流程

---

## 贡献指南

欢迎贡献代码、提出问题或改进建议！

### 贡献步骤

1. Fork 本项目
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开一个 Pull Request

### 代码规范

- 使用 Java 17 特性
- 遵循阿里巴巴 Java 开发手册
- 所有公共方法必须有 Javadoc 注释
- 使用 Lombok 简化代码
- 使用 MyBatis-Plus 提高开发效率

---

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

---

## 联系方式

- **作者**：黄志鹏
- **邮箱**：your-email@example.com
- **GitHub**：https://github.com/yourusername/MembershipSystemJava

---

## 更新日志

### v1.0.0 (2026-06-09)

- ✅ 初始版本发布
- ✅ 完成会员管理功能
- ✅ 完成充值消费功能
- ✅ 完成预约管理功能
- ✅ 完成数据统计功能
- ✅ 完成认证授权功能
- ✅ 生成完整 Javadoc 注释
- ✅ 生成 API 文档

---

**感谢使用 MembershipSystem！如有问题，欢迎提出 Issue。**
