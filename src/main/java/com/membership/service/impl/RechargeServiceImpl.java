package com.membership.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.membership.common.BusinessException;
import com.membership.dto.request.RechargeRequest;
import com.membership.dto.response.RechargeRecordVO;
import com.membership.entity.Member;
import com.membership.entity.RechargePackage;
import com.membership.entity.RechargeRecord;
import com.membership.mapper.MemberMapper;
import com.membership.mapper.PackageMapper;
import com.membership.mapper.RechargeRecordMapper;
import com.membership.service.AuditLogService;
import com.membership.service.RechargeService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class RechargeServiceImpl extends ServiceImpl<RechargeRecordMapper, RechargeRecord>
        implements RechargeService {

    private final MemberMapper memberMapper;
    private final AuditLogService auditLogService;
    private final PackageMapper packageMapper;

    /**
     * 充值原子操作：加余额 + 加积分（1元=1积分）。
     *
     * - 套餐充值：request 包含 packageId，后端自动查金额
     * - 自定义充值：request 包含 amount（bonus 可选）
     */
    @Override
    @Transactional
    public RechargeRecord recharge(RechargeRequest request, String storeId, String operatorId, String operatorRole) {
        // 1. 解析充值金额（套餐充值 or 自定义充值）
        BigDecimal amount;
        BigDecimal bonus;
        String packageName = null;

        if (request.getPackageId() != null && !request.getPackageId().isEmpty()) {
            // 套餐充值：根据 packageId 查数据库
            RechargePackage pkg = packageMapper.selectById(request.getPackageId());
            if (pkg == null) {
                throw new BusinessException("充值套餐不存在");
            }
            amount = pkg.getAmount();
            bonus = pkg.getBonus() != null ? pkg.getBonus() : BigDecimal.ZERO;
            packageName = pkg.getName();
        } else if (request.getAmount() != null) {
            // 自定义充值
            amount = request.getAmount();
            bonus = request.getBonus() != null ? request.getBonus() : BigDecimal.ZERO;
            packageName = request.getPackageName(); // 前端可能传自定义套餐名
        } else {
            throw new BusinessException("请指定充值金额或选择充值套餐");
        }

        // 2. 悲观锁锁定会员
        Member member = memberMapper.selectByIdForUpdate(request.getMemberId());
        if (member == null) {
            throw new BusinessException("会员不存在");
        }

        // 3. 加余额
        member.setBalance(member.getBalance().add(amount).add(bonus));
        // 4. 加积分：每充值1元=1积分
        int pointsEarned = amount.intValue();
        member.setPoints(member.getPoints() + pointsEarned);
        memberMapper.updateById(member);

        // 5. 插入充值记录
        RechargeRecord record = new RechargeRecord();
        record.setMemberId(request.getMemberId());
        record.setAmount(amount);
        record.setBonus(bonus);
        record.setPackageName(packageName);
        record.setStoreId(storeId);
        save(record);

        // 6. 审计日志
        auditLogService.log(operatorId, operatorRole, "RECHARGE", "member", request.getMemberId(),
                "充值" + amount + "元，赠送" + bonus + "元", storeId);

        return record;
    }

    @Override
    public IPage<RechargeRecordVO> pageByMember(int pageNum, int pageSize, String memberId, String storeId) {
        LambdaQueryWrapper<RechargeRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(RechargeRecord::getMemberId, memberId);
        if (storeId != null) {
            wrapper.eq(RechargeRecord::getStoreId, storeId);
        }
        wrapper.orderByDesc(RechargeRecord::getCreatedAt);
        IPage<RechargeRecord> page = baseMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
        return enrichWithMemberInfo(page);
    }

    @Override
    public IPage<RechargeRecordVO> page(int pageNum, int pageSize, String storeId, String memberId) {
        LambdaQueryWrapper<RechargeRecord> wrapper = new LambdaQueryWrapper<>();
        if (storeId != null) {
            wrapper.eq(RechargeRecord::getStoreId, storeId);
        }
        if (memberId != null) {
            wrapper.eq(RechargeRecord::getMemberId, memberId);
        }
        wrapper.orderByDesc(RechargeRecord::getCreatedAt);
        IPage<RechargeRecord> page = baseMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
        return enrichWithMemberInfo(page);
    }
    
    private IPage<RechargeRecordVO> enrichWithMemberInfo(IPage<RechargeRecord> page) {
        List<RechargeRecordVO> voList = page.getRecords().stream()
                .map(RechargeRecordVO::fromEntity)
                .collect(Collectors.toList());
        
        Set<String> memberIds = voList.stream()
                .map(RechargeRecordVO::getMemberId)
                .collect(Collectors.toSet());
        
        if (!memberIds.isEmpty()) {
            List<Member> members = memberMapper.selectBatchIds(memberIds);
            Map<String, Member> memberMap = members.stream()
                    .collect(Collectors.toMap(Member::getId, m -> m));
            
            voList.forEach(vo -> {
                Member member = memberMap.get(vo.getMemberId());
                if (member != null) {
                    vo.setMemberName(member.getName());
                    vo.setMemberPhone(member.getPhone());
                }
            });
        }
        
        Page<RechargeRecordVO> resultPage = new Page<>(page.getCurrent(), page.getSize(), page.getTotal());
        resultPage.setRecords(voList);
        return resultPage;
    }
}
