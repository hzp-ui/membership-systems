package com.membership.enums;

import lombok.Getter;

@Getter
public enum Status {
    ACTIVE("active", "启用"),
    INACTIVE("inactive", "停用");

    private final String value;
    private final String label;

    Status(String value, String label) {
        this.value = value;
        this.label = label;
    }
}
