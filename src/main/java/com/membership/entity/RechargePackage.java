package com.membership.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("recharge_packages")
public class RechargePackage {
    @TableId(type = IdType.ASSIGN_UUID)
    private String id;
    private String name;
    private BigDecimal amount;
    private BigDecimal bonus;
    private String status;
    private String storeId;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
