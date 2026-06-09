package com.membership.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.membership.common.Result;
import com.membership.entity.Barber;
import com.membership.security.StoreAccessUtil;
import com.membership.service.BarberService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@Tag(name = "理发师管理", description = "理发师信息的增删改查管理")
@RestController
@RequestMapping(value = "/api/v1/barbers")
@RequiredArgsConstructor
@Slf4j
public class BarberController {

    private final BarberService barberService;
    private final StoreAccessUtil storeAccess;

    @Operation(summary = "理发师列表", description = "分页查询理发师列表")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "查询成功", content = @Content(schema = @Schema(implementation = Barber.class))),
            @ApiResponse(responseCode = "403", description = "无权限访问")
    })
    @GetMapping
    public Result<IPage<Barber>> list(
            @Parameter(description = "页码", example = "1") @RequestParam(defaultValue = "1") int page,
            @Parameter(description = "每页大小", example = "20") @RequestParam(defaultValue = "20") int size,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(barberService.page(page, size, storeId));
    }

    @Operation(summary = "创建理发师", description = "创建新的理发师")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "创建成功", content = @Content(schema = @Schema(implementation = Barber.class))),
            @ApiResponse(responseCode = "400", description = "请求参数错误"),
            @ApiResponse(responseCode = "403", description = "无权限操作")
    })
    @PostMapping
    public Result<Barber> create(@RequestBody Barber barber, Authentication auth) {
        if (barber.getStoreId() == null) {
            barber.setStoreId(storeAccess.resolveStoreId(auth));
        }
        barberService.save(barber);
        return Result.ok(barber);
    }

    @Operation(summary = "更新理发师", description = "根据ID更新理发师信息")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "更新成功", content = @Content(schema = @Schema(implementation = Barber.class))),
            @ApiResponse(responseCode = "404", description = "理发师不存在"),
            @ApiResponse(responseCode = "400", description = "请求参数错误"),
            @ApiResponse(responseCode = "403", description = "无权限操作")
    })
    @PutMapping("/{id}")
    public Result<Barber> update(
            @Parameter(description = "理发师ID", required = true, example = "1") @PathVariable String id,
            @RequestBody Barber barber) {
        log.info("Received barber update request: id={}, name={}, phone={}, specialties={}", id, barber.getName(), barber.getPhone(), barber.getSpecialties());
        barber.setId(id);
        barberService.updateById(barber);
        return Result.ok(barberService.getById(id));
    }

    @Operation(summary = "删除理发师", description = "根据ID删除理发师")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "删除成功"),
            @ApiResponse(responseCode = "404", description = "理发师不存在"),
            @ApiResponse(responseCode = "403", description = "无权限操作")
    })
    @DeleteMapping("/{id}")
    public Result<Void> delete(@Parameter(description = "理发师ID", required = true, example = "1") @PathVariable String id) {
        barberService.removeById(id);
        return Result.ok();
    }
}
