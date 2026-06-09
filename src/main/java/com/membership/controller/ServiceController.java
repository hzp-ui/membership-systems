package com.membership.controller;

import com.membership.common.Result;
import com.membership.entity.ServiceItem;
import com.membership.service.ServiceItemService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "服务项目管理", description = "理发店服务项目的增删改查")
@RestController
@RequestMapping(value = "/api/v1/services")
@RequiredArgsConstructor
public class ServiceController {

    private final ServiceItemService serviceItemService;

    @Operation(summary = "服务列表", description = "获取所有服务项目的列表")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "查询成功", content = @Content(schema = @Schema(implementation = ServiceItem.class)))
    })
    @GetMapping
    public Result<List<ServiceItem>> list() {
        return Result.ok(serviceItemService.list());
    }

    @Operation(summary = "创建服务", description = "创建新的服务项目")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "创建成功", content = @Content(schema = @Schema(implementation = ServiceItem.class))),
            @ApiResponse(responseCode = "400", description = "请求参数错误")
    })
    @PostMapping
    public Result<ServiceItem> create(@RequestBody ServiceItem serviceItem) {
        serviceItemService.save(serviceItem);
        return Result.ok(serviceItem);
    }

    @Operation(summary = "更新服务", description = "根据ID更新服务项目信息")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "更新成功", content = @Content(schema = @Schema(implementation = ServiceItem.class))),
            @ApiResponse(responseCode = "404", description = "服务不存在"),
            @ApiResponse(responseCode = "400", description = "请求参数错误")
    })
    @PutMapping("/{id}")
    public Result<ServiceItem> update(
            @Parameter(description = "服务ID", required = true, example = "1") @PathVariable String id,
            @RequestBody ServiceItem serviceItem) {
        serviceItem.setId(id);
        serviceItemService.updateById(serviceItem);
        return Result.ok(serviceItemService.getById(id));
    }

    @Operation(summary = "删除服务", description = "根据ID删除服务项目")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "删除成功"),
            @ApiResponse(responseCode = "404", description = "服务不存在")
    })
    @DeleteMapping("/{id}")
    public Result<Void> delete(@Parameter(description = "服务ID", required = true, example = "1") @PathVariable String id) {
        serviceItemService.removeById(id);
        return Result.ok();
    }
}
