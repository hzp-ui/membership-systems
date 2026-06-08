package com.membership.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.membership.common.BusinessException;
import com.membership.dto.request.ConsumeRequest;
import com.membership.dto.response.ConsumptionRecordVO;
import com.membership.entity.Barber;
import com.membership.entity.ConsumptionRecord;
import com.membership.entity.Member;
import com.membership.entity.ServiceItem;
import com.membership.mapper.BarberMapper;
import com.membership.mapper.ConsumptionRecordMapper;
import com.membership.mapper.MemberMapper;
import com.membership.mapper.ServiceMapper;
import com.membership.service.AuditLogService;
import com.membership.service.ConsumptionService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ConsumptionServiceImpl extends ServiceImpl<ConsumptionRecordMapper, ConsumptionRecord>
        implements ConsumptionService {

    private final MemberMapper memberMapper;
    private final ServiceMapper serviceMapper;
    private final BarberMapper barberMapper;
    private final AuditLogService auditLogService;

    @Override
    @Transactional
    public ConsumptionRecord consume(ConsumeRequest request, String storeId, String operatorId, String operatorRole) {
        Member member = memberMapper.selectByIdForUpdate(request.getMemberId());
        if (member == null) {
            throw new BusinessException("会员不存在");
        }

        Barber barber = barberMapper.selectById(request.getBarberId());
        if (barber == null) {
            throw new BusinessException("理发师不存在");
        }

        boolean isCustom = "custom".equals(request.getServiceId());
        BigDecimal actualAmount;
        BigDecimal originalPrice;
        BigDecimal discountRate;
        String serviceName;

        if (isCustom) {
            // 自定义金额消费，无折扣
            if (request.getCustomAmount() == null || request.getCustomAmount().compareTo(BigDecimal.ZERO) <= 0) {
                throw new BusinessException("自定义金额必须大于0");
            }
            actualAmount = request.getCustomAmount().setScale(2, RoundingMode.HALF_UP);
            originalPrice = actualAmount;
            discountRate = BigDecimal.ONE;
            serviceName = "自定义消费";
        } else {
            // 按服务项目消费
            ServiceItem service = serviceMapper.selectById(request.getServiceId());
            if (service == null) {
                throw new BusinessException("服务项目不存在");
            }
            discountRate = getDiscountRate(member.getLevel(), service);
            originalPrice = service.getPrice();
            actualAmount = originalPrice.multiply(discountRate).setScale(2, RoundingMode.HALF_UP);
            serviceName = service.getName();
        }

        if (member.getBalance().compareTo(actualAmount) < 0) {
            throw new BusinessException("余额不足，当前余额: " + member.getBalance() + "，需支付: " + actualAmount);
        }

        member.setBalance(member.getBalance().subtract(actualAmount));
        int pointsEarned = actualAmount.intValue();
        member.setPoints(member.getPoints() + pointsEarned);
        memberMapper.updateById(member);

        ConsumptionRecord record = new ConsumptionRecord();
        record.setMemberId(request.getMemberId());
        record.setAmount(actualAmount);
        record.setOriginalPrice(originalPrice);
        record.setDiscount(discountRate);
        record.setServiceName(serviceName);
        record.setBarberName(barber.getName());
        record.setPointsEarned(pointsEarned);
        record.setStoreId(storeId);
        save(record);

        auditLogService.log(operatorId, operatorRole, "CONSUME", "member", request.getMemberId(),
                "消费" + actualAmount + "元，服务：" + serviceName, storeId);

        return record;
    }

    private BigDecimal getDiscountRate(String level, ServiceItem service) {
        if (level == null) {
            return service.getDiscountNormal();
        }
        return switch (level) {
            case "diamond" -> service.getDiscountDiamond();
            case "gold" -> service.getDiscountGold();
            case "silver" -> service.getDiscountSilver();
            default -> service.getDiscountNormal();
        };
    }

    @Override
    public IPage<ConsumptionRecordVO> pageByMember(int pageNum, int pageSize, String memberId, String storeId) {
        LambdaQueryWrapper<ConsumptionRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(ConsumptionRecord::getMemberId, memberId);
        if (storeId != null) {
            wrapper.eq(ConsumptionRecord::getStoreId, storeId);
        }
        wrapper.orderByDesc(ConsumptionRecord::getCreatedAt);
        IPage<ConsumptionRecord> page = baseMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
        return enrichWithMemberInfo(page);
    }

    @Override
    public IPage<ConsumptionRecordVO> page(int pageNum, int pageSize, String storeId, String memberId) {
        LambdaQueryWrapper<ConsumptionRecord> wrapper = new LambdaQueryWrapper<>();
        if (storeId != null) {
            wrapper.eq(ConsumptionRecord::getStoreId, storeId);
        }
        if (memberId != null) {
            wrapper.eq(ConsumptionRecord::getMemberId, memberId);
        }
        wrapper.orderByDesc(ConsumptionRecord::getCreatedAt);
        IPage<ConsumptionRecord> page = baseMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
        return enrichWithMemberInfo(page);
    }
    
    private IPage<ConsumptionRecordVO> enrichWithMemberInfo(IPage<ConsumptionRecord> page) {
        List<ConsumptionRecordVO> voList = page.getRecords().stream()
                .map(ConsumptionRecordVO::fromEntity)
                .collect(Collectors.toList());
        
        Set<String> memberIds = voList.stream()
                .map(ConsumptionRecordVO::getMemberId)
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
        
        Page<ConsumptionRecordVO> resultPage = new Page<>(page.getCurrent(), page.getSize(), page.getTotal());
        resultPage.setRecords(voList);
        return resultPage;
    }
}
