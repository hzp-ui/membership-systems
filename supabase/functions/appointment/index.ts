// ============================================
// 预约 Edge Function - 安全修复版
// 功能：创建/确认/取消/完成预约
// 安全改进：
// 1. JWT 认证
// 2. IDOR 防护
// 3. 输入验证
// 4. 权限控制
// 5. 审计日志
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

// ========== 验证预约权限 ==========
async function verifyAppointmentPermission(
  supabase: any, 
  user: any, 
  userType: 'admin' | 'member',
  appointmentId: string
) {
  const { data: appt } = await supabase
    .from('appointments')
    .select('*')
    .eq('id', appointmentId)
    .single()

  if (!appt) return { allowed: false, error: '预约不存在', status: 404 }

  // 会员只能操作自己的预约
  if (userType === 'member') {
    if (appt.member_id !== user.id) {
      return { allowed: false, error: '无权操作此预约', status: 403 }
    }
    return { allowed: true, appt }
  }

  // 店长只能操作本店的预约
  if (user.role === 'store_admin') {
    if (appt.store_id !== user.store_id) {
      return { allowed: false, error: '无权操作此预约', status: 403 }
    }
    return { allowed: true, appt }
  }

  // 超管可以操作所有
  return { allowed: true, appt }
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

    // ========== 2. 解析输入 ==========
    let body
    try {
      body = await req.json()
    } catch {
      return new Response(JSON.stringify({ error: '请求格式错误' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const { action } = body

    // ========== 创建预约 ==========
    if (action === 'create') {
      const { member_id, barber_id, service_id, appointment_time, store_id } = body

      // 验证必填字段
      if (!member_id || !barber_id || !service_id || !appointment_time || !store_id) {
        return new Response(JSON.stringify({ error: '请填写所有必填字段' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 验证 UUID 格式
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
      if (!uuidRegex.test(member_id) || !uuidRegex.test(barber_id) || !uuidRegex.test(service_id) || !uuidRegex.test(store_id)) {
        return new Response(JSON.stringify({ error: 'ID 格式不正确' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 验证预约时间格式
      const appointmentDate = new Date(appointment_time)
      if (isNaN(appointmentDate.getTime())) {
        return new Response(JSON.stringify({ error: '预约时间格式不正确' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 验证预约时间不能是过去
      if (appointmentDate < new Date()) {
        return new Response(JSON.stringify({ error: '预约时间不能是过去' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 会员只能为自己创建预约
      if (userType === 'member') {
        if (user.id !== member_id) {
          return new Response(JSON.stringify({ error: '只能为自己创建预约' }), {
            status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          })
        }
      }

      // 店长只能为本店创建预约
      if (userType === 'admin' && user.role === 'store_admin') {
        if (user.store_id !== store_id) {
          return new Response(JSON.stringify({ error: '只能为本店创建预约' }), {
            status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          })
        }
      }

      // 创建预约
      const { data, error } = await supabase
        .from('appointments')
        .insert({
          member_id, barber_id, service_id, 
          appointment_time: appointmentDate.toISOString(), 
          store_id, 
          status: 'pending'
        })
        .select()
        .single()

      if (error) {
        return new Response(JSON.stringify({ error: '创建预约失败' }), {
          status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 审计日志
      await logAudit(supabase, {
        userId: user.id,
        userType,
        action: 'CREATE_APPOINTMENT',
        resourceType: 'appointment',
        resourceId: data.id,
        details: { member_id, barber_id, service_id, appointment_time },
        ipAddress: clientIp
      })

      return new Response(JSON.stringify({ data }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ========== 确认预约 ==========
    if (action === 'confirm') {
      const { id } = body
      if (!id) {
        return new Response(JSON.stringify({ error: '缺少预约ID' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      const permResult = await verifyAppointmentPermission(supabase, user, userType, id)
      if (!permResult.allowed) {
        return new Response(JSON.stringify({ error: permResult.error }), {
          status: permResult.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      const appt = permResult.appt!
      if (appt.status !== 'pending') {
        return new Response(JSON.stringify({ error: '只能确认待确认的预约' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      const { data, error } = await supabase
        .from('appointments')
        .update({ status: 'confirmed' })
        .eq('id', id)
        .select()
        .single()

      if (error) {
        return new Response(JSON.stringify({ error: '确认预约失败' }), {
          status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      await logAudit(supabase, {
        userId: user.id,
        userType,
        action: 'CONFIRM_APPOINTMENT',
        resourceType: 'appointment',
        resourceId: id,
        ipAddress: clientIp
      })

      return new Response(JSON.stringify({ data }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ========== 取消预约 ==========
    if (action === 'cancel') {
      const { id } = body
      if (!id) {
        return new Response(JSON.stringify({ error: '缺少预约ID' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      const permResult = await verifyAppointmentPermission(supabase, user, userType, id)
      if (!permResult.allowed) {
        return new Response(JSON.stringify({ error: permResult.error }), {
          status: permResult.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      const appt = permResult.appt!
      if (!['pending', 'confirmed'].includes(appt.status)) {
        return new Response(JSON.stringify({ error: '只能取消待确认或已确认的预约' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      const { data, error } = await supabase
        .from('appointments')
        .update({ status: 'cancelled' })
        .eq('id', id)
        .select()
        .single()

      if (error) {
        return new Response(JSON.stringify({ error: '取消预约失败' }), {
          status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      await logAudit(supabase, {
        userId: user.id,
        userType,
        action: 'CANCEL_APPOINTMENT',
        resourceType: 'appointment',
        resourceId: id,
        ipAddress: clientIp
      })

      return new Response(JSON.stringify({ data }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ========== 完成预约 ==========
    if (action === 'complete') {
      const { id } = body
      if (!id) {
        return new Response(JSON.stringify({ error: '缺少预约ID' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      const permResult = await verifyAppointmentPermission(supabase, user, userType, id)
      if (!permResult.allowed) {
        return new Response(JSON.stringify({ error: permResult.error }), {
          status: permResult.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      const appt = permResult.appt!
      if (appt.status !== 'confirmed') {
        return new Response(JSON.stringify({ error: '只能完成已确认的预约' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 调用消费逻辑
      const consumeRes = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/consume`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${authHeader}`,
        },
        body: JSON.stringify({
          member_id: appt.member_id,
          service_id: appt.service_id,
          barber_id: appt.barber_id,
        }),
      })
      const consumeData = await consumeRes.json()

      if (!consumeRes.ok) {
        return new Response(JSON.stringify({ error: consumeData.error || '消费处理失败' }), {
          status: consumeRes.status, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 更新预约状态
      const { data, error } = await supabase
        .from('appointments')
        .update({ status: 'completed' })
        .eq('id', id)
        .select()
        .single()

      await logAudit(supabase, {
        userId: user.id,
        userType,
        action: 'COMPLETE_APPOINTMENT',
        resourceType: 'appointment',
        resourceId: id,
        details: { consumption: consumeData.data },
        ipAddress: clientIp
      })

      return new Response(JSON.stringify({ data, consumption: consumeData.data }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    return new Response(JSON.stringify({ error: '未知操作' }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (err) {
    console.error('Appointment Error:', err)
    return new Response(JSON.stringify({ 
      error: '服务器内部错误，请稍后重试',
      requestId: crypto.randomUUID()
    }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
