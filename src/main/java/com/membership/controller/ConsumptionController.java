package com.membership.controller;

import com.membership.common.Result;
import com.membership.dto.request.ConsumeRequest;
import com.membership.dto.response.ConsumptionRecordVO;
import com.membership.entity.ConsumptionRecord;
import com.membership.entity.Member;
import com.membership.security.StoreAccessUtil;
import com.membership.service.ConsumptionService;
import com.membership.service.MemberService;
import com.baomidou.mybatisplus.core.metadata.IPage;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@Tag(name = "消费记录")
@RestController
@RequestMapping(value = "/api/v1/consumptions")
@RequiredArgsConstructor
public class ConsumptionController {

    private final ConsumptionService consumptionService;
    private final StoreAccessUtil storeAccess;
    private final MemberService memberService;

    @Operation(summary = "会员消费（扣款）")
    @PostMapping
    public Result<ConsumptionRecord> consume(@Valid @RequestBody ConsumeRequest request,
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
        return Result.ok(consumptionService.consume(request, storeId, operatorId, operatorRole));
    }

    @Operation(summary = "会员消费记录")
    @GetMapping("/member/{memberId}")
    public Result<IPage<ConsumptionRecordVO>> listByMember(
            @PathVariable String memberId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(consumptionService.pageByMember(page, size, memberId, storeId));
    }

    @Operation(summary = "消费记录列表（通用分页）")
    @GetMapping
    public Result<IPage<ConsumptionRecordVO>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String memberId,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(consumptionService.page(page, size, storeId, memberId));
    }
}
