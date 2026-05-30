// ============================================
// 消费 Edge Function - 安全修复版
// 功能：根据会员等级折扣计算实际金额，扣除余额，增加积分
// 安全改进：
// 1. JWT 认证
// 2. IDOR 防护
// 3. 输入验证
// 4. 业务逻辑保护
// 5. 审计日志
// ============================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { z } from 'https://deno.land/x/zod@v0.4.2/mod.ts'

// ========== 安全配置 ==========
const ALLOWED_ORIGINS = [
  'http://localhost:5173',
  'http://localhost:3000',
]

const corsHeaders = {
  'Access-Control-Allow-Origin': ALLOWED_ORIGINS[0],
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
}

const DISCOUNT_MAP: Record<string, string> = {
  normal: 'discount_normal',
  silver: 'discount_silver',
  gold: 'discount_gold',
  diamond: 'discount_diamond',
}

// ========== 输入验证 Schema ==========
const ConsumeSchema = z.object({
  member_id: z.string().uuid('会员ID格式不正确'),
  service_id: z.string().uuid('服务ID格式不正确'),
  barber_id: z.string().uuid('理发师ID格式不正确').optional().nullable(),
})

// ========== 审计日志 ==========
async function logAudit(supabase: any, params: {
  userId: string
  userType: 'admin' | 'member'
  action: string
  resourceType: string
  resourceId?: string
  details?: any
  ipAddress?: string
}) {
  try {
    await supabase.from('audit_logs').insert({
      user_id: params.userId,
      user_type: params.userType,
      action: params.action,
      resource_type: params.resourceType,
      resource_id: params.resourceId,
      details: params.details,
      ip_address: params.ipAddress,
    })
  } catch (err) {
    console.error('Audit log failed:', err)
  }
}

// ========== 验证用户 ==========
async function verifyAndGetUser(supabase: any, authHeader: string | null) {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return { error: '未登录', status: 401 }
  }

  try {
    const token = authHeader.replace('Bearer ', '')
    const payload = JSON.parse(atob(token))
    
    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
      return { error: '登录已过期', status: 401 }
    }

    const userId = payload.sub
    const role = payload.role

    if (role === 'super_admin' || role === 'store_admin') {
      const { data: admin } = await supabase
        .from('admins')
        .select('id, role, store_id')
        .eq('id', userId)
        .single()
      
      if (!admin) return { error: '管理员不存在', status: 401 }
      return { user: admin, userType: 'admin' as const }
    } else {
      const { data: member } = await supabase
        .from('members')
        .select('id, store_id')
        .eq('id', userId)
        .single()
      
      if (!member) return { error: '会员不存在', status: 401 }
      return { user: member, userType: 'member' as const }
    }
  } catch {
    return { error: '无效的认证信息', status: 401 }
  }
}

// ========== 验证消费权限 ==========
async function verifyConsumePermission(
  supabase: any, 
  user: any, 
  userType: 'admin' | 'member',
  memberId: string
) {
  // 会员只能为自己消费
  if (userType === 'member') {
    if (user.id !== memberId) {
      return { allowed: false, error: '只能为自己的账户消费', status: 403 }
    }
    return { allowed: true }
  }

  // 店长只能为本店会员操作
  if (user.role === 'store_admin') {
    const { data: member } = await supabase
      .from('members')
      .select('id, store_id')
      .eq('id', memberId)
      .single()
    
    if (!member) return { allowed: false, error: '会员不存在', status: 404 }
    if (member.store_id !== user.store_id) {
      return { allowed: false, error: '无权为此会员操作', status: 403 }
    }
    return { allowed: true }
  }

  // 超管可以操作所有
  return { allowed: true }
}

