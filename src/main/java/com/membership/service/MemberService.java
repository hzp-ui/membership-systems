package com.membership.service;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.service.IService;
import com.membership.entity.Member;

public interface MemberService extends IService<Member> {
    IPage<Member> page(int pageNum, int pageSize, String keyword, String storeId);
    Member create(Member member);
    Member update(String id, Member member);
}
