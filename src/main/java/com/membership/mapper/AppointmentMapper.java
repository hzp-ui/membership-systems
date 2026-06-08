package com.membership.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.membership.entity.Appointment;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface AppointmentMapper extends BaseMapper<Appointment> {
}
