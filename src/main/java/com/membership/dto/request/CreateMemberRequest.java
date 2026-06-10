package com.membership.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.Pattern;
import lombok.Data;
import java.math.BigDecimal;

@Data
@Schema(description = "创建会员请求")
public class CreateMemberRequest {
    @Schema(description = "手机号", example = "13800138000")
    @NotBlank(message = "手机号不能为空")
    @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
    private String phone;

    @Schema(description = "密码，不填则使用手机号后6位")
    private String password;

    @Schema(description = "会员姓名", example = "张三")
    @NotBlank(message = "姓名不能为空")
    @Size(max = 50, message = "姓名长度不能超过50字符")
    private String name;

    @Schema(description = "会员等级", example = "初级会员")
    @Size(max = 20, message = "等级长度不能超过20字符")
    private String level;

    @Schema(description = "初始余额", example = "0")
    @NotNull(message = "余额不能为空")
    private BigDecimal balance;

    @Schema(description = "所属门店ID")
    private String storeId;
}
