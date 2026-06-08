package com.membership.dto.request;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.math.BigDecimal;

/**
 * 消费请求 - 折扣由后端根据会员等级+服务项目自动计算，前端无需传金额/折扣。
 * 支持自定义金额消费（service_id = "custom" 时，使用 custom_amount）
 */
@Data
public class ConsumeRequest {
    @NotBlank(message = "会员ID不能为空")
    @JsonProperty("member_id")
    private String memberId;

    @NotBlank(message = "服务项目ID不能为空")
    @JsonProperty("service_id")
    private String serviceId;

    @NotBlank(message = "理发师ID不能为空")
    @JsonProperty("barber_id")
    private String barberId;

    @JsonProperty("custom_amount")
    private BigDecimal customAmount;
}
