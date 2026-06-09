package com.membership.controller;

import com.membership.common.Result;
import com.membership.dto.request.LoginRequest;
import com.membership.dto.request.MemberLoginRequest;
import com.membership.dto.response.LoginResponse;
import com.membership.dto.response.MemberLoginResponse;
import com.membership.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@Tag(name = "认证管理", description = "管理员和会员的登录认证接口")
@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @Operation(summary = "管理员登录", description = "管理员使用用户名和密码登录系统，返回登录令牌")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "登录成功", content = @Content(schema = @Schema(implementation = LoginResponse.class))),
            @ApiResponse(responseCode = "401", description = "用户名或密码错误"),
            @ApiResponse(responseCode = "400", description = "请求参数错误")
    })
    @PostMapping("/admin/login")
    public Result<LoginResponse> adminLogin(@Valid @RequestBody LoginRequest request, HttpServletRequest httpRequest) {
        String ipAddress = httpRequest.getRemoteAddr();
        return Result.ok(authService.adminLogin(request, ipAddress));
    }

    @Operation(summary = "会员登录", description = "会员使用手机号和密码登录系统，返回登录令牌")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "登录成功", content = @Content(schema = @Schema(implementation = MemberLoginResponse.class))),
            @ApiResponse(responseCode = "401", description = "手机号或密码错误"),
            @ApiResponse(responseCode = "400", description = "请求参数错误")
    })
    @PostMapping("/member/login")
    public Result<MemberLoginResponse> memberLogin(@Valid @RequestBody MemberLoginRequest request, HttpServletRequest httpRequest) {
        String ipAddress = httpRequest.getRemoteAddr();
        return Result.ok(authService.memberLogin(request, ipAddress));
    }
}
