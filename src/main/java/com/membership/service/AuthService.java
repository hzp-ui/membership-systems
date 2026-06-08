package com.membership.service;

import com.membership.dto.request.LoginRequest;
import com.membership.dto.request.MemberLoginRequest;
import com.membership.dto.response.LoginResponse;
import com.membership.dto.response.MemberLoginResponse;

public interface AuthService {
    LoginResponse adminLogin(LoginRequest request, String ipAddress);
    MemberLoginResponse memberLogin(MemberLoginRequest request, String ipAddress);
}
