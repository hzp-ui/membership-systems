package com.membership.controller;

import com.membership.common.Result;
import com.membership.dto.response.DashboardResponse;
import com.membership.security.StoreAccessUtil;
import com.membership.service.DashboardService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@Tag(name = "仪表盘")
@RestController
@RequestMapping(value = "/api/v1/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final DashboardService dashboardService;
    private final StoreAccessUtil storeAccess;

    @Operation(summary = "获取仪表盘数据")
    @GetMapping
    public Result<DashboardResponse> get(Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(dashboardService.getDashboard(storeId));
    }
}
