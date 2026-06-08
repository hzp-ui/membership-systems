package com.membership.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import java.time.LocalDateTime;

@Data
public class CreateAppointmentRequest {
    @NotBlank(message = "memberId is required")
    private String memberId;
    @NotBlank(message = "barberId is required")
    private String barberId;
    private String serviceId;
    @NotNull(message = "appointmentTime is required")
    private LocalDateTime appointmentTime;
    private String storeId;
}
