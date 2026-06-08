package com.membership.service.impl;

import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.membership.entity.Store;
import com.membership.mapper.StoreMapper;
import com.membership.service.StoreService;
import org.springframework.stereotype.Service;

@Service
public class StoreServiceImpl extends ServiceImpl<StoreMapper, Store> implements StoreService {
}
