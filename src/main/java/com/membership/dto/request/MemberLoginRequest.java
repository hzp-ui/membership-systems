package com.membership.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class MemberLoginRequest {
    @NotBlank(message = "手机号不能为空")
    private String phone;
    @NotBlank(message = "密码不能为空")
    private String password;
}
