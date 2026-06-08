package com.membership.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.membership.common.BusinessException;
import com.membership.dto.response.AppointmentVO;
import com.membership.entity.Appointment;
import com.membership.entity.Barber;
import com.membership.entity.Member;
import com.membership.entity.ServiceItem;
import com.membership.mapper.AppointmentMapper;
import com.membership.mapper.BarberMapper;
import com.membership.mapper.MemberMapper;
import com.membership.mapper.ServiceMapper;
import com.membership.service.AppointmentService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AppointmentServiceImpl extends ServiceImpl<AppointmentMapper, Appointment>
        implements AppointmentService {

    private final MemberMapper memberMapper;
    private final BarberMapper barberMapper;
    private final ServiceMapper serviceMapper;

    private static final Map<String, Set<String>> VALID_TRANSITIONS = Map.of(
            "pending", Set.of("confirmed", "cancelled"),
            "confirmed", Set.of("completed", "cancelled")
    );

    @Override
    public IPage<AppointmentVO> page(int pageNum, int pageSize, String storeId, String status) {
        LambdaQueryWrapper<Appointment> wrapper = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(storeId)) {
            wrapper.eq(Appointment::getStoreId, storeId);
        }
        if (StringUtils.hasText(status)) {
            wrapper.eq(Appointment::getStatus, status);
        }
        wrapper.orderByDesc(Appointment::getCreatedAt);
        IPage<Appointment> page = baseMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
        return enrichWithMemberInfo(page);
    }
    
    private IPage<AppointmentVO> enrichWithMemberInfo(IPage<Appointment> page) {
        List<AppointmentVO> voList = page.getRecords().stream()
                .map(AppointmentVO::fromEntity)
                .collect(Collectors.toList());
        
        // 1. 填充会员信息
        Set<String> memberIds = voList.stream()
                .map(AppointmentVO::getMemberId)
                .collect(Collectors.toSet());
        
        if (!memberIds.isEmpty()) {
            List<Member> members = memberMapper.selectBatchIds(memberIds);
            Map<String, Member> memberMap = members.stream()
                    .collect(Collectors.toMap(Member::getId, m -> m));
            
            voList.forEach(vo -> {
                Member member = memberMap.get(vo.getMemberId());
                if (member != null) {
                    vo.setMemberName(member.getName());
                    vo.setMemberPhone(member.getPhone());
                }
            });
        }
        
        // 2. 填充理发师信息
        Set<String> barberIds = voList.stream()
                .map(AppointmentVO::getBarberId)
                .filter(id -> id != null && !id.isEmpty())
                .collect(Collectors.toSet());
        
        if (!barberIds.isEmpty()) {
            List<Barber> barbers = barberMapper.selectBatchIds(barberIds);
            Map<String, Barber> barberMap = barbers.stream()
                    .collect(Collectors.toMap(Barber::getId, b -> b));
            
            voList.forEach(vo -> {
                Barber barber = barberMap.get(vo.getBarberId());
                if (barber != null) {
                    vo.setBarberName(barber.getName());
                }
            });
        }
        
        // 3. 填充服务项目信息
        Set<String> serviceIds = voList.stream()
                .map(AppointmentVO::getServiceId)
                .filter(id -> id != null && !id.isEmpty())
                .collect(Collectors.toSet());
        
        if (!serviceIds.isEmpty()) {
            List<ServiceItem> services = serviceMapper.selectBatchIds(serviceIds);
            Map<String, ServiceItem> serviceMap = services.stream()
                    .collect(Collectors.toMap(ServiceItem::getId, s -> s));
            
            voList.forEach(vo -> {
                ServiceItem service = serviceMap.get(vo.getServiceId());
                if (service != null) {
                    vo.setServiceName(service.getName());
                }
            });
        }
        
        Page<AppointmentVO> resultPage = new Page<>(page.getCurrent(), page.getSize(), page.getTotal());
        resultPage.setRecords(voList);
        return resultPage;
    }

    public void validateTransition(String currentStatus, String targetStatus) {
        Set<String> allowed = VALID_TRANSITIONS.get(currentStatus);
        if (allowed == null) {
            throw new BusinessException("预约当前状态为「" + currentStatus + "」，不可变更");
        }
        if (!allowed.contains(targetStatus)) {
            throw new BusinessException("预约状态不允许从「" + currentStatus + "」变更为「" + targetStatus + "」");
        }
    }
}
