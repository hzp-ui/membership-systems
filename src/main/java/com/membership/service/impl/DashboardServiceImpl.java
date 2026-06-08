package com.membership.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.membership.dto.response.DashboardResponse;
import com.membership.entity.*;
import com.membership.mapper.*;
import com.membership.service.DashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
public class DashboardServiceImpl implements DashboardService {

    private final MemberMapper memberMapper;
    private final BarberMapper barberMapper;
    private final ConsumptionRecordMapper consumptionRecordMapper;
    private final RechargeRecordMapper rechargeRecordMapper;
    private final AppointmentMapper appointmentMapper;

    @Override
    public DashboardResponse getDashboard(String storeId) {
        LocalDateTime todayStart = LocalDate.now().atStartOfDay();

        LambdaQueryWrapper<Member> memberWrapper = new LambdaQueryWrapper<>();
        LambdaQueryWrapper<Barber> barberWrapper = new LambdaQueryWrapper<>();
        LambdaQueryWrapper<ConsumptionRecord> consumeCountWrapper = new LambdaQueryWrapper<ConsumptionRecord>()
                .ge(ConsumptionRecord::getCreatedAt, todayStart);
        LambdaQueryWrapper<RechargeRecord> rechargeCountWrapper = new LambdaQueryWrapper<RechargeRecord>()
                .ge(RechargeRecord::getCreatedAt, todayStart);
        LambdaQueryWrapper<Appointment> apptWrapper = new LambdaQueryWrapper<>();
        LambdaQueryWrapper<Appointment> pendingWrapper = new LambdaQueryWrapper<Appointment>()
                .eq(Appointment::getStatus, "pending");

        if (storeId != null) {
            memberWrapper.eq(Member::getStoreId, storeId);
            barberWrapper.eq(Barber::getStoreId, storeId);
            consumeCountWrapper.eq(ConsumptionRecord::getStoreId, storeId);
            rechargeCountWrapper.eq(RechargeRecord::getStoreId, storeId);
            apptWrapper.eq(Appointment::getStoreId, storeId);
            pendingWrapper.eq(Appointment::getStoreId, storeId);
        }

        Long totalMembers = memberMapper.selectCount(memberWrapper);
        Long totalBarbers = barberMapper.selectCount(barberWrapper);
        Long todayConsumptions = consumptionRecordMapper.selectCount(consumeCountWrapper);
        Long todayRecharges = rechargeRecordMapper.selectCount(rechargeCountWrapper);
        Long totalAppointments = appointmentMapper.selectCount(apptWrapper);
        Long pendingAppointments = appointmentMapper.selectCount(pendingWrapper);

        // Use SQL SUM instead of Java stream for performance
        BigDecimal todayRevenue = consumptionRecordMapper.sumAmountSince(todayStart, storeId);
        BigDecimal todayRechargeAmount = rechargeRecordMapper.sumAmountSince(todayStart, storeId);

        return DashboardResponse.builder()
                .totalMembers(totalMembers)
                .totalBarbers(totalBarbers)
                .todayConsumptions(todayConsumptions)
                .todayRevenue(todayRevenue)
                .todayRecharges(todayRecharges)
                .todayRechargeAmount(todayRechargeAmount)
                .totalAppointments(totalAppointments)
                .pendingAppointments(pendingAppointments)
                .build();
    }
}
