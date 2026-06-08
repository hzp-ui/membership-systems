package com.membership.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import com.membership.common.BusinessException;
import com.membership.entity.Member;
import com.membership.mapper.MemberMapper;
import com.membership.service.MemberService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

@Service
@RequiredArgsConstructor
public class MemberServiceImpl extends ServiceImpl<MemberMapper, Member> implements MemberService {

    private final PasswordEncoder passwordEncoder;

    @Override
    public IPage<Member> page(int pageNum, int pageSize, String keyword, String storeId) {
        LambdaQueryWrapper<Member> wrapper = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(keyword)) {
            wrapper.and(w -> w.like(Member::getName, keyword)
                    .or().like(Member::getPhone, keyword));
        }
        if (StringUtils.hasText(storeId)) {
            wrapper.eq(Member::getStoreId, storeId);
        }
        wrapper.orderByDesc(Member::getCreatedAt);
        return baseMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
    }

    @Override
    public Member create(Member member) {
        // Check phone uniqueness within the same store (same phone allowed across stores)
        Long count = lambdaQuery()
                .eq(Member::getPhone, member.getPhone())
                .eq(member.getStoreId() != null, Member::getStoreId, member.getStoreId())
                .count();
        if (count > 0) {
            throw new BusinessException("该门店已存在此手机号的会员");
        }
        if (StringUtils.hasText(member.getPasswordHash())) {
            member.setPasswordHash(passwordEncoder.encode(member.getPasswordHash()));
        }
        save(member);
        return member;
    }

    @Override
    public Member update(String id, Member member) {
        Member existing = getById(id);
        if (existing == null) {
            throw new BusinessException("会员不存在");
        }
        member.setId(id);
        // Don't update password through this method
        member.setPasswordHash(null);
        updateById(member);
        return getById(id);
    }
}
