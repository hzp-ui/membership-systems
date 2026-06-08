package com.membership.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import java.math.BigDecimal;

/**
 * 充值请求
 * - 套餐充值：传 packageId，后端自动查金额
 * - 自定义充值：传 amount（bonus 可选）
 */
@Data
public class RechargeRequest {
    @NotBlank(message = "会员ID不能为空")
    private String memberId;

    /** 自定义充值金额（套餐充值时不需要传） */
    private BigDecimal amount;

    /** 赠送金额（可选） */
    private BigDecimal bonus;

    /** 套餐ID（套餐充值时传此参数，amount 不需要传） */
    private String packageId;

    /** 套餐名称（后端自动填充，前端不需要传） */
    private String packageName;
}
