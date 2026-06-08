package com.membership.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("members")
public class Member {
    @TableId(type = IdType.ASSIGN_UUID)
    private String id;
    private String phone;
    private String passwordHash;
    private String name;
    private String level;
    private BigDecimal balance;
    private Long points;
    private String storeId;
    private String status;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
