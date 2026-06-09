package com.membership.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.membership.common.Result;
import com.membership.dto.request.RechargeRequest;
import com.membership.dto.response.RechargeRecordVO;
import com.membership.entity.Member;
import com.membership.entity.RechargeRecord;
import com.membership.security.StoreAccessUtil;
import com.membership.service.MemberService;
import com.membership.service.RechargeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@Tag(name = "充值记录", description = "会员充值记录管理")
@RestController
@RequestMapping(value = "/api/v1/recharges")
@RequiredArgsConstructor
public class RechargeController {

    private final RechargeService rechargeService;
    private final StoreAccessUtil storeAccess;
    private final MemberService memberService;

    @Operation(summary = "会员充值", description = "为会员账户充值金额")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "充值成功", content = @Content(schema = @Schema(implementation = RechargeRecord.class))),
            @ApiResponse(responseCode = "400", description = "请求参数错误"),
            @ApiResponse(responseCode = "404", description = "会员不存在"),
            @ApiResponse(responseCode = "403", description = "无权限操作")
    })
    @PostMapping
    public Result<RechargeRecord> recharge(@Valid @RequestBody RechargeRequest request,
                                            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        // super_admin 没指定门店时，用会员所属门店
        if (storeId == null && request.getMemberId() != null) {
            Member member = memberService.getById(request.getMemberId());
            if (member != null) {
                storeId = member.getStoreId();
            }
        }
        String operatorId = auth.getName();
        String operatorRole = auth.getAuthorities().iterator().next().getAuthority().replace("ROLE_", "").toLowerCase();
        return Result.ok(rechargeService.recharge(request, storeId, operatorId, operatorRole));
    }

    @Operation(summary = "会员充值记录", description = "分页查询指定会员的充值记录")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "查询成功", content = @Content(schema = @Schema(implementation = RechargeRecordVO.class))),
            @ApiResponse(responseCode = "403", description = "无权限访问")
    })
    @GetMapping("/member/{memberId}")
    public Result<IPage<RechargeRecordVO>> listByMember(
            @Parameter(description = "会员ID", required = true, example = "1") @PathVariable String memberId,
            @Parameter(description = "页码", example = "1") @RequestParam(defaultValue = "1") int page,
            @Parameter(description = "每页大小", example = "20") @RequestParam(defaultValue = "20") int size,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(rechargeService.pageByMember(page, size, memberId, storeId));
    }

    @Operation(summary = "充值记录列表（通用分页）", description = "分页查询充值记录列表，可按会员ID筛选")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "查询成功", content = @Content(schema = @Schema(implementation = RechargeRecordVO.class))),
            @ApiResponse(responseCode = "403", description = "无权限访问")
    })
    @GetMapping
    public Result<IPage<RechargeRecordVO>> list(
            @Parameter(description = "页码", example = "1") @RequestParam(defaultValue = "1") int page,
            @Parameter(description = "每页大小", example = "20") @RequestParam(defaultValue = "20") int size,
            @Parameter(description = "会员ID（可选）", example = "1") @RequestParam(required = false) String memberId,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(rechargeService.page(page, size, storeId, memberId));
    }
}
