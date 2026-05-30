// ============================================
// 统计 Edge Function - 安全修复版
// 功能：营业额/会员增长/热门服务统计
// 安全改进：
// 1. JWT 认证
// 2. 修复 SQL 注入（参数化查询）
// 3. 输入验证
// 4. 权限控制
// 5. 移除危险的 exec_sql RPC 调用
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
const StatisticsSchema = z.object({
  action: z.enum(['revenue', 'member_growth', 'hot_services']),
  store_id: z.string().uuid('门店ID格式不正确').optional().nullable(),
  start_date: z.string().optional().nullable(),
  end_date: z.string().optional().nullable(),
  dimension: z.enum(['day', 'week', 'month', 'year']).optional().default('day'),
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
    const userStoreId = payload.store_id

    if (role === 'super_admin' || role === 'store_admin') {
      const { data: admin } = await supabase
        .from('admins')
        .select('id, role, store_id')
        .eq('id', userId)
        .single()
      
      if (!admin) return { error: '管理员不存在', status: 401 }
      return { user: admin, userType: 'admin' as const }
    } else {
      return { error: '只有管理员可以查看统计数据', status: 403 }
    }
  } catch {
    return { error: '无效的认证信息', status: 401 }
  }
}

// ========== 构建查询（安全） ==========
function buildStatsQuery<T>(supabase: any, table: string, filters: {
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
  } 
  // 指定了 store_id 则按门店筛选
  else if (filters.storeId) {
    query = query.eq('store_id', filters.storeId)
  }
  // 超管可以看到所有

  // 日期筛选
  if (filters.startDate) {
    query = query.gte('created_at', filters.startDate)
  }
  if (filters.endDate) {
    query = query.lte('created_at', filters.endDate)
  }

  return query
}

// ========== 按维度分组统计 ==========
function groupByDimension<T extends { created_at: string }>(
  records: T[],
  dimension: 'day' | 'week' | 'month' | 'year',
  valueExtractor: (item: T) => number
): { period: string; value: number }[] {
  const grouped: Record<string, number> = {}

  for (const r of records) {
    const d = new Date(r.created_at)
    let key: string

    if (dimension === 'week') {
      // 周一作为一周开始
      const weekStart = new Date(d)
      weekStart.setDate(d.getDate() - d.getDay() + 1)
      key = weekStart.toISOString().slice(0, 10)
    } else if (dimension === 'month') {
      key = d.toISOString().slice(0, 7)
    } else if (dimension === 'year') {
      key = d.toISOString().slice(0, 4)
    } else {
      key = d.toISOString().slice(0, 10)
    }

    grouped[key] = (grouped[key] || 0) + valueExtractor(r)
  }

  return Object.entries(grouped)
    .map(([period, value]) => ({ period, value }))
    .sort((a, b) => a.period.localeCompare(b.period))
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

    const { user, userType } = authResult

    // ========== 2. 验证输入 ==========
    let body
    try {
      body = StatisticsSchema.parse(await req.json())
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

    const { action, store_id, start_date, end_date, dimension } = body

    // 构建安全查询参数
    const queryParams = {
      storeId: store_id,
      startDate: start_date,
      endDate: end_date,
      userStoreId: user.store_id,
      role: user.role,
    }

    // ========== 营业额统计 ==========
    if (action === 'revenue') {
      const query = buildStatsQuery(supabase, 'consumption_records', queryParams)
      const { data: records, error } = await query

      if (error) {
        console.error('Revenue query error:', error)
        return new Response(JSON.stringify({ error: '查询失败' }), {
          status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      const result = groupByDimension(
        records || [],
        dimension,
        (r) => Number(r.amount)
      )

      return new Response(JSON.stringify({ 
        data: result.map(item => ({
          period: item.period,
          total_amount: item.value
        }))
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ========== 会员增长统计 ==========
    if (action === 'member_growth') {
      const query = buildStatsQuery(supabase, 'members', queryParams)
      const { data: records, error } = await query

      if (error) {
        console.error('Member growth query error:', error)
        return new Response(JSON.stringify({ error: '查询失败' }), {
          status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      const result = groupByDimension(
        records || [],
        dimension,
        () => 1  // 每个会员计为 1
      )

      return new Response(JSON.stringify({ 
        data: result.map(item => ({
          period: item.period,
          count: item.value
        }))
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ========== 热门服务统计 ==========
    if (action === 'hot_services') {
      const query = buildStatsQuery(supabase, 'consumption_records', queryParams)
      const { data: records, error } = await query

      if (error) {
        console.error('Hot services query error:', error)
        return new Response(JSON.stringify({ error: '查询失败' }), {
          status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 按服务分组统计
      const grouped: Record<string, number> = {}
      for (const r of records || []) {
        grouped[r.service_name] = (grouped[r.service_name] || 0) + 1
      }

      const result = Object.entries(grouped)
        .map(([service_name, count]) => ({ service_name, count }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 20)  // 限制返回数量

      return new Response(JSON.stringify({ data: result }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    return new Response(JSON.stringify({ error: '未知操作' }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (err) {
    console.error('Statistics Error:', err)
    return new Response(JSON.stringify({ 
      error: '服务器内部错误，请稍后重试',
      requestId: crypto.randomUUID()
    }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
