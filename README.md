# 理发店会员管理系统 - 后端

基于 **Spring Boot 3.2.5 + MyBatis-Plus 3.5.7 + MySQL 8.0** 构建的 RESTful API 后端服务。

---

## 技术栈

### 核心框架

| 技术 | 版本 | 说明 |
|------|------|------|
| **Spring Boot** | 3.2.5 | 应用框架 |
| **MyBatis-Plus** | 3.5.7 | ORM 框架 |
| **MySQL** | 8.0.46 | 关系型数据库 |
| **Java** | 17 | JDK 版本 |

### 安全与认证

| 技术 | 用途 |
|------|------|
| **Spring Security** | 权限控制 |
| **JWT (JJWT)** | 无状态认证 |
| **bcrypt** | 密码加密 |

### 工具库

| 技术 | 用途 |
|------|------|
| **Jackson** | JSON 序列化 (SNAKE_CASE) |
| **Lombok** | 简化 Java 代码 |
| **HikariCP** | 数据库连接池 |
| **Maven** | 依赖管理 |

---

## 项目结构

```
MembershioSystemJava/
├── src/main/java/com/membership/
│   ├── MembershipApplication.java      # 启动类
│   ├── common/                          # 通用工具
│   │   ├── Result.java                  # 统一响应封装
│   │   ├── BusinessException.java       # 业务异常
│   │   └── GlobalExceptionHandler.java # 全局异常处理
│   ├── config/                          # 配置类
│   │   ├── SecurityConfig.java          # Spring Security 配置
│   │   ├── MybatisPlusConfig.java      # MyBatis-Plus 配置
│   │   ├── JacksonConfig.java           # JSON 序列化配置
│   │   └── OpenApiConfig.java          # Swagger/OpenAPI 配置
│   ├── controller/                      # 控制器层
│   │   ├── AuthController.java          # 认证接口
│   │   ├── MemberController.java        # 会员管理
│   │   ├── RechargeController.java      # 充值管理
│   │   ├── ConsumptionController.java   # 消费管理
│   │   ├── AppointmentController.java   # 预约管理
│   │   ├── BarberController.java        # 理发师管理
│   │   ├── ServiceController.java       # 服务管理
│   │   ├── PackageController.java       # 套餐管理
│   │   ├── StoreController.java         # 门店管理
│   │   ├── AdminController.java         # 管理员管理
│   │   ├── StatController.java          # 统计报表
│   │   └── DashboardController.java    # 仪表盘数据
│   ├── dto/                             # 数据传输对象
│   │   ├── request/                     # 请求 DTO
│   │   │   ├── LoginRequest.java
│   │   │   ├── CreateMemberRequest.java
│   │   │   ├── RechargeRequest.java
│   │   │   ├── ConsumeRequest.java
│   │   │   ├── CreateAppointmentRequest.java
│   │   │   └── CreateAdminRequest.java
│   │   └── response/                    # 响应 DTO/VO
│   │       ├── LoginResponse.java
│   │       ├── MemberLoginResponse.java
│   │       ├── DashboardResponse.java
│   │       ├── RechargeRecordVO.java
│   │       ├── ConsumptionRecordVO.java
│   │       └── AppointmentVO.java
│   ├── entity/                          # 实体类
│   │   ├── Member.java
│   │   ├── RechargeRecord.java
│   │   ├── ConsumptionRecord.java
│   │   ├── Appointment.java
│   │   ├── Barber.java
│   │   ├── ServiceItem.java             # 避免关键字冲突
│   │   ├── RechargePackage.java
│   │   ├── Store.java
│   │   ├── Admin.java
│   │   ├── AuditLog.java
│   │   └── LoginAttempt.java
│   ├── mapper/                          # MyBatis Mapper
│   │   ├── MemberMapper.java
│   │   ├── RechargeRecordMapper.java
│   │   ├── ConsumptionRecordMapper.java
│   │   ├── AppointmentMapper.java
│   │   ├── BarberMapper.java
│   │   ├── ServiceMapper.java
│   │   ├── PackageMapper.java
│   │   ├── StoreMapper.java
│   │   └── AdminMapper.java
│   ├── service/                         # 服务层接口
│   │   ├── MemberService.java
│   │   ├── RechargeService.java
│   │   ├── ConsumptionService.java
│   │   ├── AppointmentService.java
│   │   ├── BarberService.java
│   │   ├── ServiceItemService.java
│   │   ├── PackageService.java
│   │   ├── StoreService.java
│   │   ├── AdminService.java
│   │   ├── AuthService.java
│   │   ├── DashboardService.java
│   │   └── StatService.java
│   ├── service/impl/                    # 服务层实现
│   │   ├── MemberServiceImpl.java
│   │   ├── RechargeServiceImpl.java
│   │   ├── ConsumptionServiceImpl.java
│   │   ├── AppointmentServiceImpl.java
│   │   ├── BarberServiceImpl.java
│   │   ├── ServiceItemServiceImpl.java
│   │   ├── PackageServiceImpl.java
│   │   ├── StoreServiceImpl.java
│   │   ├── AdminServiceImpl.java
│   │   ├── AuthServiceImpl.java
│   │   ├── DashboardServiceImpl.java
│   │   └── StatServiceImpl.java
│   ├── security/                        # 安全相关
│   │   ├── JwtAuthFilter.java           # JWT 过滤器
│   │   ├── JwtUtil.java                 # Token 生成/解析
│   │   ├── StoreAccessUtil.java         # 门店权限工具
│   │   └── UnauthorizedHandler.java     # 未授权处理
│   ├── enums/                           # 枚举类
│   │   ├── AdminRole.java
│   │   ├── AppointmentStatus.java
│   │   ├── MemberLevel.java
│   │   └── Status.java
│   └── schedule/                        # 定时任务
│       └── CleanupScheduler.java
├── src/main/resources/
│   ├── application.yml                  # 主配置文件
│   └── db/
│       └── schema.sql                   # 数据库初始化脚本
└── pom.xml                              # Maven 配置
```

