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
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@Tag(name = "预约管理")
@RestController
@RequestMapping(value = "/api/v1/appointments")
@RequiredArgsConstructor
public class AppointmentController {

    private final AppointmentService appointmentService;
    private final AppointmentServiceImpl appointmentServiceImpl;
    private final StoreAccessUtil storeAccess;
    private final MemberService memberService;

    @Operation(summary = "预约列表")
    @GetMapping
    public Result<IPage<AppointmentVO>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String status,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(appointmentService.page(page, size, storeId, status));
    }

    @Operation(summary = "创建预约")
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

    @Operation(summary = "确认预约")
    @PutMapping("/{id}/confirm")
    public Result<Void> confirm(@PathVariable String id) {
        return updateStatus(id, "confirmed");
    }

    @Operation(summary = "完成预约")
    @PutMapping("/{id}/complete")
    public Result<Void> complete(@PathVariable String id) {
        return updateStatus(id, "completed");
    }

    @Operation(summary = "取消预约")
    @PutMapping("/{id}/cancel")
    public Result<Void> cancel(@PathVariable String id) {
        return updateStatus(id, "cancelled");
    }

    @Operation(summary = "更新预约状态（通用）")
    @PatchMapping("/{id}/status")
    public Result<Void> updateStatus(@PathVariable String id, @RequestParam String status) {
        Appointment appt = appointmentService.getById(id);
        if (appt == null) {
            throw new BusinessException("预约不存在");
        }
        appointmentServiceImpl.validateTransition(appt.getStatus(), status);
        appt.setStatus(status);
        appointmentService.updateById(appt);
        return Result.ok();
    }

    @Operation(summary = "删除预约")
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable String id) {
        appointmentService.removeById(id);
        return Result.ok();
    }
}
