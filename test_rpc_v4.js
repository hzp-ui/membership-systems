const { createClient } = require('@supabase/supabase-js');

// 硬编码配置（从 .env 文件复制）
const SUPABASE_URL = 'https://yknvmkzgsoirjfchabov.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlrbnZta3pnc29pcmpmY2hhYm92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxNTg0NjksImV4cCI6MjA5NDczNDQ2OX0.1FLE8GXo9Xl43bwjLGC-nvUZ67Q8SVphx__pE4bW4lk';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testAllRpc() {
  console.log('=== RPC 函数测试 v4（硬编码配置）===\n');
  
  // 先登录获取 JWT
  console.log('【登录获取 JWT】');
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: 'admin@membership.internal',
    <SECRET_REDACTED>
  });
  
  if (authError) {
    console.error('❌ 登录失败:', authError.message);
    return;
  }
  console.log('✅ 登录成功\n');
  
  const results = { pass: 0, fail: 0, errors: [] };  
  // 辅助函数：调用 RPC 并处理结果
  async function callRpc(funcName, params = {}) {
    try {
      const { data, error } = await supabase.rpc(funcName, params);
      if (error) throw error;
      return { success: true, data };
    } catch (err) {
      return { success: false, error: err.message };
    }
  }
  
  // ==================== 辅助函数 ====================
  console.log('【辅助函数】');
  
  let currentAdminId = null;
  let currentStoreId = null;
  let currentMemberId = null;
  let currentBarberId = null;
  let currentServiceId = null;
  let currentPackageId = null;
  
  // 1. rpc_get_current_admin_info
  let result = await callRpc('rpc_get_current_admin_info');
  if (result.success) {
    console.log('✅ rpc_get_current_admin_info');
    const admin = result.data?.data;
    if (admin) {
      currentAdminId = admin.id;
      currentStoreId = admin.store_id;
      console.log(`   管理员: ${admin.name}, 门店ID: ${currentStoreId}`);
    }
    results.pass++;
  } else {
    console.log('❌ rpc_get_current_admin_info:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_current_admin_info', error: result.error });
  }
  
  // ==================== 门店 CRUD ====================
  console.log('\n【门店 CRUD】');
  
  // 2. rpc_get_stores
  result = await callRpc('rpc_get_stores', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_stores');
    results.pass++;
  } else {
    console.log('❌ rpc_get_stores:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_stores', error: result.error });
  }
  
  // 3. rpc_create_store (参数：p_name, p_address, p_phone, p_manager)
  result = await callRpc('rpc_create_store', {
    p_name: '测试门店',
    p_address: '测试地址123号',
    p_phone: '13800138000',
    p_manager: '测试经理'
  });
  if (result.success) {
    console.log('✅ rpc_create_store');
    const store = result.data?.data;
    if (store) {
      currentStoreId = store.id;
      console.log(`   新门店ID: ${currentStoreId}`);
    }
    results.pass++;
  } else {
    console.log('❌ rpc_create_store:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_create_store', error: result.error });
  }
  
  // 4. rpc_update_store (参数：p_id, p_name, p_address, p_phone, p_manager, p_status)
  if (currentStoreId) {
    result = await callRpc('rpc_update_store', {
      p_id: currentStoreId,
      p_name: '测试门店（已更新）',
      p_address: '新地址456号',
      p_phone: '13900139000',
      p_manager: '新经理',
      p_status: 'active'
    });
    if (result.success) {
      console.log('✅ rpc_update_store');
      results.pass++;
    } else {
      console.log('❌ rpc_update_store:', result.error);
      results.fail++;
      results.errors.push({ func: 'rpc_update_store', error: result.error });
    }
  }
  
  // 5. rpc_delete_store
  if (currentStoreId) {
    result = await callRpc('rpc_delete_store', {
      p_id: currentStoreId
    });
    if (result.success) {
      console.log('✅ rpc_delete_store');
      results.pass++;
    } else {
      console.log('❌ rpc_delete_store:', result.error);
      results.fail++;
      results.errors.push({ func: 'rpc_delete_store', error: result.error });
    }
  }
  
  // ==================== 管理员 CRUD ====================
  console.log('\n【管理员 CRUD】');
  
  // 6. rpc_get_admins
  result = await callRpc('rpc_get_admins', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_admins');
    results.pass++;
  } else {
    console.log('❌ rpc_get_admins:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_admins', error: result.error });
  }
  
  // 7. rpc_create_admin (参数：p_username, p_password, p_name, p_phone, p_role, p_store_id)
  // 需要先获取一个有效的 store_id
  let testStoreId = currentStoreId;
  if (!testStoreId) {
    // 获取第一个门店
    const { data: stores } = await supabase.from('stores').select('id').limit(1);
    if (stores && stores.length > 0) {
      testStoreId = stores[0].id;
    }
  }
  
  if (testStoreId) {
    result = await callRpc('rpc_create_admin', {
      p_username: 'testadmin',
      p_password: 'test123',
      p_name: '测试管理员',
      p_phone: '13700137000',
      p_role: 'store_admin',
      p_store_id: testStoreId
    });
    if (result.success) {
      console.log('✅ rpc_create_admin');
      results.pass++;
    } else {
      console.log('❌ rpc_create_admin:', result.error);
      results.fail++;
      results.errors.push({ func: 'rpc_create_admin', error: result.error });
    }
  }
  
  // ==================== 总结 ====================
  console.log('\n' + '='.repeat(50));
  console.log(`✅ 通过: ${results.pass}/7`);
  console.log(`❌ 失败: ${results.fail}/7`);
  
  if (results.errors.length > 0) {
    console.log('\n错误详情:');
    results.errors.forEach((err, idx) => {
      console.log(`${idx + 1}. ${err.func}: ${err.error}`);
    });
  }
  
  console.log('='.repeat(50));
}

testAllRpc().catch(console.error);
