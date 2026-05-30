import { createClient } from '@supabase/supabase-js';

const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlrbnZta3pnc29pcmpmY2hhYm92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxNTg0NjksImV4cCI6MjA5NDczNDQ2OX0.1FLE8GXo9Xl43bwjLGC-nvUZ67Q8SVphx__pE4bW4lk';

const sb = createClient('https://yknvmkzgsoirjfchabov.supabase.co', ANON_KEY);

async function testLogin() {
  console.log('测试新认证登录...\n');

  const { data, error } = await sb.auth.signInWithPassword({
    email: 'admin@membership.internal',
    password: 'admin123'
  });

  if (error) {
    console.error('❌ 登录失败:', error.message);
    return;
  }

  console.log('✅ 登录成功!');
  console.log('User ID:', data.user.id);
  console.log('Email:', data.user.email);
  console.log('Token (前50字符):', data.session.access_token.substring(0, 50) + '...');

  // 测试获取当前用户
  const { data: userData, error: userErr } = await sb.auth.getUser();
  if (userErr) {
    console.error('获取用户失败:', userErr.message);
  } else {
    console.log('\n当前用户:', userData.user.email);
  }
}

testLogin().catch(console.error);
