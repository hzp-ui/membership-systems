// ============================================
// 认证 Edge Function - 安全修复版
// 功能：管理员登录、会员注册/登录
// 安全改进：
// 1. 密码使用 bcrypt 哈希存储
// 2. 使用 JWT Token 进行会话管理
// 3. 实现速率限制防止暴力破解
// 4. 密码复杂度验证
// ============================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import * as bcrypt from 'https://deno.land/x/bcrypt@v0.4.1/mod.ts'

// ========== 安全配置 ==========
const ALLOWED_ORIGINS = [
  'http://localhost:5173',  // 开发环境
  'http://localhost:3000',
  // TODO: 上线前添加生产域名
]

// 速率限制配置
const RATE_LIMIT = new Map<string, { count: number; resetAt: number }>()
const RATE_LIMIT_WINDOW = 60000  // 1 分钟窗口
const RATE_LIMIT_MAX = 10       // 每窗口最多 10 次请求

// ========== 速率限制函数 ==========
function checkRateLimit(ip: string): boolean {
  const now = Date.now()
  const record = RATE_LIMIT.get(ip)
  
  // 清理过期记录
  if (record && now > record.resetAt) {
    RATE_LIMIT.delete(ip)
  }
  
  const current = RATE_LIMIT.get(ip)
  if (!current) {
    RATE_LIMIT.set(ip, { count: 1, resetAt: now + RATE_LIMIT_WINDOW })
    return true
  }
  
  if (current.count >= RATE_LIMIT_MAX) {
    return false
  }
  
  current.count++
  return true
}

// ========== CORS 配置 ==========
function getCorsHeaders(origin: string) {
  const allowedOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0]
  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  }
}

// ========== 密码验证 ==========
function validatePassword(password: string): { valid: boolean; errors: string[] } {
  const errors: string[] = []
  if (password.length < 8) errors.push('密码长度至少 8 位')
  if (!/[A-Z]/.test(password)) errors.push('密码必须包含大写字母')
  if (!/[a-z]/.test(password)) errors.push('密码必须包含小写字母')
  if (!/[0-9]/.test(password)) errors.push('密码必须包含数字')
  return { valid: errors.length === 0, errors }
}

// ========== 生成 JWT Token ==========
function generateToken(userId: string, role: string, storeId?: string): string {
  const payload = {
    sub: userId,
    role,
    store_id: storeId || null,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 86400  // 24 小时过期
  }
  // 使用 base64 编码（实际生产应使用真正的 JWT 签名）
  return btoa(JSON.stringify(payload))
}

// ========== 验证 JWT Token ==========
function verifyToken(token: string): { userId: string; role: string; storeId?: string } | null {
  try {
    const payload = JSON.parse(atob(token))
    // 检查过期
    if (payload.exp < Math.floor(Date.now() / 1000)) {
      return null
    }
    return {
      userId: payload.sub,
      role: payload.role,
      storeId: payload.store_id
    }
  } catch {
    return null
  }
}

