package com.membership.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.membership.common.BusinessException;
import com.membership.dto.request.LoginRequest;
import com.membership.dto.request.MemberLoginRequest;
import com.membership.dto.response.LoginResponse;
import com.membership.dto.response.MemberLoginResponse;
import com.membership.entity.Admin;
import com.membership.entity.LoginAttempt;
import com.membership.entity.Member;
import com.membership.mapper.AdminMapper;
import com.membership.mapper.LoginAttemptMapper;
import com.membership.mapper.MemberMapper;
import com.membership.security.JwtUtil;
import com.membership.service.AuditLogService;
import com.membership.service.AuthService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.LocalDateTime;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthServiceImpl implements AuthService {

    private final AdminMapper adminMapper;
    private final MemberMapper memberMapper;
    private final LoginAttemptMapper loginAttemptMapper;
    private final PasswordEncoder passwordEncoder;
    private final AuditLogService auditLogService;
    private final JwtUtil jwtUtil;

    private static final int MAX_LOGIN_ATTEMPTS = 5;
    private static final int LOCKOUT_MINUTES = 15;

    @Override
    public LoginResponse adminLogin(LoginRequest request, String ipAddress) {
        // Rate limit check
        checkLoginAttempts(request.getUsername(), "admin");

        Admin admin = adminMapper.selectOne(
                new LambdaQueryWrapper<Admin>().eq(Admin::getUsername, request.getUsername()));

        if (admin == null || !passwordEncoder.matches(request.getPassword(), admin.getPasswordHash())) {
            recordAttempt(request.getUsername(), false, ipAddress);
            throw new BusinessException(401, "用户名或密码错误");
        }

        if ("inactive".equals(admin.getStatus())) {
            throw new BusinessException(403, "账号已停用");
        }

        recordAttempt(request.getUsername(), true, ipAddress);

        // 审计日志：管理员登录成功
        auditLogService.log(admin.getId(), admin.getRole(), "LOGIN", "admin", admin.getId(), "管理员登录成功", admin.getStoreId(), ipAddress);

        String token = jwtUtil.generateToken(admin.getId(), admin.getRole(), admin.getStoreId());
        return LoginResponse.builder()
                .token(token)
                .userId(admin.getId())
                .username(admin.getUsername())
                .name(admin.getName())
                .role(admin.getRole())
                .storeId(admin.getStoreId())
                .build();
    }

    @Override
    public MemberLoginResponse memberLogin(MemberLoginRequest request, String ipAddress) {
        checkLoginAttempts(request.getPhone(), "member");

        Member member = memberMapper.selectOne(
                new LambdaQueryWrapper<Member>().eq(Member::getPhone, request.getPhone()));

        if (member == null || !passwordEncoder.matches(request.getPassword(), member.getPasswordHash())) {
            recordAttempt(request.getPhone(), false, ipAddress);
            throw new BusinessException(401, "手机号或密码错误");
        }

        if ("inactive".equals(member.getStatus())) {
            throw new BusinessException(403, "账号已停用");
        }

        recordAttempt(request.getPhone(), true, ipAddress);

        // 审计日志：会员登录成功
        auditLogService.log(member.getId(), "member", "LOGIN", "member", member.getId(), "会员登录成功", member.getStoreId(), ipAddress);

        String token = jwtUtil.generateToken(member.getId(), "member", member.getStoreId());
        return MemberLoginResponse.builder()
                .token(token)
                .memberId(member.getId())
                .name(member.getName())
                .phone(member.getPhone())
                .level(member.getLevel())
                .balance(member.getBalance())
                .points(member.getPoints())
                .build();
    }

    private void checkLoginAttempts(String identifier, String userType) {
        LocalDateTime since = LocalDateTime.now().minusMinutes(LOCKOUT_MINUTES);
        Long failCount = loginAttemptMapper.selectCount(
                new LambdaQueryWrapper<LoginAttempt>()
                        .eq(LoginAttempt::getPhone, identifier)
                        .eq(LoginAttempt::getSuccess, false)
                        .ge(LoginAttempt::getAttemptTime, since));

        if (failCount != null && failCount >= MAX_LOGIN_ATTEMPTS) {
            LoginAttempt lastAttempt = loginAttemptMapper.selectOne(
                    new LambdaQueryWrapper<LoginAttempt>()
                            .eq(LoginAttempt::getPhone, identifier)
                            .eq(LoginAttempt::getSuccess, false)
                            .orderByDesc(LoginAttempt::getAttemptTime)
                            .last("LIMIT 1"));
            if (lastAttempt != null) {
                LocalDateTime unlockTime = lastAttempt.getAttemptTime().plusMinutes(LOCKOUT_MINUTES);
                long remainingMinutes = java.time.Duration.between(LocalDateTime.now(), unlockTime).toMinutes();
                if (remainingMinutes > 0) {
                    throw new BusinessException(429, "账户已锁定，请" + remainingMinutes + "分钟后再试");
                }
            }
        }
    }

    private void recordAttempt(String identifier, boolean success, String ipAddress) {
        LoginAttempt attempt = new LoginAttempt();
        attempt.setPhone(identifier);
        attempt.setSuccess(success);
        attempt.setIpAddress(ipAddress);
        attempt.setAttemptTime(LocalDateTime.now());
        loginAttemptMapper.insert(attempt);
    }
}
