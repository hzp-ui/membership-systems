package com.membership.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.membership.entity.LoginAttempt;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.time.LocalDateTime;

@Mapper
public interface LoginAttemptMapper extends BaseMapper<LoginAttempt> {

    @Delete("DELETE FROM login_attempts WHERE attempt_time < #{cutoff}")
    int deleteOldAttempts(@Param("cutoff") LocalDateTime cutoff);
}
