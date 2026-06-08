package com.membership.dto.response;

import com.membership.entity.Appointment;
import lombok.Data;
import java.time.LocalDateTime;

@Data
public class AppointmentVO {
    private String id;
    private String memberId;
    private String memberName;
    private String memberPhone;
    private String barberId;
    private String barberName;
    private String serviceId;
    private String serviceName;
    private LocalDateTime appointmentTime;
    private String status;
    private String storeId;
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
