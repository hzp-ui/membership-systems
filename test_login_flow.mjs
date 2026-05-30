/**
 * @file test_login_flow.mjs - 测试新的登录流程
 * @description 验证 Supabase Auth 登录 + RPC 获取管理员信息
 * @usage node test_login_flow.mjs
 */

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://yknvmkzgsoirjfchabov.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlrbnZta3pnc29pcmpmY2hhYm92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxNTg0NjksImV4cCI6MjA5NDczNDQ2OX0.1FLE8GXo9Xl43bwjLGC-nvUZ67Q8SVphx__pE4bW4lk';

const sb = createClient(SUPABASE_URL, ANON_KEY);

async function testLoginFlow() {
  console.log('🔐 测试新登录流程\n');
  console.log('='.repeat(60));

  // Step 1: Supabase Auth 登录
  console.log('\n📝 Step 1: Supabase Auth 登录');
  console.log('Email: admin@membership.internal');
  
  const { data: authData, error: authError } = await sb.auth.signInWithPassword({
    email: 'admin@membership.internal',
    password: 'admin123',
  });

  if (authError) {
    console.error('❌ 登录失败:', authError.message);
    return;
  }

  if (!authData.session) {
    console.error('❌ 登录失败: 无会话数据');
    return;
  }

  console.log('✅ 登录成功!');
  console.log(`   User ID: ${authData.user.id}`);
  console.log(`   Email: ${authData.user.email}`);
  console.log(`   JWT (前50字符): ${authData.session.access_token.substring(0, 50)}...`);
  console.log(`   Expires at: ${new Date(authData.session.expires_at * 1000).toLocaleString('zh-CN')}`);

  // Step 2: 调用 RPC 获取管理员详细信息
  console.log('\n📝 Step 2: 调用 rpc_get_current_admin_info()');
  
  const { data: rpcData, error: rpcError } = await sb.rpc('rpc_get_current_admin_info');

  if (rpcError) {
    console.error('❌ RPC 调用失败:', rpcError.message);
    return;
  }

  if (!rpcData) {
    console.error('❌ RPC 返回空数据');
    return;
  }

  if (rpcData.error) {
    console.error('❌ RPC 返回错误:', rpcData.error);
    return;
  }

  console.log('✅ RPC 调用成功!');
  console.log('   管理员信息:');
  console.log(`   ID: ${rpcData.data?.id}`);
  console.log(`   Username: ${rpcData.data?.username}`);
  console.log(`   Name: ${rpcData.data?.name}`);
  console.log(`   Role: ${rpcData.data?.role}`);
  console.log(`   Store ID: ${rpcData.data?.store_id || '(无)'}`);

  // Step 3: 验证 JWT 已自动设置到 Supabase 客户端
  console.log('\n📝 Step 3: 验证 JWT 认证');
  
  const { data: userData, error: userError } = await sb.auth.getUser();
  
  if (userError) {
    console.error('❌ 获取当前用户失败:', userError.message);
    return;
  }

  console.log('✅ JWT 认证成功!');
  console.log(`   Current User: ${userData.user.email}`);
  console.log(`   Aud: ${userData.user.aud}`);
  console.log(`   Role: ${userData.user.role}`);

  // Step 4: 测试一个需要认证的 RPC 调用
  console.log('\n📝 Step 4: 测试需要认证的 RPC (rpc_get_stores)');
  
  const { data: storesData, error: storesError } = await sb.rpc('rpc_get_stores');
  
  if (storesError) {
    console.error('❌ rpc_get_stores 失败:', storesError.message);
    return;
  }

  console.log('✅ rpc_get_stores 调用成功!');
  console.log(`   返回数据: ${Array.isArray(storesData?.data) ? storesData.data.length : 0} 条门店记录`);

  // 总结
  console.log('\n' + '='.repeat(60));
  console.log('🎉 登录流程测试通过！');
  console.log('='.repeat(60));
  console.log('\n✅ Supabase Auth 登录正常');
  console.log('✅ JWT Token 自动设置到客户端');
  console.log('✅ RPC 调用正常 (rpc_get_current_admin_info)');
  console.log('✅ 需要认证的 RPC 正常 (rpc_get_stores)');
  console.log('\n前端修改后的登录流程应该能正常工作！\n');
}

testLoginFlow().catch(err => {
  console.error('💥 测试异常:', err.message);
  process.exit(1);
});
