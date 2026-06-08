package com.membership.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.membership.entity.Barber;
import com.membership.mapper.BarberMapper;
import com.membership.service.BarberService;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
public class BarberServiceImpl extends ServiceImpl<BarberMapper, Barber> implements BarberService {
    @Override
    public IPage<Barber> page(int pageNum, int pageSize, String storeId) {
        LambdaQueryWrapper<Barber> wrapper = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(storeId)) {
            wrapper.eq(Barber::getStoreId, storeId);
        }
        wrapper.orderByDesc(Barber::getCreatedAt);
        return baseMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
    }
}
