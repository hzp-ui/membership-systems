/**
 * @file test_rpc_params.mjs - 测试 RPC 函数参数
 * @description 通过试错确定 rpc_get_stores 的正确参数
 * @usage node test_rpc_params.mjs
 */

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://yknvmkzgsoirjfchabov.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlrbnZta3pnc29pcmpmY2hhYm92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxNTg0NjksImV4cCI6MjA5NDczNDQ2OX0.1FLE8GXo9Xl43bwjLGC-nvUZ67Q8SVphx__pE4bW4lk';

const sb = createClient(SUPABASE_URL, ANON_KEY);

async function test() {
  // 登录
  const { data: authData, error: authError } = await sb.auth.signInWithPassword({
    email: 'admin@membership.internal',
    password: 'admin123',
  });

  if (authError) {
    console.error('登录失败:', authError.message);
    return;
  }

  console.log('✅ 登录成功\n');

  // 测试 rpc_get_stores 的不同参数组合
  const tests = [
    { name: '无参数', params: undefined },
    { name: '空对象 {}', params: {} },
    { name: 'p_store_id: null', params: { p_store_id: null } },
    { name: 'p_status: active', params: { p_status: 'active' } },
    { name: 'p_status: null', params: { p_status: null } },
  ];

  for (const t of tests) {
    const { data, error } = await sb.rpc('rpc_get_stores', t.params);
    const status = error ? `❌ ${error.message}` : `✅ 成功`;
    console.log(`${t.name}: ${status}`);
    if (data) {
      console.log(`   返回: ${JSON.stringify(data).slice(0, 100)}`);
    }
  }
}

test().catch(err => {
  console.error('异常:', err.message);
  process.exit(1);
});