---

## 核心架构

### 认证流程

```
用户登录 (POST /api/v1/auth/admin/login)
    ↓
AuthServiceImpl.authenticate()
    ↓
验证 bcrypt 密码哈希
    ↓
生成 JWT Token (JJWT)
    ↓
返回 Token + 用户信息
    ↓
前端存储 Token (localStorage)
    ↓
后续请求携带 Token (Authorization Header)
    ↓
JwtAuthFilter 拦截并验证 Token
    ↓
设置 Authentication 到 SecurityContext
```

### 数据隔离方案

```java
// StoreAccessUtil.java
@Component
public class StoreAccessUtil {
    
    public String resolveStoreId(Authentication auth) {
        if (auth == null) return null;
        
        UserDetails user = (UserDetails) auth.getPrincipal();
        boolean isSuperAdmin = user.getAuthorities().stream()
            .anyMatch(a -> a.getAuthority().equals("ROLE_SUPER_ADMIN"));
        
        if (isSuperAdmin) {
            return null;  // null = 查询所有门店
        }
        
        // store_admin 从数据库查询其 store_id
        return adminService.getStoreIdByUsername(user.getUsername());
    }
}
```

**权限模型**：
- `SUPER_ADMIN`：可操作所有数据
- `STORE_ADMIN`：只能操作自己门店的数据

### 统一响应格式

```java
// Result.java
@Data
public class Result<T> {
    private int code;
    private String message;
    private T data;
    
    public static <T> Result<T> ok(T data) {
        Result<T> result = new Result<>();
        result.setCode(200);
        result.setMessage("success");
        result.setData(data);
        return result;
    }
    
    public static <T> Result<T> error(int code, String message) {
        Result<T> result = new Result<>();
        result.setCode(code);
        result.setMessage(message);
        return result;
    }
}
```

---

## API 文档

### 认证接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| POST | `/api/v1/auth/admin/login` | 管理员登录 | 公开 |
| POST | `/api/v1/auth/member/login` | 会员登录 | 公开 |
| POST | `/api/v1/auth/member/register` | 会员注册 | 公开 |

### 会员接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/members` | 会员列表 | 需登录 |
| POST | `/api/v1/members` | 创建会员 | 需登录 |
| PUT | `/api/v1/members/{id}` | 更新会员 | 需登录 |
| DELETE | `/api/v1/members/{id}` | 删除会员 | 需登录 |

### 充值接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/recharges` | 充值记录 | 需登录 |
| POST | `/api/v1/recharges` | 会员充值 | 需登录 |

