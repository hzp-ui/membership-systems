package com.membership.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.membership.common.BusinessException;
import com.membership.dto.request.CreateAdminRequest;
import com.membership.entity.Admin;
import com.membership.mapper.AdminMapper;
import com.membership.service.AdminService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
@RequiredArgsConstructor
public class AdminServiceImpl extends ServiceImpl<AdminMapper, Admin> implements AdminService {

    private final PasswordEncoder passwordEncoder;

    @Override
    public IPage<Admin> page(int pageNum, int pageSize, String storeId) {
        LambdaQueryWrapper<Admin> wrapper = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(storeId)) {
            wrapper.eq(Admin::getStoreId, storeId);
        }
        wrapper.orderByDesc(Admin::getCreatedAt);
        return baseMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
    }

    @Override
    public Admin create(CreateAdminRequest request) {
        Long count = lambdaQuery().eq(Admin::getUsername, request.getUsername()).count();
        if (count > 0) {
            throw new BusinessException("用户名已存在");
        }
        Admin admin = new Admin();
        admin.setUsername(request.getUsername());
        admin.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        admin.setName(request.getName());
        admin.setPhone(request.getPhone());
        admin.setRole(request.getRole());
        admin.setStoreId(request.getStoreId());
        admin.setStatus("active");
        save(admin);
        return admin;
    }

    @Override
    public Admin update(String id, Admin admin) {
        Admin existing = getById(id);
        if (existing == null) {
            throw new BusinessException("管理员不存在");
        }
        admin.setId(id);
        admin.setPasswordHash(null); // Don't update password through this method
        updateById(admin);
        return getById(id);
    }
}
