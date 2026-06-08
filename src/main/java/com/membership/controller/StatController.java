package com.membership.controller;

import com.membership.common.Result;
import com.membership.security.StoreAccessUtil;
import com.membership.service.StatService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Tag(name = "统计分析")
@RestController
@RequestMapping(value = "/api/v1/stats")
@RequiredArgsConstructor
public class StatController {

    private final StatService statService;
    private final StoreAccessUtil storeAccess;

    @Operation(summary = "财务汇总")
    @GetMapping("/finance-summary")
    public Result<Map<String, Object>> financeSummary(
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(statService.financeSummary(storeId, startDate, endDate));
    }

    @Operation(summary = "日报表")
    @GetMapping("/daily-statements")
    public Result<List<Map<String, Object>>> dailyStatements(
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(statService.dailyStatements(storeId, startDate, endDate));
    }

    @Operation(summary = "营收统计")
    @GetMapping("/revenue")
    public Result<List<Map<String, Object>>> revenueStats(
            @RequestParam(defaultValue = "30") int days,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(statService.revenueStats(storeId, days));
    }

    @Operation(summary = "会员增长统计")
    @GetMapping("/member-growth")
    public Result<List<Map<String, Object>>> memberGrowthStats(
            @RequestParam(defaultValue = "30") int days,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(statService.memberGrowthStats(storeId, days));
    }

    @Operation(summary = "热门服务统计")
    @GetMapping("/hot-services")
    public Result<List<Map<String, Object>>> hotServicesStats(
            @RequestParam(defaultValue = "10") int limit,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(statService.hotServicesStats(storeId, limit));
    }
}
