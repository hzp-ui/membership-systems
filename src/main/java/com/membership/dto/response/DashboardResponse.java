package com.membership.dto.response;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;

@Data
@Builder
public class DashboardResponse {
    private Long totalMembers;
    private Long totalBarbers;
    private Long todayConsumptions;
    private BigDecimal todayRevenue;
    private Long todayRecharges;
    private BigDecimal todayRechargeAmount;
    private Long totalAppointments;
    private Long pendingAppointments;
}