### 消费接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/consumptions` | 消费记录 | 需登录 |
| POST | `/api/v1/consumptions` | 创建消费 | 需登录 |

### 预约接口

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/api/v1/appointments` | 预约列表 | 需登录 |
| POST | `/api/v1/appointments` | 创建预约 | 需登录 |
| PUT | `/api/v1/appointments/{id}/confirm` | 确认预约 | 需登录 |
| PUT | `/api/v1/appointments/{id}/complete` | 完成预约 | 需登录 |
| PUT | `/api/v1/appointments/{id}/cancel` | 取消预约 | 需登录 |

### 其他接口

| 模块 | 路径前缀 | 说明 |
|------|----------|------|
| 理发师 | `/api/v1/barbers` | 理发师管理 |
| 服务 | `/api/v1/services` | 服务管理 |
| 套餐 | `/api/v1/packages` | 套餐管理 |
| 门店 | `/api/v1/stores` | 门店管理 |
| 管理员 | `/api/v1/admins` | 管理员管理 |
| 统计 | `/api/v1/stats` | 统计报表 |

---

## 数据库设计

### 核心表结构

```sql
-- 会员表
CREATE TABLE members (
    id VARCHAR(32) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    level VARCHAR(20) DEFAULT '普通会员',
    balance DECIMAL(10,2) DEFAULT 0,
    points INT DEFAULT 0,
    store_id VARCHAR(32),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_phone (phone),
    INDEX idx_store_id (store_id)
);

-- 充值记录表
CREATE TABLE recharge_records (
    id VARCHAR(32) PRIMARY KEY,
    member_id VARCHAR(32) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    package_id VARCHAR(32),
    store_id VARCHAR(32),
    admin_id VARCHAR(32),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_member_id (member_id),
    INDEX idx_store_id (store_id),
    INDEX idx_created_at (created_at)
);

-- 消费记录表
CREATE TABLE consumption_records (
    id VARCHAR(32) PRIMARY KEY,
    member_id VARCHAR(32) NOT NULL,
    service_id VARCHAR(32),
    barber_id VARCHAR(32),
    amount DECIMAL(10,2) NOT NULL,
    original_price DECIMAL(10,2),
    discount DECIMAL(3,2) DEFAULT 1.00,
    points_earned INT DEFAULT 0,
    store_id VARCHAR(32),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_member_id (member_id),
    INDEX idx_store_id (store_id),
    INDEX idx_created_at (created_at)
);

-- 预约表
CREATE TABLE appointments (
    id VARCHAR(32) PRIMARY KEY,
    member_id VARCHAR(32) NOT NULL,
    barber_id VARCHAR(32),
    service_id VARCHAR(32),
    appointment_time TIMESTAMP NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    store_id VARCHAR(32),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_member_id (member_id),
    INDEX idx_barber_id (barber_id),
    INDEX idx_status (status),
    INDEX idx_store_id (store_id)
);

