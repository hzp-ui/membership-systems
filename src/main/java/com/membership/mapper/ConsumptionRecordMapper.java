package com.membership.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.membership.entity.ConsumptionRecord;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Mapper
public interface ConsumptionRecordMapper extends BaseMapper<ConsumptionRecord> {

    @Select("<script>" +
            "SELECT COALESCE(SUM(amount), 0) FROM consumption_records " +
            "WHERE created_at &gt;= #{since}" +
            "<if test='storeId != null'> AND store_id = #{storeId}</if>" +
            "</script>")
    BigDecimal sumAmountSince(@Param("since") LocalDateTime since, @Param("storeId") String storeId);
}
