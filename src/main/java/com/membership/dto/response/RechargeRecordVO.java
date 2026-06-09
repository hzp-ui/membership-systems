package com.membership.dto.response;

import com.membership.entity.RechargeRecord;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Schema(description = "充值记录视图对象（含会员名称）")
public class RechargeRecordVO {
    @Schema(description = "记录ID", example = "rech_001")
    private String id;

    @Schema(description = "会员ID", example = "mem_001")
    private String memberId;

    @Schema(description = "会员姓名", example = "张三")
    private String memberName;

    @Schema(description = "会员手机号", example = "13800138000")
    private String memberPhone;

    @Schema(description = "充值金额", example = "500.00")
    private BigDecimal amount;

    @Schema(description = "赠送金额", example = "50.00")
    private BigDecimal bonus;

    @Schema(description = "套餐名称", example = "充值500送50")
    private String packageName;

    @Schema(description = "所属门店ID", example = "store-001")
    private String storeId;

    @Schema(description = "创建时间")
    private LocalDateTime createdAt;

    public static RechargeRecordVO fromEntity(RechargeRecord record) {
        RechargeRecordVO vo = new RechargeRecordVO();
        vo.setId(record.getId());
        vo.setMemberId(record.getMemberId());
        vo.setAmount(record.getAmount());
        vo.setBonus(record.getBonus());
        vo.setPackageName(record.getPackageName());
        vo.setStoreId(record.getStoreId());
        vo.setCreatedAt(record.getCreatedAt());
        return vo;
    }
}
