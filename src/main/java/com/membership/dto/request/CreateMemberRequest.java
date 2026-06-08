package com.membership.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import java.math.BigDecimal;

@Data
public class CreateMemberRequest {
    @NotBlank(message = "手机号不能为空")
    private String phone;
    private String password;
    @NotBlank(message = "姓名不能为空")
    private String name;
    private String level;
    @NotNull(message = "余额不能为空")
    private BigDecimal balance;
    private String storeId;
}
