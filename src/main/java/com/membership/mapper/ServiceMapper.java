package com.membership.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.membership.entity.ServiceItem;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface ServiceMapper extends BaseMapper<ServiceItem> {
}
