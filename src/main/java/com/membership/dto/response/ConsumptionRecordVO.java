package com.membership.dto.response;

import com.membership.entity.ConsumptionRecord;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
public class ConsumptionRecordVO {
    private String id;
    private String memberId;
    private String memberName;
    private String memberPhone;
    private BigDecimal amount;
    private BigDecimal originalPrice;
    private BigDecimal discount;
    private Integer pointsEarned;
    private String serviceName;
    private String barberName;
    private String storeId;
    private LocalDateTime createdAt;
    
    public static ConsumptionRecordVO fromEntity(ConsumptionRecord record) {
        ConsumptionRecordVO vo = new ConsumptionRecordVO();
        vo.setId(record.getId());
        vo.setMemberId(record.getMemberId());
        vo.setAmount(record.getAmount());
        vo.setOriginalPrice(record.getOriginalPrice());
        vo.setDiscount(record.getDiscount());
        vo.setPointsEarned(record.getPointsEarned());
        vo.setServiceName(record.getServiceName());
        vo.setBarberName(record.getBarberName());
        vo.setStoreId(record.getStoreId());
        vo.setCreatedAt(record.getCreatedAt());
        return vo;
    }
}
