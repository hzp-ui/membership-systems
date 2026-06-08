package com.membership.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.membership.entity.RechargePackage;
import com.membership.mapper.PackageMapper;
import com.membership.service.PackageService;
import org.springframework.stereotype.Service;

@Service
public class PackageServiceImpl extends ServiceImpl<PackageMapper, RechargePackage> implements PackageService {
}
