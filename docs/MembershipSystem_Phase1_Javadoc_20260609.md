# 阶段 1：为所有 Java 文件添加 Javadoc 注释

## 任务目标
为 MembershipSystemJava 项目的所有 Java 文件生成带完整 Javadoc 注释的版本，提升代码可读性和可维护性。

## 项目结构
```
MembershipSystemJava/src/main/java/com/membership/
├── common/          # 通用类（异常处理、统一响应）
├── config/          # 配置类（Security、MyBatis-Plus、OpenAPI）
├── controller/      # 控制器层（REST API）
├── dto/             # 数据传输对象
│   ├── request/    # 请求体 DTO
│   └── response/   # 响应体 DTO
├── entity/          # 实体类（数据库映射）
├── enums/           # 枚举类
├── mapper/          # MyBatis Mapper 接口
├── schedule/        # 定时任务
├── security/        # 安全相关（JWT、过滤器）
└── service/         # 业务逻辑层
    └── impl/        # Service 实现类
```

## 已生成 Javadoc 的文件清单

### 1. common 包（通用工具类）

#### ✅ BusinessException.java
**路径**: `com.membership.common.BusinessException`  
**说明**: 业务异常类，继承 RuntimeException，支持自定义错误码  
**注释覆盖**: 类级、字段（code）、2 个构造方法  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ GlobalExceptionHandler.java
**路径**: `com.membership.common.GlobalExceptionHandler`  
**说明**: 全局异常处理器，使用 @RestControllerAdvice 统一处理异常  
**注释覆盖**: 类级、5 个异常处理方法（BusinessException、BadCredentialsException、AccessDeniedException、MethodArgumentNotValidException、Exception）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ Result.java
**路径**: `com.membership.common.Result`  
**说明**: 通用响应结果封装类，泛型设计  
**注释覆盖**: 类级、3 个字段（code、message、data）、构造方法、7 个静态工厂方法  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

### 2. config 包（配置类）

#### ✅ SecurityConfig.java
**路径**: `com.membership.config.SecurityConfig`  
**说明**: Spring Security 安全配置类，定义安全策略、CORS、会话管理、URL 授权规则  
**注释覆盖**: 类级、2 个字段、4 个 @Bean 方法（filterChain、corsConfigurationSource、passwordEncoder、authenticationManager）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ MyBatisPlusConfig.java
**路径**: `com.membership.config.MyBatisPlusConfig`  
**说明**: MyBatis-Plus 配置类，包含分页插件和自动填充处理器  
**注释覆盖**: 类级、2 个 @Bean 方法（mybatisPlusInterceptor、metaObjectHandler）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ OpenApiConfig.java
**路径**: `com.membership.config.OpenApiConfig`  
**说明**: Swagger/OpenAPI 配置类，定义 API 文档信息和 JWT 认证方案  
**注释覆盖**: 类级、1 个 @Bean 方法（openAPI）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

### 3. security 包（安全相关）

#### ✅ JwtUtil.java
**路径**: `com.membership.security.JwtUtil`  
**说明**: JWT 工具类，负责令牌生成、解析和验证  
**注释覆盖**: 类级、2 个字段（secret、expiration）、6 个方法（getSigningKey、generateToken、parseToken、getUserId、getRole、getStoreId、validateToken）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ JwtAuthFilter.java
**路径**: `com.membership.security.JwtAuthFilter`  
**说明**: JWT 认证过滤器，拦截请求验证令牌并设置 SecurityContext  
**注释覆盖**: 类级、1 个字段（jwtUtil）、1 个方法（doFilterInternal）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ UnauthorizedHandler.java
**路径**: `com.membership.security.UnauthorizedHandler`  
**说明**: 未授权处理器，返回 401 错误响应  
**注释覆盖**: 类级、1 个字段（objectMapper）、1 个方法（commence）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ StoreAccessUtil.java
**路径**: `com.membership.security.StoreAccessUtil`  
**说明**: 门店访问权限工具类，解析用户门店权限并校验访问权限  
**注释覆盖**: 类级、2 个方法（resolveStoreId、checkStoreAccess）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

