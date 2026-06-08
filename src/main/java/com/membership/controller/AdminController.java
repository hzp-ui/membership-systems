package com.membership.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.membership.common.Result;
import com.membership.dto.request.CreateAdminRequest;
import com.membership.entity.Admin;
import com.membership.service.AdminService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import com.membership.security.StoreAccessUtil;

@Tag(name = "管理员管理")
@RestController
@RequestMapping("/api/v1/admins")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;
    private final StoreAccessUtil storeAccess;

    @Operation(summary = "管理员列表")
    @GetMapping
    @PreAuthorize("hasAnyRole('SUPER_ADMIN', 'STORE_ADMIN')")
    public Result<IPage<Admin>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(adminService.page(page, size, storeId));
    }

    @Operation(summary = "创建管理员")
    @PostMapping
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public Result<Admin> create(@RequestBody CreateAdminRequest request) {
        return Result.ok(adminService.create(request));
    }

    @Operation(summary = "更新管理员")
    @PutMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public Result<Admin> update(@PathVariable String id, @RequestBody Admin admin) {
        admin.setId(id);
        return Result.ok(adminService.update(id, admin));
    }

    @Operation(summary = "删除管理员")
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public Result<Void> delete(@PathVariable String id) {
        adminService.removeById(id);
        return Result.ok();
    }

    @Operation(summary = "按门店查询管理员")
    @GetMapping("/by-store/{storeId}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public Result<IPage<Admin>> listByStore(
            @PathVariable String storeId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size) {
        return Result.ok(adminService.page(page, size, storeId));
    }
}
