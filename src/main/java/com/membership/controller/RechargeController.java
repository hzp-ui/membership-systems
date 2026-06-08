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
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@Tag(name = "充值记录")
@RestController
@RequestMapping(value = "/api/v1/recharges")
@RequiredArgsConstructor
public class RechargeController {

    private final RechargeService rechargeService;
    private final StoreAccessUtil storeAccess;
    private final MemberService memberService;

    @Operation(summary = "会员充值")
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

    @Operation(summary = "会员充值记录")
    @GetMapping("/member/{memberId}")
    public Result<IPage<RechargeRecordVO>> listByMember(
            @PathVariable String memberId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(rechargeService.pageByMember(page, size, memberId, storeId));
    }

    @Operation(summary = "充值记录列表（通用分页）")
    @GetMapping
    public Result<IPage<RechargeRecordVO>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String memberId,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(rechargeService.page(page, size, storeId, memberId));
    }
}
