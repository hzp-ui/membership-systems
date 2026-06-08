package com.membership.controller;

import com.membership.common.Result;
import com.membership.entity.ServiceType;
import com.membership.service.ServiceTypeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "服务类型")
@RestController
@RequestMapping(value = "/api/v1/service-types")
@RequiredArgsConstructor
public class ServiceTypeController {

    private final ServiceTypeService serviceTypeService;

    @Operation(summary = "服务类型列表")
    @GetMapping
    public Result<List<ServiceType>> list() {
        return Result.ok(serviceTypeService.list());
    }

    @Operation(summary = "创建服务类型")
    @PostMapping
    public Result<ServiceType> create(@RequestBody ServiceType serviceType) {
        serviceTypeService.save(serviceType);
        return Result.ok(serviceType);
    }

    @Operation(summary = "删除服务类型")
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable String id) {
        serviceTypeService.removeById(id);
        return Result.ok();
    }
}
