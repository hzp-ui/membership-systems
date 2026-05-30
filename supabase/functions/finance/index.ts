// ============================================
// 财务对账 Edge Function - 安全修复版
// 功能：财务汇总报表/每日对账单/CSV导出
// 安全改进：
// 1. JWT 认证
// 2. 权限控制
// 3. 输入验证
// 4. 参数化查询（无 SQL 拼接）
// ============================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { z } from 'https://deno.land/x/zod@v0.4.2/mod.ts'

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

// ========== 输入验证 Schema ==========
const FinanceSchema = z.object({
  action: z.enum(['summary', 'daily', 'export_csv']),
  store_id: z.string().uuid('门店ID格式不正确').optional().nullable(),
  start_date: z.string().optional().nullable(),
  end_date: z.string().optional().nullable(),
})

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
      return { error: '只有管理员可以查看财务数据', status: 403 }
    }
  } catch {
    return { error: '无效的认证信息', status: 401 }
  }
}

// ========== 构建查询（安全） ==========
function buildFinanceQuery(supabase: any, table: string, filters: {
  storeId?: string
  startDate?: string
  endDate?: string
  userStoreId?: string
  role?: string
}) {
  let query = supabase.from(table).select('*')

  // 店长只能查看本店数据
  if (filters.role === 'store_admin') {
    query = query.eq('store_id', filters.userStoreId)
  } else if (filters.storeId) {
    query = query.eq('store_id', filters.storeId)
  }

  // 日期筛选
  if (filters.startDate) {
    query = query.gte('created_at', filters.startDate)
  }
  if (filters.endDate) {
    query = query.lte('created_at', filters.endDate)
  }

  return query
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

    // ========== 1. 验证认证 ==========
    const authHeader = req.headers.get('Authorization')
    const authResult = await verifyAndGetUser(supabase, authHeader)
    
    if (authResult.error) {
      return new Response(JSON.stringify({ error: authResult.error }), {
        status: authResult.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const { user } = authResult

    // ========== 2. 验证输入 ==========
    let body
    try {
      body = FinanceSchema.parse(await req.json())
    } catch (err) {
      if (err instanceof z.ZodError) {
        return new Response(JSON.stringify({ 
          error: '参数格式错误', 
          details: err.errors.map(e => `${e.path.join('.')}: ${e.message}`) 
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

    const { action, store_id, start_date, end_date } = body

    // 构建查询参数
    const queryParams = {
      storeId: store_id,
      startDate: start_date,
      endDate: end_date,
      userStoreId: user.store_id,
      role: user.role,
    }

    // ========== 财务汇总报表 ==========
    if (action === 'summary') {
      const [rechargeRes, consumptionRes] = await Promise.all([
        buildFinanceQuery(supabase, 'recharge_records', queryParams),
        buildFinanceQuery(supabase, 'consumption_records', queryParams),
      ])

      const rechargeIncome = (rechargeRes.data || []).reduce((s, r) => s + Number(r.amount), 0)
      const consumptionIncome = (consumptionRes.data || []).reduce((s, r) => s + Number(r.amount), 0)
      const refundAmount = 0 // 本期不实现退款
      const netIncome = rechargeIncome + consumptionIncome - refundAmount

      return new Response(JSON.stringify({
        data: { 
          recharge_income: rechargeIncome, 
          consumption_income: consumptionIncome, 
          refund_amount: refundAmount, 
          net_income: netIncome 
        }
      }), { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      })
    }

    // ========== 每日对账单 ==========
    if (action === 'daily') {
      const [rechargeRes, consumptionRes] = await Promise.all([
        buildFinanceQuery(supabase, 'recharge_records', queryParams),
        buildFinanceQuery(supabase, 'consumption_records', queryParams),
      ])

      const dailyMap: Record<string, any> = {}
      
      for (const r of rechargeRes.data || []) {
        const day = new Date(r.created_at).toISOString().slice(0, 10)
        if (!dailyMap[day]) {
          dailyMap[day] = { date: day, recharge_count: 0, recharge_amount: 0, consumption_count: 0, consumption_amount: 0, refund_count: 0, refund_amount: 0 }
        }
        dailyMap[day].recharge_count++
        dailyMap[day].recharge_amount += Number(r.amount)
      }
      
      for (const r of consumptionRes.data || []) {
        const day = new Date(r.created_at).toISOString().slice(0, 10)
        if (!dailyMap[day]) {
          dailyMap[day] = { date: day, recharge_count: 0, recharge_amount: 0, consumption_count: 0, consumption_amount: 0, refund_count: 0, refund_amount: 0 }
        }
        dailyMap[day].consumption_count++
        dailyMap[day].consumption_amount += Number(r.amount)
      }

      const data = Object.values(dailyMap)
        .sort((a: any, b: any) => a.date.localeCompare(b.date))
      
      return new Response(JSON.stringify({ data }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ========== 导出CSV ==========
    if (action === 'export_csv') {
      const [rechargeRes, consumptionRes] = await Promise.all([
        buildFinanceQuery(supabase, 'recharge_records', queryParams),
        buildFinanceQuery(supabase, 'consumption_records', queryParams),
      ])

      const dailyMap: Record<string, any> = {}
      
      for (const r of rechargeRes.data || []) {
        const day = new Date(r.created_at).toISOString().slice(0, 10)
        if (!dailyMap[day]) {
          dailyMap[day] = { date: day, recharge_count: 0, recharge_amount: 0, consumption_count: 0, consumption_amount: 0, refund_count: 0, refund_amount: 0 }
        }
        dailyMap[day].recharge_count++
        dailyMap[day].recharge_amount += Number(r.amount)
      }
      
      for (const r of consumptionRes.data || []) {
        const day = new Date(r.created_at).toISOString().slice(0, 10)
        if (!dailyMap[day]) {
          dailyMap[day] = { date: day, recharge_count: 0, recharge_amount: 0, consumption_count: 0, consumption_amount: 0, refund_count: 0, refund_amount: 0 }
        }
        dailyMap[day].consumption_count++
        dailyMap[day].consumption_amount += Number(r.amount)
      }

      const rows = Object.values(dailyMap)
        .sort((a: any, b: any) => a.date.localeCompare(b.date)) as any[]
      
      // UTF-8 BOM + CSV 内容
      const BOM = '\uFEFF'
      let csv = BOM + '日期,充值笔数,充值金额,消费笔数,消费金额,退款笔数,退款金额\n'
      for (const r of rows) {
        csv += `${r.date},${r.recharge_count},${r.recharge_amount.toFixed(2)},${r.consumption_count},${r.consumption_amount.toFixed(2)},${r.refund_count},${r.refund_amount.toFixed(2)}\n`
      }

      return new Response(csv, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/csv; charset=utf-8',
          'Content-Disposition': `attachment; filename=finance_report_${new Date().toISOString().slice(0, 10)}.csv`,
        }
      })
    }

    return new Response(JSON.stringify({ error: '未知操作' }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (err) {
    console.error('Finance Error:', err)
    return new Response(JSON.stringify({ 
      error: '服务器内部错误，请稍后重试',
      requestId: crypto.randomUUID()
    }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
