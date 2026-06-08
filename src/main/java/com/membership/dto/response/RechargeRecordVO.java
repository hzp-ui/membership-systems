package com.membership.dto.response;

import com.membership.entity.RechargeRecord;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
public class RechargeRecordVO {
    private String id;
    private String memberId;
    private String memberName;
    private String memberPhone;
    private BigDecimal amount;
    private BigDecimal bonus;
    private String packageName;
    private String storeId;
    private LocalDateTime createdAt;
    
    public static RechargeRecordVO fromEntity(RechargeRecord record) {
        RechargeRecordVO vo = new RechargeRecordVO();
        vo.setId(record.getId());
        vo.setMemberId(record.getMemberId());
        vo.setAmount(record.getAmount());
        vo.setBonus(record.getBonus());
        vo.setPackageName(record.getPackageName());
        vo.setStoreId(record.getStoreId());
        vo.setCreatedAt(record.getCreatedAt());
        return vo;
    }
}
