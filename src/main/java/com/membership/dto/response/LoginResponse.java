package com.membership.dto.response;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class LoginResponse {
    private String token;
    private String userId;
    private String username;
    private String name;
    private String role;
    private String storeId;
}
