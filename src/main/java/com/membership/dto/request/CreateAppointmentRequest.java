package com.membership.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Schema(description = "创建预约请求")
public class CreateAppointmentRequest {
    @Schema(description = "会员ID", example = "mem_001")
    @NotBlank(message = "memberId is required")
    private String memberId;

    @Schema(description = "理发师ID", example = "barber_001")
    @NotBlank(message = "barberId is required")
    private String barberId;

    @Schema(description = "服务ID（可选）")
    private String serviceId;

    @Schema(description = "预约时间，ISO格式", example = "2026-06-15T14:00:00")
    @NotNull(message = "appointmentTime is required")
    private LocalDateTime appointmentTime;

    @Schema(description = "门店ID（可选，不填则使用会员所属门店）")
    private String storeId;
}
