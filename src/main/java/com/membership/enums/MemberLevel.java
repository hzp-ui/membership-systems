package com.membership.enums;

import lombok.Getter;

@Getter
public enum MemberLevel {
    NORMAL("normal", "普通会员"),
    SILVER("silver", "银卡会员"),
    GOLD("gold", "金卡会员"),
    DIAMOND("diamond", "钻石会员");

    private final String value;
    private final String label;

    MemberLevel(String value, String label) {
        this.value = value;
        this.label = label;
    }
}
