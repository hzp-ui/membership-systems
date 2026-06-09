package com.membership.dto.request;

import com.fasterxml.jackson.annotation.JsonProperty;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.math.BigDecimal;

/**
 * 消费请求 - 折扣由后端根据会员等级+服务项目自动计算，前端无需传金额/折扣。
 * 支持自定义金额消费（service_id = "custom" 时，使用 custom_amount）
 */
@Data
@Schema(description = "消费请求：折扣由后端自动计算，支持选择服务或自定义金额")
public class ConsumeRequest {
    @Schema(description = "会员ID", example = "mem_001")
    @NotBlank(message = "会员ID不能为空")
    @JsonProperty("member_id")
    private String memberId;

    @Schema(description = "服务项目ID，传 custom 时使用自定义金额", example = "svc_001")
    @NotBlank(message = "服务项目ID不能为空")
    @JsonProperty("service_id")
    private String serviceId;

    @Schema(description = "理发师ID", example = "barber_001")
    @NotBlank(message = "理发师ID不能为空")
    @JsonProperty("barber_id")
    private String barberId;

    @Schema(description = "自定义消费金额（service_id=custom 时使用）", example = "150.00")
    @JsonProperty("custom_amount")
    private BigDecimal customAmount;
}
