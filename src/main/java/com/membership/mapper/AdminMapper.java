package com.membership.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.membership.entity.Admin;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface AdminMapper extends BaseMapper<Admin> {
}
