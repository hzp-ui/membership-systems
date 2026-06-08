package com.membership.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("recharge_records")
public class RechargeRecord {
    @TableId(type = IdType.ASSIGN_UUID)
    private String id;
    private String memberId;
    private BigDecimal amount;
    private BigDecimal bonus;
    private String packageName;
    private String storeId;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}
