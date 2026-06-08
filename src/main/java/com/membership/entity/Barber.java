package com.membership.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("barbers")
public class Barber {
    @TableId(type = IdType.ASSIGN_UUID)
    private String id;
    private String name;
    private String phone;
    private String specialties;
    private String status;
    private String storeId;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
