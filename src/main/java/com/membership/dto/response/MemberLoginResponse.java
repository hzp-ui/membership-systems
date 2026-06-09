package com.membership.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;

@Data
@Builder
@Schema(description = "会员登录响应")
public class MemberLoginResponse {
    @Schema(description = "JWT Token", example = "eyJhbGciOi...")
    private String token;

    @Schema(description = "会员ID", example = "mem_001")
    private String memberId;

    @Schema(description = "会员姓名", example = "张三")
    private String name;

    @Schema(description = "手机号", example = "13800138000")
    private String phone;

    @Schema(description = "会员等级", example = "初级会员")
    private String level;

    @Schema(description = "账户余额", example = "500.00")
    private BigDecimal balance;

    @Schema(description = "积分", example = "120")
    private Long points;
}