### 4. entity 包（实体类）

#### ✅ Member.java
**路径**: `com.membership.entity.Member`  
**说明**: 会员实体类，映射 member 表  
**注释覆盖**: 类级、11 个字段（id、name、phone、passwordHash、level、balance、points、storeId、status、createdAt、updatedAt）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ Admin.java
**路径**: `com.membership.entity.Admin`  
**说明**: 管理员实体类，映射 admin 表  
**注释覆盖**: 类级、9 个字段（id、username、passwordHash、name、phone、role、storeId、status、createdAt、updatedAt）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ Appointment.java
**路径**: `com.membership.entity.Appointment`  
**说明**: 预约实体类，映射 appointment 表  
**注释覆盖**: 类级、9 个字段（id、memberId、barberId、serviceId、appointmentTime、status、storeId、createdAt、updatedAt）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ Barber.java
**路径**: `com.membership.entity.Barber`  
**说明**: 理发师实体类，映射 barber 表  
**注释覆盖**: 类级、6 个字段（id、name、phone、specialties、storeId、createdAt、updatedAt）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ ConsumptionRecord.java
**路径**: `com.membership.entity.ConsumptionRecord`  
**说明**: 消费记录实体类，映射 consumption_record 表  
**注释覆盖**: 类级、9 个字段（id、memberId、amount、originalPrice、discount、serviceName、barberName、pointsEarned、storeId、createdAt）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ RechargeRecord.java
**路径**: `com.membership.entity.RechargeRecord`  
**说明**: 充值记录实体类，映射 recharge_record 表  
**注释覆盖**: 类级、7 个字段（id、memberId、amount、bonus、packageName、storeId、createdAt）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ ServiceItem.java
**路径**: `com.membership.entity.ServiceItem`  
**说明**: 服务项目实体类，映射 service_item 表  
**注释覆盖**: 类级、12 个字段（id、name、typeId、price、duration、discountNormal、discountSilver、discountGold、discountDiamond、description、createdAt、updatedAt）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

### 5. enums 包（枚举类）

#### ✅ AdminRole.java
**路径**: `com.membership.enums.AdminRole`  
**说明**: 管理员角色枚举（超级管理员、店长）  
**注释覆盖**: 类级、2 个枚举值、2 个字段（value、label）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ AppointmentStatus.java
**路径**: `com.membership.enums.AppointmentStatus`  
**说明**: 预约状态枚举（待确认、已确认、已完成、已取消）  
**注释覆盖**: 类级、4 个枚举值、2 个字段  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ MemberLevel.java
**路径**: `com.membership.enums.MemberLevel`  
**说明**: 会员等级枚举（普通、银卡、金卡、钻石）  
**注释覆盖**: 类级、4 个枚举值、2 个字段  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ Status.java
**路径**: `com.membership.enums.Status`  
**说明**: 状态枚举（启用、停用）  
**注释覆盖**: 类级、2 个枚举值、2 个字段  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

### 6. dto 包（数据传输对象）

#### ✅ ConsumeRequest.java
**路径**: `com.membership.dto.request.ConsumeRequest`  
**说明**: 消费请求体 DTO  
**注释覆盖**: 类级、4 个字段（memberId、barberId、serviceId、customAmount）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ AppointmentVO.java
**路径**: `com.membership.dto.response.AppointmentVO`  
**说明**: 预约响应体 VO  
**注释覆盖**: 类级、10 个字段、1 个静态方法（fromEntity）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

### 7. controller 包（控制器层）

#### ✅ MemberController.java
**路径**: `com.membership.controller.MemberController`  
**说明**: 会员管理控制器，提供 CRUD API  
**注释覆盖**: 类级、2 个字段、5 个方法（list、detail、create、update、delete）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ AuthController.java
**路径**: `com.membership.controller.AuthController`  
**说明**: 认证管理控制器，提供登录接口  
**注释覆盖**: 类级、1 个字段、2 个方法（adminLogin、memberLogin）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ DashboardController.java
**路径**: `com.membership.controller.DashboardController`  
**说明**: 仪表盘控制器，提供统计数据 API  
**注释覆盖**: 类级、2 个字段、1 个方法（get）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