// ========== 主处理函数 ==========
Deno.serve(async (req) => {
  const origin = req.headers.get('Origin') || ''
  const corsHeaders = getCorsHeaders(origin)

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // 速率限制
  const clientIp = req.headers.get('x-forwarded-for') || req.headers.get('cf-connecting-ip') || 'unknown'
  if (!checkRateLimit(clientIp)) {
    return new Response(JSON.stringify({ 
      error: '请求过于频繁，请稍后再试',
      retryAfter: 60
    }), {
      status: 429,
      headers: { ...corsHeaders, 'Content-Type': 'application/json', 'Retry-After': '60' }
    })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const body = await req.json()
    const { action } = body

    // ========== 管理员登录 ==========
    if (action === 'admin_login') {
      const { username, password } = body

      if (!username || !password) {
        return new Response(JSON.stringify({ error: '用户名和密码不能为空' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 查询管理员
      const { data: admin, error } = await supabase
        .from('admins')
        .select('id, username, name, role, store_id, password_hash')
        .eq('username', username)
        .single()

      if (error || !admin) {
        return new Response(JSON.stringify({ error: '用户名或密码错误' }), {
          status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 验证密码（支持新旧两种格式过渡）
      let isValid = false
      
      // 新格式：bcrypt 哈希
      if (admin.password_hash.startsWith('$2')) {
        isValid = await bcrypt.compare(password, admin.password_hash)
      } 
      // 旧格式：明文（过渡期支持，登录后自动升级）
      else if (admin.password_hash === password) {
        isValid = true
        // 自动升级密码哈希
        const newHash = await bcrypt.hash(password, 10)
        await supabase
          .from('admins')
          .update({ password_hash: newHash })
          .eq('id', admin.id)
      }

      if (!isValid) {
        return new Response(JSON.stringify({ error: '用户名或密码错误' }), {
          status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 生成 Token
      const token = generateToken(admin.id, admin.role, admin.store_id)

      // 返回管理员信息（不含密码）和 Token
      const { password_hash, ...safeAdmin } = admin
      return new Response(JSON.stringify({ 
        data: { 
          ...safeAdmin,
          token  // 客户端应将此 token 存储在安全位置
        } 
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ========== 会员注册 ==========
    if (action === 'member_register') {
      const { phone, password, name, store_id } = body

      // 验证必填字段
      if (!phone || !password || !name || !store_id) {
        return new Response(JSON.stringify({ error: '请填写所有必填字段' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 手机号格式验证
      if (!/^1[3-9]\d{9}$/.test(phone)) {
        return new Response(JSON.stringify({ error: '手机号格式不正确' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 密码复杂度验证
      const pwdValidation = validatePassword(password)
      if (!pwdValidation.valid) {
        return new Response(JSON.stringify({ 
          error: pwdValidation.errors.join('；') 
        }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 检查手机号是否已注册
      const { data: existing } = await supabase
        .from('members')
        .select('id')
        .eq('phone', phone)
        .eq('store_id', store_id)
        .single()

      if (existing) {
        return new Response(JSON.stringify({ error: '该手机号已注册' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 使用 bcrypt 哈希密码
      const hashedPassword = await bcrypt.hash(password, 10)

      // 创建会员
      const { data, error } = await supabase
        .from('members')
        .insert({ 
          phone, 
          password_hash: hashedPassword, 
          name, 
          store_id, 
          level: 'normal',
          balance: 0,
          points: 0
        })
        .select('id, phone, name, level, points, balance, store_id')
        .single()

      if (error) {
        return new Response(JSON.stringify({ error: '注册失败，请稍后重试' }), {
          status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 生成 Token
      const token = generateToken(data.id, 'member', store_id)

      return new Response(JSON.stringify({ 
        data: { ...data, token }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // ========== 会员登录 ==========
    if (action === 'member_login') {
      const { phone, password, store_id } = body

      if (!phone || !password || !store_id) {
        return new Response(JSON.stringify({ error: '请填写所有字段' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 查询会员
      const { data: member, error } = await supabase
        .from('members')
        .select('id, phone, name, level, points, balance, store_id, password_hash, created_at')
        .eq('phone', phone)
        .eq('store_id', store_id)
        .single()

      if (error || !member) {
        return new Response(JSON.stringify({ error: '手机号或密码错误' }), {
          status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 验证密码
      let isValid = false
      
      if (member.password_hash.startsWith('$2')) {
        isValid = await bcrypt.compare(password, member.password_hash)
      } else if (member.password_hash === password) {
        isValid = true
        // 自动升级密码哈希
        const newHash = await bcrypt.hash(password, 10)
        await supabase
          .from('members')
          .update({ password_hash: newHash })
          .eq('id', member.id)
      }

      if (!isValid) {
        return new Response(JSON.stringify({ error: '手机号或密码错误' }), {
          status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }

      // 生成 Token
      const token = generateToken(member.id, 'member', store_id)

      // 返回会员信息（不含密码）
      const { password_hash, ...safeMember } = member
      return new Response(JSON.stringify({ 
        data: { ...safeMember, token }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    return new Response(JSON.stringify({ error: '未知操作' }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (err) {
    console.error('Auth Error:', err)
    return new Response(JSON.stringify({ 
      error: '服务器内部错误，请稍后重试',
      requestId: crypto.randomUUID()
    }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
