package com.membership.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.membership.common.BusinessException;
import com.membership.common.Result;
import com.membership.dto.request.CreateAppointmentRequest;
import com.membership.dto.response.AppointmentVO;
import com.membership.entity.Appointment;
import com.membership.entity.Member;
import com.membership.security.StoreAccessUtil;
import com.membership.service.AppointmentService;
import com.membership.service.MemberService;
import com.membership.service.impl.AppointmentServiceImpl;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@Tag(name = "预约管理", description = "会员预约的增删改查及状态管理")
@RestController
@RequestMapping(value = "/api/v1/appointments")
@RequiredArgsConstructor
public class AppointmentController {

    private final AppointmentService appointmentService;
    private final AppointmentServiceImpl appointmentServiceImpl;
    private final StoreAccessUtil storeAccess;
    private final MemberService memberService;

    @Operation(summary = "预约列表", description = "分页查询预约列表，可按状态筛选")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "查询成功", content = @Content(schema = @Schema(implementation = AppointmentVO.class))),
            @ApiResponse(responseCode = "403", description = "无权限访问")
    })
    @GetMapping
    public Result<IPage<AppointmentVO>> list(
            @Parameter(description = "页码", example = "1") @RequestParam(defaultValue = "1") int page,
            @Parameter(description = "每页大小", example = "20") @RequestParam(defaultValue = "20") int size,
            @Parameter(description = "预约状态（pending/confirmed/completed/cancelled）", example = "pending") @RequestParam(required = false) String status,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(appointmentService.page(page, size, storeId, status));
    }

    @Operation(summary = "创建预约", description = "创建新的预约记录")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "创建成功", content = @Content(schema = @Schema(implementation = Appointment.class))),
            @ApiResponse(responseCode = "400", description = "请求参数错误"),
            @ApiResponse(responseCode = "404", description = "会员或理发师不存在"),
            @ApiResponse(responseCode = "403", description = "无权限操作")
    })
    @PostMapping
    public Result<Appointment> create(@Valid @RequestBody CreateAppointmentRequest request,
                                      Authentication auth) {
        Appointment appt = new Appointment();
        appt.setMemberId(request.getMemberId());
        appt.setBarberId(request.getBarberId());
        appt.setServiceId(request.getServiceId());
        appt.setAppointmentTime(request.getAppointmentTime());
        appt.setStatus("pending");
        String storeId = request.getStoreId();
        if (storeId == null) {
            storeId = storeAccess.resolveStoreId(auth);
        }
        if (storeId == null) {
            Member member = memberService.getById(request.getMemberId());
            if (member != null) {
                storeId = member.getStoreId();
            }
        }
        appt.setStoreId(storeId);
        appointmentService.save(appt);
        return Result.ok(appt);
    }

    @Operation(summary = "确认预约", description = "将预约状态更新为已确认")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "确认成功"),
            @ApiResponse(responseCode = "404", description = "预约不存在"),
            @ApiResponse(responseCode = "400", description = "状态转换非法")
    })
    @PutMapping("/{id}/confirm")
    public Result<Void> confirm(@Parameter(description = "预约ID", required = true, example = "1") @PathVariable String id) {
        return updateStatus(id, "confirmed");
    }

    @Operation(summary = "完成预约", description = "将预约状态更新为已完成")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "操作成功"),
            @ApiResponse(responseCode = "404", description = "预约不存在"),
            @ApiResponse(responseCode = "400", description = "状态转换非法")
    })
    @PutMapping("/{id}/complete")
    public Result<Void> complete(@Parameter(description = "预约ID", required = true, example = "1") @PathVariable String id) {
        return updateStatus(id, "completed");
    }

    @Operation(summary = "取消预约", description = "将预约状态更新为已取消")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "取消成功"),
            @ApiResponse(responseCode = "404", description = "预约不存在"),
            @ApiResponse(responseCode = "400", description = "状态转换非法")
    })
    @PutMapping("/{id}/cancel")
    public Result<Void> cancel(@Parameter(description = "预约ID", required = true, example = "1") @PathVariable String id) {
        return updateStatus(id, "cancelled");
    }

    @Operation(summary = "更新预约状态（通用）", description = "根据预约ID更新预约状态")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "更新成功"),
            @ApiResponse(responseCode = "404", description = "预约不存在"),
            @ApiResponse(responseCode = "400", description = "状态转换非法")
    })
    @PatchMapping("/{id}/status")
    public Result<Void> updateStatus(
            @Parameter(description = "预约ID", required = true, example = "1") @PathVariable String id,
            @Parameter(description = "新状态（pending/confirmed/completed/cancelled）", required = true, example = "confirmed") @RequestParam String status) {
        Appointment appt = appointmentService.getById(id);
        if (appt == null) {
            throw new BusinessException("预约不存在");
        }
        appointmentServiceImpl.validateTransition(appt.getStatus(), status);
        appt.setStatus(status);
        appointmentService.updateById(appt);
        return Result.ok();
    }

    @Operation(summary = "删除预约", description = "根据预约ID删除预约记录")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "删除成功"),
            @ApiResponse(responseCode = "404", description = "预约不存在")
    })
    @DeleteMapping("/{id}")
    public Result<Void> delete(@Parameter(description = "预约ID", required = true, example = "1") @PathVariable String id) {
        appointmentService.removeById(id);
        return Result.ok();
    }
}
