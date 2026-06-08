package com.membership.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.service.IService;
import com.membership.dto.response.AppointmentVO;
import com.membership.entity.Appointment;

public interface AppointmentService extends IService<Appointment> {
    IPage<AppointmentVO> page(int pageNum, int pageSize, String storeId, String status);
}
