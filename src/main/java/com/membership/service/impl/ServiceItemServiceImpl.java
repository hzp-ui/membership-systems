package com.membership.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.membership.entity.ServiceItem;
import com.membership.mapper.ServiceMapper;
import com.membership.service.ServiceItemService;
import org.springframework.stereotype.Service;

@org.springframework.stereotype.Service
public class ServiceItemServiceImpl extends ServiceImpl<ServiceMapper, ServiceItem> implements ServiceItemService {
}
