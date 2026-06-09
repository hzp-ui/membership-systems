package com.membership.controller;

import com.membership.common.Result;
import com.membership.entity.RechargePackage;
import com.membership.service.PackageService;
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

@Tag(name = "充值套餐", description = "充值套餐的增删改查管理")
@RestController
@RequestMapping(value = "/api/v1/packages")
@RequiredArgsConstructor
public class PackageController {

    private final PackageService packageService;

    @Operation(summary = "套餐列表", description = "获取所有充值套餐的列表")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "查询成功", content = @Content(schema = @Schema(implementation = RechargePackage.class)))
    })
    @GetMapping
    public Result<List<RechargePackage>> list() {
        return Result.ok(packageService.list());
    }

    @Operation(summary = "创建套餐", description = "创建新的充值套餐")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "创建成功", content = @Content(schema = @Schema(implementation = RechargePackage.class))),
            @ApiResponse(responseCode = "400", description = "请求参数错误")
    })
    @PostMapping
    public Result<RechargePackage> create(@RequestBody RechargePackage pkg) {
        packageService.save(pkg);
        return Result.ok(pkg);
    }

    @Operation(summary = "更新套餐", description = "根据ID更新充值套餐信息")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "更新成功", content = @Content(schema = @Schema(implementation = RechargePackage.class))),
            @ApiResponse(responseCode = "404", description = "套餐不存在"),
            @ApiResponse(responseCode = "400", description = "请求参数错误")
    })
    @PutMapping("/{id}")
    public Result<RechargePackage> update(
            @Parameter(description = "套餐ID", required = true, example = "1") @PathVariable String id,
            @RequestBody RechargePackage pkg) {
        pkg.setId(id);
        packageService.updateById(pkg);
        return Result.ok(packageService.getById(id));
    }

    @Operation(summary = "删除套餐", description = "根据ID删除充值套餐")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "删除成功"),
            @ApiResponse(responseCode = "404", description = "套餐不存在")
    })
    @DeleteMapping("/{id}")
    public Result<Void> delete(@Parameter(description = "套餐ID", required = true, example = "1") @PathVariable String id) {
        packageService.removeById(id);
        return Result.ok();
    }
}
