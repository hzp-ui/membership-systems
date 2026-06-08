package com.membership.enums;

import lombok.Getter;

@Getter
public enum AppointmentStatus {
    PENDING("pending", "待确认"),
    CONFIRMED("confirmed", "已确认"),
    COMPLETED("completed", "已完成"),
    CANCELLED("cancelled", "已取消");

    private final String value;
    private final String label;

    AppointmentStatus(String value, String label) {
        this.value = value;
        this.label = label;
    }
}
