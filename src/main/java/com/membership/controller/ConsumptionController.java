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

@Tag(name = "消费记录", description = "会员消费记录管理")
@RestController
@RequestMapping(value = "/api/v1/consumptions")
@RequiredArgsConstructor
public class ConsumptionController {

    private final ConsumptionService consumptionService;
    private final StoreAccessUtil storeAccess;
    private final MemberService memberService;

    @Operation(summary = "会员消费（扣款）", description = "记录会员消费并扣除相应金额")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "消费成功", content = @Content(schema = @Schema(implementation = ConsumptionRecord.class))),
            @ApiResponse(responseCode = "400", description = "请求参数错误"),
            @ApiResponse(responseCode = "404", description = "会员不存在"),
            @ApiResponse(responseCode = "402", description = "余额不足"),
            @ApiResponse(responseCode = "403", description = "无权限操作")
    })
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

    @Operation(summary = "会员消费记录", description = "分页查询指定会员的消费记录")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "查询成功", content = @Content(schema = @Schema(implementation = ConsumptionRecordVO.class))),
            @ApiResponse(responseCode = "403", description = "无权限访问")
    })
    @GetMapping("/member/{memberId}")
    public Result<IPage<ConsumptionRecordVO>> listByMember(
            @Parameter(description = "会员ID", required = true, example = "1") @PathVariable String memberId,
            @Parameter(description = "页码", example = "1") @RequestParam(defaultValue = "1") int page,
            @Parameter(description = "每页大小", example = "20") @RequestParam(defaultValue = "20") int size,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(consumptionService.pageByMember(page, size, memberId, storeId));
    }

    @Operation(summary = "消费记录列表（通用分页）", description = "分页查询消费记录列表，可按会员ID筛选")
    @ApiResponses(value = {
            @ApiResponse(responseCode = "200", description = "查询成功", content = @Content(schema = @Schema(implementation = ConsumptionRecordVO.class))),
            @ApiResponse(responseCode = "403", description = "无权限访问")
    })
    @GetMapping
    public Result<IPage<ConsumptionRecordVO>> list(
            @Parameter(description = "页码", example = "1") @RequestParam(defaultValue = "1") int page,
            @Parameter(description = "每页大小", example = "20") @RequestParam(defaultValue = "20") int size,
            @Parameter(description = "会员ID（可选）", example = "1") @RequestParam(required = false) String memberId,
            Authentication auth) {
        String storeId = storeAccess.resolveStoreId(auth);
        return Result.ok(consumptionService.page(page, size, storeId, memberId));
    }
}
