package com.membership.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import java.math.BigDecimal;

/**
 * 充值请求
 * - 套餐充值：传 packageId，后端自动查金额
 * - 自定义充值：传 amount（bonus 可选）
 */
@Data
@Schema(description = "充值请求：套餐充值传 packageId，自定义充值传 amount")
public class RechargeRequest {
    @Schema(description = "会员ID", example = "mem_001")
    @NotBlank(message = "会员ID不能为空")
    private String memberId;

    @Schema(description = "自定义充值金额（套餐充值时不需要传）", example = "500.00")
    private BigDecimal amount;

    @Schema(description = "赠送金额（可选）", example = "50.00")
    private BigDecimal bonus;

    @Schema(description = "套餐ID（套餐充值时传此参数，amount 不需要传）", example = "pkg_001")
    private String packageId;

    @Schema(description = "套餐名称（后端自动填充，前端不需要传）")
    private String packageName;
}
