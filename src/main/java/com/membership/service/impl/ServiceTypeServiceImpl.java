package com.membership.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.membership.entity.ServiceType;
import com.membership.mapper.ServiceTypeMapper;
import com.membership.service.ServiceTypeService;
import org.springframework.stereotype.Service;

@Service
public class ServiceTypeServiceImpl extends ServiceImpl<ServiceTypeMapper, ServiceType> implements ServiceTypeService {
}
