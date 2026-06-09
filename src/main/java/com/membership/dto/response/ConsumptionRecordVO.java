package com.membership.dto.response;

import com.membership.entity.ConsumptionRecord;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Schema(description = "消费记录视图对象（含会员/理发师/服务名称）")
public class ConsumptionRecordVO {
    @Schema(description = "记录ID", example = "cons_001")
    private String id;

    @Schema(description = "会员ID", example = "mem_001")
    private String memberId;

    @Schema(description = "会员姓名", example = "张三")
    private String memberName;

    @Schema(description = "会员手机号", example = "13800138000")
    private String memberPhone;

    @Schema(description = "消费金额", example = "150.00")
    private BigDecimal amount;

    @Schema(description = "原价", example = "200.00")
    private BigDecimal originalPrice;

    @Schema(description = "折扣", example = "0.75")
    private BigDecimal discount;

    @Schema(description = "获得积分", example = "15")
    private Integer pointsEarned;

    @Schema(description = "服务名称", example = "洗剪吹")
    private String serviceName;

    @Schema(description = "理发师姓名", example = "李四")
    private String barberName;

    @Schema(description = "所属门店ID", example = "store-001")
    private String storeId;

    @Schema(description = "创建时间")
    private LocalDateTime createdAt;

    public static ConsumptionRecordVO fromEntity(ConsumptionRecord record) {
        ConsumptionRecordVO vo = new ConsumptionRecordVO();
        vo.setId(record.getId());
        vo.setMemberId(record.getMemberId());
        vo.setAmount(record.getAmount());
        vo.setOriginalPrice(record.getOriginalPrice());
        vo.setDiscount(record.getDiscount());
        vo.setPointsEarned(record.getPointsEarned());
        vo.setServiceName(record.getServiceName());
        vo.setBarberName(record.getBarberName());
        vo.setStoreId(record.getStoreId());
        vo.setCreatedAt(record.getCreatedAt());
        return vo;
    }
}
