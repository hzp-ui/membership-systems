package com.membership.controller;

import com.membership.common.Result;
import com.membership.dto.request.LoginRequest;
import com.membership.dto.request.MemberLoginRequest;
import com.membership.dto.response.LoginResponse;
import com.membership.dto.response.MemberLoginResponse;
import com.membership.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@Tag(name = "认证管理")
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @Operation(summary = "管理员登录")
    @PostMapping("/admin/login")
    public Result<LoginResponse> adminLogin(@Valid @RequestBody LoginRequest request, HttpServletRequest httpRequest) {
        String ipAddress = httpRequest.getRemoteAddr();
        return Result.ok(authService.adminLogin(request, ipAddress));
    }

    @Operation(summary = "会员登录")
    @PostMapping("/member/login")
    public Result<MemberLoginResponse> memberLogin(@Valid @RequestBody MemberLoginRequest request, HttpServletRequest httpRequest) {
        String ipAddress = httpRequest.getRemoteAddr();
        return Result.ok(authService.memberLogin(request, ipAddress));
    }
}
