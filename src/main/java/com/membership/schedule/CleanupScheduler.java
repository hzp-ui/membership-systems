package com.membership.schedule;

import com.membership.entity.LoginAttempt;
import com.membership.mapper.LoginAttemptMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

/**
 * 定时清理任务
 * - 清理7天前的登录尝试记录
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class CleanupScheduler {

    private final LoginAttemptMapper loginAttemptMapper;

    /**
     * 每天凌晨3点清理7天前的login_attempts记录
     */
    @Scheduled(cron = "0 0 3 * * ?")
    public void cleanOldLoginAttempts() {
        LocalDateTime cutoff = LocalDateTime.now().minusDays(7);
        int deleted = loginAttemptMapper.deleteOldAttempts(cutoff);
        if (deleted > 0) {
            log.info("已清理 {} 条7天前的登录尝试记录", deleted);
        }
    }
}
