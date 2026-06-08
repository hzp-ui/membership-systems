package com.membership.controller;

import com.membership.common.Result;
import com.membership.entity.ServiceItem;
import com.membership.service.ServiceItemService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "服务项目管理")
@RestController
@RequestMapping(value = "/api/v1/services")
@RequiredArgsConstructor
public class ServiceController {

    private final ServiceItemService serviceItemService;

    @Operation(summary = "服务列表")
    @GetMapping
    public Result<List<ServiceItem>> list() {
        return Result.ok(serviceItemService.list());
    }

    @Operation(summary = "创建服务")
    @PostMapping
    public Result<ServiceItem> create(@RequestBody ServiceItem serviceItem) {
        serviceItemService.save(serviceItem);
        return Result.ok(serviceItem);
    }

    @Operation(summary = "更新服务")
    @PutMapping("/{id}")
    public Result<ServiceItem> update(@PathVariable String id, @RequestBody ServiceItem serviceItem) {
        serviceItem.setId(id);
        serviceItemService.updateById(serviceItem);
        return Result.ok(serviceItemService.getById(id));
    }

    @Operation(summary = "删除服务")
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable String id) {
        serviceItemService.removeById(id);
        return Result.ok();
    }
}
