package com.membership.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("service_types")
public class ServiceType {
    @TableId(type = IdType.ASSIGN_UUID)
    private String id;
    private String name;
    private String storeId;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}
