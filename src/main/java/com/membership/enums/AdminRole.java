package com.membership.enums;

import lombok.Getter;

@Getter
public enum AdminRole {
    SUPER_ADMIN("super_admin", "超级管理员"),
    STORE_ADMIN("store_admin", "店长");

    private final String value;
    private final String label;

    AdminRole(String value, String label) {
        this.value = value;
        this.label = label;
    }
}
