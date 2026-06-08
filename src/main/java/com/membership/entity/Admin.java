package com.membership.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("admins")
public class Admin {
    @TableId(type = IdType.ASSIGN_UUID)
    private String id;
    private String username;
    private String passwordHash;
    private String name;
    private String phone;
    private String role;
    private String storeId;
    private String status;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
