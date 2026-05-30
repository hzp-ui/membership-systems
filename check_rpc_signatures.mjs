/**
 * @file check_rpc_signatures.mjs - 检查所有 RPC 函数签名
 * @description 查询 information_schema 获取 rpc_* 函数的参数列表
 * @usage node check_rpc_signatures.mjs
 */

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://yknvmkzgsoirjfchabov.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlrbnZta3pnc29pcmpmY2hhYm92Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTE1ODQ2OSwiZXhwIjoyMDk0NzM0NDY5fQ.vhWyPfQGxQYkP3ApPtsayb5kq4uChngbo2l-iehbbI8';

const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function checkSignatures() {
  console.log('🔍 检查 RPC 函数签名\n');
  console.log('='.repeat(80));

  // 查询所有 rpc_* 函数
  const sql = `
    SELECT 
      p.proname AS function_name,
      pg_get_function_identity_arguments(p.oid) AS identity_arguments,
      pg_get_function_result(p.oid) AS return_type
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname LIKE 'rpc_%'
    ORDER BY p.proname;
  `;

  const { data, error } = await sb.rpc('exec_sql', { sql });
  
  if (error) {
    // 如果函数不存在，尝试直接查询
    console.log('尝试直接查询 pg_proc...\n');
    
    const { data: data2, error: error2 } = await sb.from('pg_proc').select('*').limit(1);
    console.log('pg_proc access:', error2?.message || '无权限');
    
    // 尝试 information_schema
    const { data: data3, error: error3 } = await sb.rpc('exec_sql', { 
      sql: `SELECT * FROM information_schema.routines WHERE routine_name LIKE 'rpc_%' LIMIT 5` 
    });
    console.log('information_schema:', error3?.message || JSON.stringify(data3, null, 2));
    
    return;
  }

  console.log('✅ 查询结果:\n');
  console.log(JSON.stringify(data, null, 2));
}

// 尝试更简单的方法：直接调用函数并捕获错误信息
async function testRpcCall(fnName, params = {}) {
  const { error } = await sb.rpc(fnName, params);
  if (error) {
    return { success: false, error: error.message };
  }
  return { success: true };
}

async function guessSignatures() {
  console.log('\n🧪 通过试错推断函数签名\n');
  console.log('='.repeat(80));

  const functions = [
    'rpc_get_stores',
    'rpc_get_admins',
    'rpc_get_members',
    'rpc_get_barbers',
    'rpc_get_services',
    'rpc_get_service_types',
    'rpc_get_packages',
    'rpc_get_recharge_records',
    'rpc_get_consume_records',
    'rpc_get_appointments',
  ];

  for (const fn of functions) {
    console.log(`\n📝 ${fn}:`);
    
    // 测试 1: 无参数
    let result = await testRpcCall(fn);
    if (result.success) {
      console.log('  ✅ 无参数调用成功');
      continue;
    }
    
    // 测试 2: 空对象
    result = await testRpcCall(fn, {});
    if (result.success) {
      console.log('  ✅ 空对象调用成功');
      continue;
    }
    
    console.log(`  ❌ ${result.error}`);
  }
}

await checkSignatures().catch(() => {});
await guessSignatures();

console.log('\n✅ 检查完成\n');
