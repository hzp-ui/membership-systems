package com.membership.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.service.IService;
import com.membership.entity.Barber;

public interface BarberService extends IService<Barber> {
    IPage<Barber> page(int pageNum, int pageSize, String storeId);
}
