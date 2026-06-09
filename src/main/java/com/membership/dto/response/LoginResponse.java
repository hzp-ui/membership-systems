package com.membership.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
@Schema(description = "管理员登录响应")
public class LoginResponse {
    @Schema(description = "JWT Token", example = "eyJhbGciOiJIUzI1NiJ9...")
    private String token;

    @Schema(description = "管理员ID", example = "admin_001")
    private String userId;

    @Schema(description = "用户名", example = "admin")
    private String username;

    @Schema(description = "姓名", example = "张三")
    private String name;

    @Schema(description = "角色：super_admin 或 store_admin", example = "super_admin")
    private String role;

    @Schema(description = "所属门店ID（store_admin 时非空）", example = "store-001")
    private String storeId;
}
