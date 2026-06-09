package com.membership.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
@Schema(description = "创建管理员请求")
public class CreateAdminRequest {
    @Schema(description = "用户名", example = "admin1")
    @NotBlank(message = "用户名不能为空")
    private String username;

    @Schema(description = "密码", example = "admin123")
    @NotBlank(message = "密码不能为空")
    private String password;

    @Schema(description = "姓名", example = "张三")
    @NotBlank(message = "姓名不能为空")
    private String name;

    @Schema(description = "手机号", example = "13800138000")
    private String phone;

    @Schema(description = "角色：super_admin 或 store_admin", example = "store_admin")
    @NotBlank(message = "角色不能为空")
    private String role;

    @Schema(description = "管理的门店ID（store_admin 必填）")
    private String storeId;
}
