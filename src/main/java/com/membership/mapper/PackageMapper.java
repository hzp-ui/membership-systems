package com.membership.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.membership.entity.RechargePackage;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface PackageMapper extends BaseMapper<RechargePackage> {
}
