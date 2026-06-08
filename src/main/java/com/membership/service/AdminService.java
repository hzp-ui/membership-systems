package com.membership.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.service.IService;
import com.membership.dto.request.CreateAdminRequest;
import com.membership.entity.Admin;

public interface AdminService extends IService<Admin> {
    IPage<Admin> page(int pageNum, int pageSize, String storeId);
    Admin create(CreateAdminRequest request);
    Admin update(String id, Admin admin);
}