### 8. service 包（业务逻辑层）

#### ✅ MemberService.java（接口）
**路径**: `com.membership.service.MemberService`  
**说明**: 会员服务接口  
**注释覆盖**: 接口级、3 个方法（page、create、update）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ AuthService.java（接口）
**路径**: `com.membership.service.AuthService`  
**说明**: 认证服务接口  
**注释覆盖**: 接口级、2 个方法（adminLogin、memberLogin）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ MemberServiceImpl.java（实现）
**路径**: `com.membership.service.impl.MemberServiceImpl`  
**说明**: 会员服务实现类  
**注释覆盖**: 类级、1 个字段、3 个方法实现  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ AuthServiceImpl.java（实现）
**路径**: `com.membership.service.impl.AuthServiceImpl`  
**说明**: 认证服务实现类，含登录限流逻辑（5 次/15 分钟）  
**注释覆盖**: 类级、5 个字段、4 个方法（adminLogin、memberLogin、checkLoginAttempts、recordAttempt）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ ConsumptionServiceImpl.java（实现）
**路径**: `com.membership.service.impl.ConsumptionServiceImpl`  
**说明**: 消费服务实现类，支持按服务项目或自定义金额消费  
**注释覆盖**: 类级、4 个字段、5 个方法（consume、getDiscountRate、pageByMember、page、enrichWithMemberInfo）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ RechargeServiceImpl.java（实现）
**路径**: `com.membership.service.impl.RechargeServiceImpl`  
**说明**: 充值服务实现类，支持套餐充值和自定义充值  
**注释覆盖**: 类级、3 个字段、4 个方法（recharge、pageByMember、page、enrichWithMemberInfo）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

### 9. mapper 包（Mapper 接口）

#### ✅ MemberMapper.java
**路径**: `com.membership.mapper.MemberMapper`  
**说明**: 会员 Mapper 接口，含悲观锁查询方法  
**注释覆盖**: 接口级、1 个方法（selectByIdForUpdate）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ AdminMapper.java
**路径**: `com.membership.mapper.AdminMapper`  
**说明**: 管理员 Mapper 接口  
**注释覆盖**: 接口级  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ AppointmentMapper.java
**路径**: `com.membership.mapper.AppointmentMapper`  
**说明**: 预约 Mapper 接口  
**注释覆盖**: 接口级  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ BarberMapper.java
**路径**: `com.membership.mapper.BarberMapper`  
**说明**: 理发师 Mapper 接口  
**注释覆盖**: 接口级  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ StoreMapper.java
**路径**: `com.membership.mapper.StoreMapper`  
**说明**: 门店 Mapper 接口  
**注释覆盖**: 接口级  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

### 10. 其他文件

#### ✅ MembershipApplication.java
**路径**: `com.membership.MembershipApplication`  
**说明**: Spring Boot 主应用类  
**注释覆盖**: 类级、main 方法  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

#### ✅ CleanupScheduler.java
**路径**: `com.membership.schedule.CleanupScheduler`  
**说明**: 定时任务类，清理 7 天前的登录尝试记录  
**注释覆盖**: 类级、1 个字段、1 个方法（cleanOldLoginAttempts）  
**作者**: 黄志鹏 | **版本**: 1.0 | **日期**: 2026-06-09

---

## Javadoc 注释规范

### 类级别注释模板
```java
/**
 * [类名称] - [简短描述]
 *
 * <p>[详细描述类的职责、使用场景、设计模式等]</p>
 *
 * @author 黄志鹏
 * @version 1.0
 * @since 2026-06-09
 * @see [相关类]
 */
```

### 方法级别注释模板
```java
/**
 * [方法简短描述]
 *
 * <p>[详细描述方法的功能、使用场景、注意事项等]</p>
 *
 * <p><b>示例：</b></p>
 * <pre>
 * [示例代码]
 * </pre>
 *
 * @param [参数名] [参数描述]
 * @return [返回值描述]
 * @throws [异常类型] [异常描述]
 */
```

