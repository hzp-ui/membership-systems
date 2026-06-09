package com.membership.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.membership.common.Result;
import com.membership.entity.Member;
import com.membership.security.StoreAccessUtil;
import com.membership.service.MemberService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@Tag(name = "会员管理", description = "会员信息的增删改查管理")
@RestController
@RequestMapping("/api/v1/members")
@RequiredArgsConstructor
public class MemberController {

    private final MemberService memberService;
    private final StoreAccessUtil storeAccess;

    @Operation(summary = "会员列表", description = "分页查询会员列表，支持按关键词搜索")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "查询成功", content = @Content(schema = @Schema(implementation = Member.class))),
            @ApiResponse(responseCode = "403", description = "无权限访问")
    })
    @GetMapping
    public Result<IPage<Member>> list(
            @Parameter(description = "页码", example = "1") @RequestParam(defaultValue = "1") int page,
            @Parameter(description = "每页大小", example = "20") @RequestParam(defaultValue = "20") int size,
            @Parameter(description = "搜索关键词（姓名/手机号）", example = "张三") @RequestParam(required = false) String keyword,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(memberService.page(page, size, keyword, storeId));
    }

    @Operation(summary = "会员详情", description = "根据会员ID获取会员详细信息")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "查询成功", content = @Content(schema = @Schema(implementation = Member.class))),
            @ApiResponse(responseCode = "404", description = "会员不存在"),
            @ApiResponse(responseCode = "403", description = "无权限访问")
    })
    @GetMapping("/{id}")
    public Result<Member> detail(@Parameter(description = "会员ID", required = true, example = "1") @PathVariable String id) {
        return Result.ok(memberService.getById(id));
    }

    @Operation(summary = "创建会员", description = "创建新会员，可设置会员基本信息")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "创建成功", content = @Content(schema = @Schema(implementation = Member.class))),
            @ApiResponse(responseCode = "400", description = "请求参数错误"),
            @ApiResponse(responseCode = "403", description = "无权限操作")
    })
    @PostMapping
    public Result<Member> create(@RequestBody Member member) {
        return Result.ok(memberService.create(member));
    }

    @Operation(summary = "更新会员", description = "根据会员ID更新会员信息")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "更新成功", content = @Content(schema = @Schema(implementation = Member.class))),
            @ApiResponse(responseCode = "404", description = "会员不存在"),
            @ApiResponse(responseCode = "400", description = "请求参数错误"),
            @ApiResponse(responseCode = "403", description = "无权限操作")
    })
    @PutMapping("/{id}")
    public Result<Member> update(
            @Parameter(description = "会员ID", required = true, example = "1") @PathVariable String id,
            @RequestBody Member member) {
        member.setId(id);
        return Result.ok(memberService.update(id, member));
    }

    @Operation(summary = "删除会员", description = "根据会员ID删除会员（逻辑删除）")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "删除成功"),
            @ApiResponse(responseCode = "404", description = "会员不存在"),
            @ApiResponse(responseCode = "403", description = "无权限操作")
    })
    @DeleteMapping("/{id}")
    public Result<Void> delete(@Parameter(description = "会员ID", required = true, example = "1") @PathVariable String id) {
        memberService.removeById(id);
        return Result.ok();
    }
}
