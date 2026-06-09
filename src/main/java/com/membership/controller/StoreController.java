package com.membership.controller;

import com.membership.common.Result;
import com.membership.entity.Store;
import com.membership.security.StoreAccessUtil;
import com.membership.service.StoreService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "门店管理", description = "门店信息的增删改查，仅超级管理员可操作")
@RestController
@RequestMapping(value = "/api/v1/stores")
@RequiredArgsConstructor
public class StoreController {

    private final StoreService storeService;
    private final StoreAccessUtil storeAccess;

    @Operation(summary = "获取门店列表", description = "获取当前管理员可访问的门店列表")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "查询成功", content = @Content(schema = @Schema(implementation = Store.class))),
            @ApiResponse(responseCode = "403", description = "无权限访问")
    })
    @GetMapping
    public Result<List<Store>> list(Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        if (storeId != null) {
            return Result.ok(storeService.listByIds(List.of(storeId)));
        }
        return Result.ok(storeService.list());
    }

    @Operation(summary = "获取门店详情", description = "根据门店ID获取门店详细信息")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "查询成功", content = @Content(schema = @Schema(implementation = Store.class))),
            @ApiResponse(responseCode = "404", description = "门店不存在"),
            @ApiResponse(responseCode = "403", description = "无权限访问")
    })
    @GetMapping("/{id}")
    public Result<Store> get(@Parameter(description = "门店ID", required = true, example = "1") @PathVariable String id, Authentication auth) {
        storeAccess.checkStoreAccess(id, auth);
        return Result.ok(storeService.getById(id));
    }

    @Operation(summary = "创建门店", description = "创建新的门店（仅超级管理员）")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "创建成功", content = @Content(schema = @Schema(implementation = Store.class))),
            @ApiResponse(responseCode = "400", description = "请求参数错误"),
            @ApiResponse(responseCode = "403", description = "无权限操作")
    })
    @PostMapping
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public Result<Store> create(@RequestBody Store store) {
        storeService.save(store);
        return Result.ok(store);
    }

    @Operation(summary = "更新门店", description = "根据门店ID更新门店信息（仅超级管理员）")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "更新成功", content = @Content(schema = @Schema(implementation = Store.class))),
            @ApiResponse(responseCode = "404", description = "门店不存在"),
            @ApiResponse(responseCode = "400", description = "请求参数错误"),
            @ApiResponse(responseCode = "403", description = "无权限操作")
    })
    @PutMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public Result<Store> update(
            @Parameter(description = "门店ID", required = true, example = "1") @PathVariable String id,
            @RequestBody Store store) {
        store.setId(id);
        storeService.updateById(store);
        return Result.ok(storeService.getById(id));
    }

    @Operation(summary = "删除门店", description = "根据门店ID删除门店（仅超级管理员）")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "删除成功"),
            @ApiResponse(responseCode = "404", description = "门店不存在"),
            @ApiResponse(responseCode = "403", description = "无权限操作")
    })
    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public Result<Void> delete(@Parameter(description = "门店ID", required = true, example = "1") @PathVariable String id) {
        storeService.removeById(id);
        return Result.ok();
    }
}