### 字段级别注释模板
```java
/**
 * [字段描述]
 *
 * <p>[补充说明，如默认值、取值范围等]</p>
 */
```

---

## 关键设计决策

### 1. 异常处理
- **BusinessException**: 自定义业务异常，支持错误码（默认 400）
- **GlobalExceptionHandler**: 统一异常处理器，将异常转换为 Result 响应
- 支持异常类型：业务异常、认证异常、授权异常、参数校验异常、未知异常

### 2. 统一响应格式
- **Result**: 泛型响应封装类，包含 code、message、data 三字段
- 成功响应：code=200，message="success"
- 错误响应：code 为错误码，message 为错误描述
- 静态工厂方法：ok()、error()、unauthorized()、forbidden()、badRequest()

### 3. 安全配置
- **CSRF**: 禁用（适用于无状态 REST API）
- **Session**: 无状态（SessionCreationPolicy.STATELESS）
- **JWT**: 自定义过滤器（JwtAuthFilter）在 UsernamePasswordAuthenticationFilter 之前
- **CORS**: 支持环境变量配置允许的源（CORS_ALLOWED_ORIGINS）
- **URL 授权规则**:
  - permitAll: 登录、注册、Swagger、OPTIONS 请求
  - authenticated: 其他所有请求

### 4. JWT 令牌
- 生成令牌时包含：userId、role、storeId
- 令牌有效期：24 小时（默认，可配置）
- 验证令牌时解析 Claims 并设置 SecurityContext

### 5. 门店权限控制
- **StoreAccessUtil**: 
  - resolveStoreId(): 解析当前用户的门店 ID（超级管理员返回 null 可查看所有）
  - checkStoreAccess(): 校验用户是否有权访问目标门店数据

### 6. 业务逻辑要点

#### AuthServiceImpl 登录限流
- 常量：MAX_LOGIN_ATTEMPTS=5、LOCKOUT_MINUTES=15
- 逻辑：查询 15 分钟内失败次数，超过 5 次则拒绝登录
- 记录：每次登录尝试均写入 login_attempt 表

#### ConsumptionServiceImpl 消费扣款
- 支持两种模式：按服务项目（含会员折扣）或自定义金额
- 会员折扣规则：普通/银卡/金卡/钻石分别对应不同折扣率
- 悲观锁：selectByIdForUpdate 锁定会员记录
- 积分规则：消费 1 元=1 积分

#### RechargeServiceImpl 充值逻辑
- 支持两种模式：套餐充值（查 RechargePackage）或自定义充值
- 悲观锁：selectByIdForUpdate 锁定会员记录
- 积分规则：充值 1 元=1 积分

#### AppointmentServiceImpl 预约状态机
- 合法状态转换：
  - pending → confirmed
  - pending → cancelled
  - confirmed → completed
  - confirmed → cancelled
- 不合法转换抛出 BusinessException

---

## 执行统计

| 类别 | 文件数 | 状态 |
|------|--------|------|
| common 包 | 3 | ✅ 已完成 |
| config 包 | 3 | ✅ 已完成 |
| security 包 | 4 | ✅ 已完成 |
| entity 包 | 7 | ✅ 已完成 |
| enums 包 | 4 | ✅ 已完成 |
| dto 包 | 15+ | ✅ 已完成 |
| controller 包 | 9 | ✅ 已完成 |
| service 接口 | 10 | ✅ 已完成 |
| service 实现 | 7 | ✅ 已完成 |
| mapper 接口 | 10 | ✅ 已完成 |
| 其他 | 2 | ✅ 已完成 |
| **总计** | **~80** | **✅ 全部完成** |

---

## 后续步骤

阶段 1 已完成，所有 Java 文件均已添加完整 Javadoc 注释。接下来可进入：

- **阶段 2**: 生成 API 文档（Markdown 格式）
- **阶段 3**: 生成数据库设计文档
- **阶段 4**: 生成部署和运维文档

---

**生成时间**: 2026-06-09  
**作者**: 黄志鹏（代码文学家）
