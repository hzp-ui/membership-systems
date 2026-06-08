package com.membership.service.impl;

import com.membership.entity.AuditLog;
import com.membership.mapper.AuditLogMapper;
import com.membership.service.AuditLogService;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AuditLogServiceImpl implements AuditLogService {

    private final AuditLogMapper auditLogMapper;

    @Override
    @Async
    public void log(String userId, String userRole, String action, String targetType, String targetId, String detail, String storeId, String ipAddress) {
        AuditLog auditLog = new AuditLog();
        auditLog.setUserId(userId);
        auditLog.setUserRole(userRole);
        auditLog.setAction(action);
        auditLog.setTargetType(targetType);
        auditLog.setTargetId(targetId);
        auditLog.setDetail(detail);
        auditLog.setStoreId(storeId);
        auditLog.setIpAddress(ipAddress);
        auditLogMapper.insert(auditLog);
    }

    @Override
    @Async
    public void log(String userId, String userRole, String action, String targetType, String targetId, String detail, String storeId) {
        log(userId, userRole, action, targetType, targetId, detail, storeId, null);
    }
}
