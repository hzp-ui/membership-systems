package com.membership.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;

@Data
@Builder
@Schema(description = "仪表盘统计数据")
public class DashboardResponse {
    @Schema(description = "会员总数", example = "120")
    private Long totalMembers;

    @Schema(description = "理发师总数", example = "8")
    private Long totalBarbers;

    @Schema(description = "今日消费笔数", example = "15")
    private Long todayConsumptions;

    @Schema(description = "今日营收金额", example = "3200.00")
    private BigDecimal todayRevenue;

    @Schema(description = "今日充值笔数", example = "8")
    private Long todayRecharges;

    @Schema(description = "今日充值金额", example = "4000.00")
    private BigDecimal todayRechargeAmount;

    @Schema(description = "预约总数", example = "25")
    private Long totalAppointments;

    @Schema(description = "待处理预约数", example = "5")
    private Long pendingAppointments;
}
