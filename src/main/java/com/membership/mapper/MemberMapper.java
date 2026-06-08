package com.membership.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.membership.entity.Member;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface MemberMapper extends BaseMapper<Member> {

    @Select("SELECT * FROM members WHERE id = #{id} FOR UPDATE")
    Member selectByIdForUpdate(@Param("id") String id);
}
