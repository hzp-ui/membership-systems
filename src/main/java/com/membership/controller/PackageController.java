package com.membership.controller;

import com.membership.common.Result;
import com.membership.entity.RechargePackage;
import com.membership.service.PackageService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "充值套餐")
@RestController
@RequestMapping(value = "/api/v1/packages")
@RequiredArgsConstructor
public class PackageController {

    private final PackageService packageService;

    @Operation(summary = "套餐列表")
    @GetMapping
    public Result<List<RechargePackage>> list() {
        return Result.ok(packageService.list());
    }

    @Operation(summary = "创建套餐")
    @PostMapping
    public Result<RechargePackage> create(@RequestBody RechargePackage pkg) {
        packageService.save(pkg);
        return Result.ok(pkg);
    }

    @Operation(summary = "更新套餐")
    @PutMapping("/{id}")
    public Result<RechargePackage> update(@PathVariable String id, @RequestBody RechargePackage pkg) {
        pkg.setId(id);
        packageService.updateById(pkg);
        return Result.ok(packageService.getById(id));
    }

    @Operation(summary = "删除套餐")
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable String id) {
        packageService.removeById(id);
        return Result.ok();
    }
}
