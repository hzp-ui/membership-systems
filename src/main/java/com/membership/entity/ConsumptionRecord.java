package com.membership.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("consumption_records")
public class ConsumptionRecord {
    @TableId(type = IdType.ASSIGN_UUID)
    private String id;
    private String memberId;
    private BigDecimal amount;
    private BigDecimal originalPrice;
    private BigDecimal discount;
    private String serviceName;
    private String barberName;
    private Integer pointsEarned;
    private String storeId;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}
