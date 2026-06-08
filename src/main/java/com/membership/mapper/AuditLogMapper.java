package com.membership.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.membership.entity.AuditLog;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface AuditLogMapper extends BaseMapper<AuditLog> {
}
