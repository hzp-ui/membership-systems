package com.membership.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("services")
public class ServiceItem {
    @TableId(type = IdType.ASSIGN_UUID)
    private String id;
    private String type;
    private String name;
    private BigDecimal price;
    private BigDecimal discountNormal;
    private BigDecimal discountSilver;
    private BigDecimal discountGold;
    private BigDecimal discountDiamond;
    private String storeId;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
