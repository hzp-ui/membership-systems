package com.membership.dto.response;

import com.membership.entity.Appointment;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Schema(description = "预约视图对象（含会员/理发师/服务名称）")
public class AppointmentVO {
    @Schema(description = "预约ID", example = "apt_001")
    private String id;

    @Schema(description = "会员ID", example = "mem_001")
    private String memberId;

    @Schema(description = "会员姓名", example = "张三")
    private String memberName;

    @Schema(description = "会员手机号", example = "13800138000")
    private String memberPhone;

    @Schema(description = "理发师ID", example = "barber_001")
    private String barberId;

    @Schema(description = "理发师姓名", example = "李四")
    private String barberName;

    @Schema(description = "服务ID", example = "svc_001")
    private String serviceId;

    @Schema(description = "服务名称", example = "洗剪吹")
    private String serviceName;

    @Schema(description = "预约时间", example = "2026-06-15T14:00:00")
    private LocalDateTime appointmentTime;

    @Schema(description = "预约状态：pending/confirmed/completed/cancelled", example = "pending")
    private String status;

    @Schema(description = "所属门店ID", example = "store-001")
    private String storeId;

    @Schema(description = "创建时间")
    private LocalDateTime createdAt;

    public static AppointmentVO fromEntity(Appointment appointment) {
        AppointmentVO vo = new AppointmentVO();
        vo.setId(appointment.getId());
        vo.setMemberId(appointment.getMemberId());
        vo.setBarberId(appointment.getBarberId());
        vo.setServiceId(appointment.getServiceId());
        vo.setAppointmentTime(appointment.getAppointmentTime());
        vo.setStatus(appointment.getStatus());
        vo.setStoreId(appointment.getStoreId());
        vo.setCreatedAt(appointment.getCreatedAt());
        return vo;
    }
}
