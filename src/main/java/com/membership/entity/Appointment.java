package com.membership.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("appointments")
public class Appointment {
    @TableId(type = IdType.ASSIGN_UUID)
    private String id;
    private String memberId;
    private String barberId;
    private String serviceId;
    private LocalDateTime appointmentTime;
    private String status;
    private String storeId;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
