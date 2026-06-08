package com.membership.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("login_attempts")
public class LoginAttempt {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String phone;
    private Boolean success;
    private String ipAddress;
    private LocalDateTime attemptTime;
}