-- 管理员表
CREATE TABLE admins (
    id VARCHAR(32) PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,  -- bcrypt hash
    name VARCHAR(100),
    role VARCHAR(20) DEFAULT 'store_admin',
    store_id VARCHAR(32),
    status TINYINT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 其他表：barbers, services, recharge_packages, stores
```

**字符集**: `utf8mb4` (支持 emoji)

---

## 开发指南

### 环境要求

- **JDK**: 17+
- **Maven**: 3.9+
- **MySQL**: 8.0+
- **IDE**: IntelliJ IDEA / Eclipse (推荐 IDEA)

### 配置数据库

1. 创建数据库：

```sql
CREATE DATABASE membership_system 
  CHARACTER SET utf8mb4 
  COLLATE utf8mb4_unicode_ci;
```

2. 修改 `application.yml`：

```yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/membership_system?useUnicode=true&characterEncoding=utf8mb4&serverTimezone=Asia/Shanghai
    username: root
    password: Mysql@2026
```

3. 初始化数据库：

```bash
mysql -u root -p membership_system < src/main/resources/db/schema.sql
```

### 运行项目

```bash
# 使用 Maven 启动
mvn spring-boot:run

# 或者打包后运行
mvn clean package
java -jar target/membership-system-0.0.1-SNAPSHOT.jar
```

访问: http://localhost:8080

### 测试 API

```bash
# 登录
curl -X POST http://localhost:8080/api/v1/auth/admin/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# 使用 Token 访问
curl http://localhost:8080/api/v1/members \
  -H "Authorization: Bearer <your-token>"
```

---

## 配置说明

### application.yml

```yaml
server:
  port: 8080

spring:
  datasource:
    url: jdbc:mysql://localhost:3306/membership_system
    username: root
    password: Mysql@2026
    hikari:
      connection-init-sql: SET NAMES utf8mb4
  
  jackson:
    property-naming-strategy: SNAKE_CASE  # 自动转换 camelCase ↔ snake_case
  
  mvc:
    throw-exception-if-no-handler-found: true

mybatis-plus:
  configuration:
    map-underscore-to-camel-case: true  # 自动下划线转驼峰
  global-config:
    db-config:
      id-type: assign_id  # Snowflake 算法
```

---

## 安全配置

### Spring Security

```java
@Configuration
public class SecurityConfig {
    
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/**").permitAll()
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }
}
```

### JWT Token 配置

```java
// JwtUtil.java
public class JwtUtil {
    
    private static final String SECRET_KEY = "your-secret-key";
    private static final long EXPIRATION = 86400000;  // 24 hours
    
    public String generateToken(String username, String role) {
        return Jwts.builder()
            .setSubject(username)
            .claim("role", role)
            .setIssuedAt(new Date())
            .setExpiration(new Date(System.currentTimeMillis() + EXPIRATION))
            .signWith(SignatureAlgorithm.HS512, SECRET_KEY)
            .compact();
    }
}
```

---

## 性能优化

### MyBatis-Plus 分页

```java
// MybatisPlusConfig.java
@Configuration
public class MybatisPlusConfig {
    
    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor() {
        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
        interceptor.addInnerInterceptor(new PaginationInnerInterceptor(DbType.MYSQL));
        return interceptor;
    }
}
```

### 数据库连接池

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 10
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
```

---

## 测试

### 回归测试

```bash
# 运行所有测试
mvn test

# 运行特定测试类
mvn test -Dtest=MemberServiceTest
```

### API 测试

使用 **Postman** 或 **cURL** 测试 API：

1. 导入 `postman_collection.json` (待创建)
2. 设置环境变量 `base_url = http://localhost:8080`
3. 登录后自动设置 Token

---

## 部署

### 打包

```bash
mvn clean package -DskipTests
```

输出: `target/membership-system-0.0.1-SNAPSHOT.jar`

### 运行

```bash
# 生产环境
java -jar -Dspring.profiles.active=prod target/membership-system-0.0.1-SNAPSHOT.jar

# 后台运行 (Linux)
nohup java -jar target/membership-system-0.0.1-SNAPSHOT.jar > app.log 2>&1 &
```

### Docker 部署 (可选)

```dockerfile
# Dockerfile
FROM openjdk:17-jdk-slim
COPY target/membership-system-0.0.1-SNAPSHOT.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

构建并运行：

```bash
docker build -t membership-system .
docker run -p 8080:8080 membership-system
```

---

## 已知问题

1. **项目路径拼写错误**: `MembershioSystemJava` (应为 `MembershipSystemJava`)
2. **前端路径拼写错误**: `MmbershipJavaWeb` (应为 `MembershipJavaWeb`)
3. **部分 Controller 需要优化**: 代码复用（StoreAccessUtil 仅替换了 3/7 个）
4. **Swagger 文档待完善**: 需要添加详细的 API 文档注解

---

## 最近更新

### 2026-06-08
- ✅ 完成 37 个后端 API 接口
- ✅ 实现 JWT + Spring Security 认证
- ✅ 实现多门店数据隔离（StoreAccessUtil）
- ✅ 修复中文编码问题（UTF-8）
- ✅ 创建 VO/DTO 层（RechargeRecordVO、ConsumptionRecordVO、AppointmentVO）
- ✅ 配置 Jackson SNAKE_CASE 自动转换
- ✅ 64 个回归测试全部通过

---

## 前端仓库

- **GitHub**: https://github.com/hzp-ui/membership-system
- **分支**: `refactor/rest-api-migration`
- **技术栈**: React 18 + TypeScript 5.6 + Vite + Ant Design 5

---

## 贡献指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交改动 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

---

## 许可证

MIT

---

## 联系方式

如有问题或建议，请提交 Issue 或联系项目维护者。
