const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://yknvmkzgsoirjfchabov.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlrbnZta3pnc29pcmpmY2hhYm92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxNTg0NjksImV4cCI6MjA5NDczNDQ2OX0.1FLE8GXo9Xl43bwjLGC-nvUZ67Q8SVphx__pE4bW4lk';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testAllRpc() {
  console.log('=== RPC 函数完整测试 ==\n');
  
  // 先登录获取 JWT
  console.log('【步骤1：登录获取 JWT】');
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
  
  let currentStoreId = 'a0000000-0000-0000-0000-000000000002'; // 使用已存在的门店
  let currentAdminId = null;
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
      console.log(`   当前管理员: ${admin.name}`);
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
  
  // 3. rpc_create_store
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
  
  // 4. rpc_update_store
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
  
  // 7. rpc_create_admin
  result = await callRpc('rpc_create_admin', {
    p_username: 'testadmin' + Date.now(),
    p_password: 'test123',
    p_name: '测试管理员',
    p_phone: '13700137000',
    p_role: 'store_admin',
    p_store_id: 'a0000000-0000-0000-0000-000000000002'
  });
  if (result.success) {
    console.log('✅ rpc_create_admin');
    results.pass++;
  } else {
    console.log('❌ rpc_create_admin:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_create_admin', error: result.error });
  }
  
  // ==================== 会员 CRUD ====================
  console.log('\n【会员 CRUD】');
  
  // 8. rpc_get_members
  result = await callRpc('rpc_get_members', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_members');
    results.pass++;
  } else {
    console.log('❌ rpc_get_members:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_members', error: result.error });
  }
  
  // 9. rpc_create_member
  result = await callRpc('rpc_create_member', {
    p_phone: '1360013' + Math.floor(Math.random() * 10000),
    p_name: '测试会员',
    p_store_id: 'a0000000-0000-0000-0000-000000000002',
    p_level: 'normal'
  });
  if (result.success) {
    console.log('✅ rpc_create_member');
    const member = result.data?.data;
    if (member) {
      currentMemberId = member.id;
      console.log(`   新会员ID: ${currentMemberId}`);
    }
    results.pass++;
  } else {
    console.log('❌ rpc_create_member:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_create_member', error: result.error });
  }
  
  // 10. rpc_update_member
  if (currentMemberId) {
    result = await callRpc('rpc_update_member', {
      p_id: currentMemberId,
      p_name: '测试会员（已更新）',
      p_phone: '13600136001',
      p_level: 'silver',
      p_points: 100,
      p_balance: 500.00,
      p_status: 'active'
    });
    if (result.success) {
      console.log('✅ rpc_update_member');
      results.pass++;
    } else {
      console.log('❌ rpc_update_member:', result.error);
      results.fail++;
      results.errors.push({ func: 'rpc_update_member', error: result.error });
    }
  }
  
  // ==================== 理发师 CRUD ====================
  console.log('\n【理发师 CRUD】');
  
  // 11. rpc_get_barbers
  result = await callRpc('rpc_get_barbers', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_barbers');
    results.pass++;
  } else {
    console.log('❌ rpc_get_barbers:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_barbers', error: result.error });
  }
  
  // 12. rpc_create_barber
  result = await callRpc('rpc_create_barber', {
    p_name: '测试理发师',
    p_phone: '13500135000',
    p_specialties: JSON.stringify(['洗发', '剪发']),
    p_store_id: 'a0000000-0000-0000-0000-000000000002'
  });
  if (result.success) {
    console.log('✅ rpc_create_barber');
    const barber = result.data?.data;
    if (barber) {
      currentBarberId = barber.id;
      console.log(`   新理发师ID: ${currentBarberId}`);
    }
    results.pass++;
  } else {
    console.log('❌ rpc_create_barber:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_create_barber', error: result.error });
  }
  
  // ==================== 服务类型 CRUD ====================
  console.log('\n【服务类型 CRUD】');
  
  // 13. rpc_get_service_types
  result = await callRpc('rpc_get_service_types', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_service_types');
    results.pass++;
  } else {
    console.log('❌ rpc_get_service_types:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_service_types', error: result.error });
  }
  
  // 14. rpc_create_service_type
  result = await callRpc('rpc_create_service_type', {
    p_name: '新服务类型',
    p_store_id: 'a0000000-0000-0000-0000-000000000002'
  });
  if (result.success) {
    console.log('✅ rpc_create_service_type');
    results.pass++;
  } else {
    console.log('❌ rpc_create_service_type:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_create_service_type', error: result.error });
  }
  
  // ==================== 充值套餐 CRUD ====================
  console.log('\n【充值套餐 CRUD】');
  
  // 15. rpc_get_packages
  result = await callRpc('rpc_get_packages', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_packages');
    results.pass++;
  } else {
    console.log('❌ rpc_get_packages:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_packages', error: result.error });
  }
  
  // 16. rpc_create_package
  result = await callRpc('rpc_create_package', {
    p_name: '测试套餐',
    p_amount: 500.00,
    p_bonus: 50.00,
    p_status: 'active',
    p_store_id: 'a0000000-0000-0000-0000-000000000002'
  });
  if (result.success) {
    console.log('✅ rpc_create_package');
    const pkg = result.data?.data;
    if (pkg) {
      currentPackageId = pkg.id;
      console.log(`   新套餐ID: ${currentPackageId}`);
    }
    results.pass++;
  } else {
    console.log('❌ rpc_create_package:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_create_package', error: result.error });
  }
  
  // ==================== 充值记录 ====================
  console.log('\n【充值记录】');
  
  // 17. rpc_create_recharge_record
  if (currentMemberId) {
    result = await callRpc('rpc_create_recharge_record', {
      p_member_id: currentMemberId,
      p_amount: 200.00,
      p_bonus: 20.00,
      p_package_name: '测试套餐'
    });
    if (result.success) {
      console.log('✅ rpc_create_recharge_record');
      results.pass++;
    } else {
      console.log('❌ rpc_create_recharge_record:', result.error);
      results.fail++;
      results.errors.push({ func: 'rpc_create_recharge_record', error: result.error });
    }
  }
  
  // 18. rpc_get_recharge_records
  result = await callRpc('rpc_get_recharge_records', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_recharge_records');
    results.pass++;
  } else {
    console.log('❌ rpc_get_recharge_records:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_recharge_records', error: result.error });
  }
  
  // ==================== 消费记录 ====================
  console.log('\n【消费记录】');
  
  // 19. rpc_get_consume_records
  result = await callRpc('rpc_get_consume_records', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_consume_records');
    results.pass++;
  } else {
    console.log('❌ rpc_get_consume_records:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_consume_records', error: result.error });
  }
  
  // ==================== 预约 ====================
  console.log('\n【预约】');
  
  // 20. rpc_get_appointments
  result = await callRpc('rpc_get_appointments', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_appointments');
    results.pass++;
  } else {
    console.log('❌ rpc_get_appointments:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_appointments', error: result.error });
  }
  
  // ==================== 统计 ====================
  console.log('\n【统计】');
  
  // 21. rpc_revenue_stats
  result = await callRpc('rpc_revenue_stats', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_revenue_stats');
    results.pass++;
  } else {
    console.log('❌ rpc_revenue_stats:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_revenue_stats', error: result.error });
  }
  
  // 22. rpc_member_growth_stats
  result = await callRpc('rpc_member_growth_stats', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_member_growth_stats');
    results.pass++;
  } else {
    console.log('❌ rpc_member_growth_stats:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_member_growth_stats', error: result.error });
  }
  
  // 23. rpc_hot_services_stats
  result = await callRpc('rpc_hot_services_stats', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_hot_services_stats');
    results.pass++;
  } else {
    console.log('❌ rpc_hot_services_stats:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_hot_services_stats', error: result.error });
  }
  
  // ==================== 总结 ====================
  console.log('\n' + '='.repeat(50));
  console.log(`✅ 通过: ${results.pass}/23`);
  console.log(`❌ 失败: ${results.fail}/23`);
  
  if (results.errors.length > 0) {
    console.log('\n错误详情:');
    results.errors.forEach((err, idx) => {
      console.log(`${idx + 1}. ${err.func}: ${err.error}`);
    });
  }
  
  console.log('='.repeat(50));
}

testAllRpc().catch(console.error);
