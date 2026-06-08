package com.membership.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.service.IService;
import com.membership.dto.request.ConsumeRequest;
import com.membership.dto.response.ConsumptionRecordVO;
import com.membership.entity.ConsumptionRecord;

public interface ConsumptionService extends IService<ConsumptionRecord> {
    ConsumptionRecord consume(ConsumeRequest request, String storeId, String operatorId, String operatorRole);
    IPage<ConsumptionRecordVO> pageByMember(int pageNum, int pageSize, String memberId, String storeId);
    IPage<ConsumptionRecordVO> page(int pageNum, int pageSize, String storeId, String memberId);
}
