package com.membership.service;

import com.membership.entity.AuditLog;

/**
 * 审计日志服务
 */
public interface AuditLogService {
    /**
     * 记录审计日志
     */
    void log(String userId, String userRole, String action, String targetType, String targetId, String detail, String storeId, String ipAddress);

    /**
     * 记录审计日志（简化版，无IP）
     */
    void log(String userId, String userRole, String action, String targetType, String targetId, String detail, String storeId);
}
