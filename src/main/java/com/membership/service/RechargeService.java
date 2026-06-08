package com.membership.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.service.IService;
import com.membership.dto.request.RechargeRequest;
import com.membership.dto.response.RechargeRecordVO;
import com.membership.entity.Member;
import com.membership.entity.RechargeRecord;

import java.math.BigDecimal;

public interface RechargeService extends IService<RechargeRecord> {
    RechargeRecord recharge(RechargeRequest request, String storeId, String operatorId, String operatorRole);
    IPage<RechargeRecordVO> pageByMember(int pageNum, int pageSize, String memberId, String storeId);
    IPage<RechargeRecordVO> page(int pageNum, int pageSize, String storeId, String memberId);
}
