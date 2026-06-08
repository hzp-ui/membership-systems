package com.membership.dto.response;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;

@Data
@Builder
public class MemberLoginResponse {
    private String token;
    private String memberId;
    private String name;
    private String phone;
    private String level;
    private BigDecimal balance;
    private Long points;
}
