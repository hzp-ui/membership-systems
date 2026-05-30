const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: 'E:\\学习\\会员系统\\MmbershipWeb\\.env' });

const supabase = createClient(process.env.VITE_SUPABASE_URL, process.env.VITE_SUPABASE_ANON_KEY);

async function testAllRpc() {
  console.log('=== RPC 函数测试 v3（修正参数）===\n');
  
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
  
  // ==================== 管理员 CRUD ====================
  console.log('\n【管理员 CRUD】');
  
  // 5. rpc_get_admins
  result = await callRpc('rpc_get_admins', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_admins');
    results.pass++;
  } else {
    console.log('❌ rpc_get_admins:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_admins', error: result.error });
  }
  
  // 6. rpc_create_admin (参数：p_username, p_password, p_name, p_phone, p_role, p_store_id)
  result = await callRpc('rpc_create_admin', {
    p_username: 'testadmin',
    p_password: 'test123',
    p_name: '测试管理员',
    p_phone: '13700137000',
    p_role: 'store_admin',
    p_store_id: currentStoreId
  });
  if (result.success) {
    console.log('✅ rpc_create_admin');
    const admin = result.data?.data;
    if (admin) {
      console.log(`   新管理员ID: ${admin.id}`);
    }
    results.pass++;
  } else {
    console.log('❌ rpc_create_admin:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_create_admin', error: result.error });
  }
  
  // ==================== 会员 CRUD ====================
  console.log('\n【会员 CRUD】');
  
  // 7. rpc_get_members
  result = await callRpc('rpc_get_members', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_members');
    results.pass++;
  } else {
    console.log('❌ rpc_get_members:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_members', error: result.error });
  }
  
  // 8. rpc_create_member (参数：p_phone, p_name, p_store_id, p_level)
  result = await callRpc('rpc_create_member', {
    p_phone: '13600136000',
    p_name: '测试会员',
    p_store_id: currentStoreId,
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
  
  // 9. rpc_update_member (参数：p_id, p_name, p_phone, p_level, p_points, p_balance, p_status)
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
  
  // 10. rpc_get_barbers
  result = await callRpc('rpc_get_barbers', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_barbers');
    results.pass++;
  } else {
    console.log('❌ rpc_get_barbers:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_barbers', error: result.error });
  }
  
  // 11. rpc_create_barber (参数：p_name, p_phone, p_specialties, p_store_id)
  result = await callRpc('rpc_create_barber', {
    p_name: '测试理发师',
    p_phone: '13500135000',
    p_specialties: JSON.stringify(['洗发', '剪发']), // JSONB 格式
    p_store_id: currentStoreId
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
  
  // ==================== 服务项目 CRUD ====================
  console.log('\n【服务项目 CRUD】');
  
  // 12. rpc_get_services
  result = await callRpc('rpc_get_services', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_services');
    results.pass++;
  } else {
    console.log('❌ rpc_get_services:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_services', error: result.error });
  }
  
  // 13. rpc_create_service (参数：p_type, p_name, p_price, p_discount_*, p_store_id)
  result = await callRpc('rpc_create_service', {
    p_type: '洗剪吹',
    p_name: '精致洗剪吹',
    p_price: 68.00,
    p_discount_normal: 1.0,
    p_discount_silver: 0.9,
    p_discount_gold: 0.8,
    p_discount_diamond: 0.7,
    p_store_id: currentStoreId
  });
  if (result.success) {
    console.log('✅ rpc_create_service');
    const service = result.data?.data;
    if (service) {
      currentServiceId = service.id;
      console.log(`   新服务ID: ${currentServiceId}`);
    }
    results.pass++;
  } else {
    console.log('❌ rpc_create_service:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_create_service', error: result.error });
  }
  
  // ==================== 服务类型 CRUD ====================
  console.log('\n【服务类型 CRUD】');
  
  // 14. rpc_get_service_types
  result = await callRpc('rpc_get_service_types', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_service_types');
    results.pass++;
  } else {
    console.log('❌ rpc_get_service_types:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_service_types', error: result.error });
  }
  
  // 15. rpc_create_service_type
  result = await callRpc('rpc_create_service_type', {
    p_name: '新服务类型',
    p_store_id: currentStoreId
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
  
  // 16. rpc_get_packages
  result = await callRpc('rpc_get_packages', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_get_packages');
    results.pass++;
  } else {
    console.log('❌ rpc_get_packages:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_get_packages', error: result.error });
  }
  
  // 17. rpc_create_package (参数：p_name, p_amount, p_bonus, p_status, p_store_id)
  result = await callRpc('rpc_create_package', {
    p_name: '测试套餐',
    p_amount: 500.00,
    p_bonus: 50.00,
    p_status: 'active',
    p_store_id: currentStoreId
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
  
  // 18. rpc_create_recharge_record
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
  
  // 19. rpc_get_recharge_records
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
  
  // 20. rpc_create_consume_record
  if (currentMemberId && currentServiceId) {
    result = await callRpc('rpc_create_consume_record', {
      p_member_id: currentMemberId,
      p_amount: 68.00,
      p_original_price: 68.00,
      p_service_name: '精致洗剪吹',
      p_barber_name: '测试理发师',
      p_store_id: currentStoreId
    });
    if (result.success) {
      console.log('✅ rpc_create_consume_record');
      results.pass++;
    } else {
      console.log('❌ rpc_create_consume_record:', result.error);
      results.fail++;
      results.errors.push({ func: 'rpc_create_consume_record', error: result.error });
    }
  }
  
  // 21. rpc_get_consume_records
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
  
  // 22. rpc_create_appointment
  if (currentMemberId && currentBarberId && currentServiceId) {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(10, 0, 0, 0);
    
    result = await callRpc('rpc_create_appointment', {
      p_member_id: currentMemberId,
      p_barber_id: currentBarberId,
      p_service_id: currentServiceId,
      p_appointment_time: tomorrow.toISOString()
    });
    if (result.success) {
      console.log('✅ rpc_create_appointment');
      results.pass++;
    } else {
      console.log('❌ rpc_create_appointment:', result.error);
      results.fail++;
      results.errors.push({ func: 'rpc_create_appointment', error: result.error });
    }
  }
  
  // 23. rpc_get_appointments
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
  
  // 24. rpc_revenue_stats
  result = await callRpc('rpc_revenue_stats', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_revenue_stats');
    results.pass++;
  } else {
    console.log('❌ rpc_revenue_stats:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_revenue_stats', error: result.error });
  }
  
  // 25. rpc_member_growth_stats
  result = await callRpc('rpc_member_growth_stats', { p_store_id: null });
  if (result.success) {
    console.log('✅ rpc_member_growth_stats');
    results.pass++;
  } else {
    console.log('❌ rpc_member_growth_stats:', result.error);
    results.fail++;
    results.errors.push({ func: 'rpc_member_growth_stats', error: result.error });
  }
  
  // 26. rpc_hot_services_stats
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
  console.log(`✅ 通过: ${results.pass}/26`);
  console.log(`❌ 失败: ${results.fail}/26`);
  
  if (results.errors.length > 0) {
    console.log('\n错误详情:');
    results.errors.forEach((err, idx) => {
      console.log(`${idx + 1}. ${err.func}: ${err.error}`);
    });
  }
  
  console.log('='.repeat(50));
}

testAllRpc().catch(console.error);
