package com.membership.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.membership.common.Result;
import com.membership.entity.Member;
import com.membership.security.StoreAccessUtil;
import com.membership.service.MemberService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@Tag(name = "会员管理")
@RestController
@RequestMapping("/api/v1/members")
@RequiredArgsConstructor
public class MemberController {

    private final MemberService memberService;
    private final StoreAccessUtil storeAccess;

    @Operation(summary = "会员列表")
    @GetMapping
    public Result<IPage<Member>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String keyword,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(memberService.page(page, size, keyword, storeId));
    }

    @Operation(summary = "会员详情")
    @GetMapping("/{id}")
    public Result<Member> detail(@PathVariable String id) {
        return Result.ok(memberService.getById(id));
    }

    @Operation(summary = "创建会员")
    @PostMapping
    public Result<Member> create(@RequestBody Member member) {
        return Result.ok(memberService.create(member));
    }

    @Operation(summary = "更新会员")
    @PutMapping("/{id}")
    public Result<Member> update(@PathVariable String id, @RequestBody Member member) {
        member.setId(id);
        return Result.ok(memberService.update(id, member));
    }

    @Operation(summary = "删除会员")
    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable String id) {
        memberService.removeById(id);
        return Result.ok();
    }
}
