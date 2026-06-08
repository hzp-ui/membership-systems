package com.membership.controller;

import com.membership.common.Result;
import com.membership.entity.Store;
import com.membership.security.StoreAccessUtil;
import com.membership.service.StoreService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "门店管理")
@RestController
@RequestMapping(value = "/api/v1/stores")
@RequiredArgsConstructor
public class StoreController {

    private final StoreService storeService;
    private final StoreAccessUtil storeAccess;

    @Operation(summary = "获取门店列表")
    @GetMapping
    public Result<List<Store>> list(Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        if (storeId != null) {
            return Result.ok(storeService.listByIds(List.of(storeId)));
        }
        return Result.ok(storeService.list());
    }

    @Operation(summary = "获取门店详情")
    @GetMapping("/{id}")
    public Result<Store> get(@PathVariable String id, Authentication auth) {
        storeAccess.checkStoreAccess(id, auth);
        return Result.ok(storeService.getById(id));
    }

    @Operation(summary = "创建门店")
    @PostMapping
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public Result<Store> create(@RequestBody Store store) {
        storeService.save(store);
        return Result.ok(store);
    }

    @Operation(summary = "更新门店")
    @PutMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public Result<Store> update(@PathVariable String id, @RequestBody Store store) {
        store.setId(id);
        storeService.updateById(store);
        return Result.ok(storeService.getById(id));
    }

    @Operation(summary = "删除门店")
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public Result<Void> delete(@PathVariable String id) {
        storeService.removeById(id);
        return Result.ok();
    }
}
