const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://yknvmkzgsoirjfchabov.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlrbnZta3pnc29pcmpmY2hhYm92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxNTg0NjksImV4cCI6MjA5NDczNDQ2OX0.1FLE8GXo9Xl43bwjLGC-nvUZ67Q8SVphx__pE4bW4lk';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testSimple() {
  console.log('测试 rpc_get_stores...\n');
  
  try {
    const { data, error } = await supabase.rpc('rpc_get_stores', { p_store_id: null });
    
    if (error) {
      console.error('❌ 错误:', error.message);
      console.error('  错误详情:', error);
    } else {
      console.log('✅ 成功!');
      console.log('  数据:', JSON.stringify(data, null, 2).substring(0, 500));
    }
  } catch (err) {
    console.error('❌ 异常:', err.message);
  }
}

testSimple().catch(console.error);