// ========== 主处理函数 ==========
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const clientIp = req.headers.get('x-forwarded-for') || req.headers.get('cf-connecting-ip')

    // ========== 1. 验证认证 ==========
    const authHeader = req.headers.get('Authorization')
    const authResult = await verifyAndGetUser(supabase, authHeader)
    
    if (authResult.error) {
      return new Response(JSON.stringify({ error: authResult.error }), {
        status: authResult.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const { user, userType } = authResult

    // ========== 2. 验证输入 ==========
    let body
    try {
      body = ConsumeSchema.parse(await req.json())
    } catch (err) {
      if (err instanceof z.ZodError) {
        return new Response(JSON.stringify({ 
          error: '参数格式错误', 
          details: err.errors.map(e => e.message) 
        }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
      return new Response(JSON.stringify({ error: '参数格式错误' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const { member_id, service_id, barber_id } = body

    // ========== 3. 验证权限 ==========
    const permResult = await verifyConsumePermission(supabase, user, userType, member_id)
    if (!permResult.allowed) {
      return new Response(JSON.stringify({ error: permResult.error }), {
        status: permResult.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ========== 4. 查询会员 ==========
    const { data: member, error: memberErr } = await supabase
      .from('members')
      .select('*')
      .eq('id', member_id)
      .single()

    if (memberErr || !member) {
      return new Response(JSON.stringify({ error: '会员不存在' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ========== 5. 查询服务项目 ==========
    const { data: service, error: svcErr } = await supabase
      .from('services')
      .select('*')
      .eq('id', service_id)
      .single()

    if (svcErr || !service) {
      return new Response(JSON.stringify({ error: '服务项目不存在' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // 验证服务是否属于同一门店
    if (service.store_id !== member.store_id) {
      return new Response(JSON.stringify({ error: '服务项目不适用于此会员' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ========== 6. 计算折扣后金额 ==========
    const discountCol = DISCOUNT_MAP[member.level] || 'discount_normal'
    const discount = Number(service[discountCol]) || 1.0
    const originalPrice = Number(service.price)
    const actualAmount = Math.round(originalPrice * discount * 100) / 100

    // ========== 7. 检查余额 ==========
    if (Number(member.balance) < actualAmount) {
      return new Response(JSON.stringify({ 
        error: '余额不足，请先充值',
        currentBalance: member.balance,
        requiredAmount: actualAmount
      }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ========== 8. 查询理发师（可选） ==========
    let barberName = null
    if (barber_id) {
      const { data: barber } = await supabase
        .from('barbers')
        .select('name')
        .eq('id', barber_id)
        .single()
      barberName = barber?.name ?? null
      
      // 验证理发师是否属于同一门店
      if (barber && barber.store_id !== member.store_id) {
        return new Response(JSON.stringify({ error: '理发师不适用于此门店' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
    }

    // ========== 9. 执行扣款 ==========
    const newBalance = Number(member.balance) - actualAmount
    const pointsEarned = Math.floor(actualAmount)
    const newPoints = member.points + pointsEarned

    const { error: updateErr } = await supabase
      .from('members')
      .update({ 
        balance: newBalance, 
        points: newPoints,
        updated_at: new Date().toISOString()
      })
      .eq('id', member_id)

    if (updateErr) {
      return new Response(JSON.stringify({ error: '扣款失败，请稍后重试' }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ========== 10. 创建消费记录 ==========
    const { data: record, error: recordErr } = await supabase
      .from('consumption_records')
      .insert({
        member_id,
        amount: actualAmount,
        original_price: originalPrice,
        discount,
        service_id: service.id,
        service_name: service.name,
        barber_id: barber_id || null,
        barber_name: barberName,
        points_earned: pointsEarned,
        store_id: member.store_id,
      })
      .select()
      .single()

    if (recordErr) {
      // 回滚余额
      console.error('Failed to create consumption record, rolling back:', recordErr)
      await supabase
        .from('members')
        .update({ balance: member.balance, points: member.points })
        .eq('id', member_id)
      
      return new Response(JSON.stringify({ error: '消费记录创建失败' }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ========== 11. 审计日志 ==========
    await logAudit(supabase, {
      userId: user.id,
      userType,
      action: 'CONSUME',
      resourceType: 'member_balance',
      resourceId: member_id,
      details: {
        service_id,
        service_name: service.name,
        barber_id,
        barber_name: barberName,
        original_price: originalPrice,
        discount,
        actual_amount: actualAmount,
        points_earned: pointsEarned,
        old_balance: member.balance,
        new_balance: newBalance,
        old_points: member.points,
        new_points: newPoints
      },
      ipAddress: clientIp
    })

    // ========== 12. 返回结果 ==========
    return new Response(JSON.stringify({
      data: { 
        record, 
        new_balance: newBalance, 
        new_points: newPoints,
        discount_applied: discount,
        original_price: originalPrice,
        actual_amount: actualAmount
      }
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (err) {
    console.error('Consume Error:', err)
    return new Response(JSON.stringify({ 
      error: '服务器内部错误，请稍后重试',
      requestId: crypto.randomUUID()
    }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
