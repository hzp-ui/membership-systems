/**
 * @file test_all_rpc.mjs - 全量 RPC 测试脚本
 * @description 测试 Phase 2 改造后的所有 RPC 函数（移除 p_admin_id 参数）
 * @usage node test_all_rpc.mjs
 */

import { createClient } from '@supabase/supabase-js';

// ========== 配置 ==========
const SUPABASE_URL = 'https://yknvmkzgsoirjfchabov.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlrbnZta3pnc29pcmpmY2hhYm92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxNTg0NjksImV4cCI6MjA5NDczNDQ2OX0.1FLE8GXo9Xl43bwjLGC-nvUZ67Q8SVphx__pE4bW4lk';

const sb = createClient(SUPABASE_URL, ANON_KEY);

// ========== 统计 ==========
let passed = 0;
let failed = 0;
let skipped = 0;
const results = [];

// ========== 工具函数 ==========
function log(name, status, detail = '') {
  const icon = { pass: '✅', fail: '❌', skip: '⏭️' }[status];
  console.log(`${icon} ${name}${detail ? ' — ' + detail : ''}`);
  if (status === 'pass') passed++;
  else if (status === 'fail') failed++;
  else skipped++;
  results.push({ name, status, detail });
}

async function rpc(fn, params = {}) {
  const { data, error } = await sb.rpc(fn, params);
  if (error) return { data: null, error };
  if (data?.error) return { data: null, error: new Error(data.error) };
  return { data: data?.data ?? data, error: null };
}

// ========== 登录 ==========
async function login() {
  console.log('🔐 登录认证...\n');
  const { data, error } = await sb.rpc('rpc_admin_login', {
    p_username: 'admin',
    p_password: 'admin123',
  });
  if (error) throw new Error(`登录失败: ${error.message}`);
  if (data?.error) throw new Error(data.error);

  // 设置 JWT Token
  const token = data.data?.token;
  if (!token) throw new Error('登录返回无 token');

  sb.auth.setSession({ access_token: token, refresh_token: '' });
  log('管理员登录 (admin/admin123)', 'pass', `token=${token.substring(0, 20)}...`);
  console.log(`\n当前用户: ${data.data.username} (${data.data.role})\n`);
  return data.data;
}

// ========== 测试用例 ==========
async function runTests(admin) {
  console.log('═══════════════════════════════════════');
  console.log('🧪 开始全量 RPC 测试');
  console.log('═══════════════════════════════════════\n');

  // ---- 1. 辅助函数 ----
  console.log('--- 1. 辅助函数 ---');

  let r = await rpc('rpc_get_current_admin');
  log('rpc_get_current_admin', r.error ? 'fail' : 'pass', r.error?.message || `id=${r.data?.id}`);

  r = await rpc('rpc_get_current_admin_info');
  log('rpc_get_current_admin_info', r.error ? 'fail' : 'pass', r.error?.message || `name=${r.data?.username}`);

  // ---- 2. 门店 CRUD ----
  console.log('\n--- 2. 门店 CRUD ---');

  r = await rpc('rpc_get_stores');
  log('rpc_get_stores', r.error ? 'fail' : 'pass', r.error?.message || `${Array.isArray(r.data) ? r.data.length : 0} 条`);

  // 创建门店（super_admin 可跨门店操作）
  const testStoreName = `测试门店_${Date.now()}`;
  r = await rpc('rpc_create_store', {
    p_name: testStoreName,
    p_address: '测试地址',
    p_phone: '13800000001',
    p_status: 'active',
  });
  const newStoreId = r.data?.[0]?.id;
  log('rpc_create_store', r.error ? 'fail' : 'pass', r.error?.message || `id=${newStoreId}`);

  if (newStoreId) {
    r = await rpc('rpc_update_store', {
      p_store_id: newStoreId,
      p_name: `${testStoreName}_已更新`,
      p_address: '更新地址',
      p_phone: '13800000002',
      p_status: 'active',
    });
    log('rpc_update_store', r.error ? 'fail' : 'pass', r.error?.message || '更新成功');

    // 清理：删除测试门店（通过 SQL 直接删除，因为可能没有 rpc_delete_store）
    await sb.rpc('rpc_delete_store', { p_store_id: newStoreId }).catch(() => {});
  }

  // ---- 3. 管理员 CRUD ----
  console.log('\n--- 3. 管理员 CRUD ---');

  r = await rpc('rpc_get_admins');
  log('rpc_get_admins', r.error ? 'fail' : 'pass', r.error?.message || `${Array.isArray(r.data) ? r.data.length : 0} 条`);

  const testAdminName = `testadmin_${Date.now()}`;
  r = await rpc('rpc_create_admin', {
    p_username: testAdminName,
    p_password: 'Test123456',
    p_display_name: '测试管理员',
    p_role: 'store_admin',
    p_phone: '13900000001',
    p_store_id: admin.store_id,
  });
  const newAdminId = r.data?.[0]?.id;
  log('rpc_create_admin', r.error ? 'fail' : 'pass', r.error?.message || `id=${newAdminId}`);

  if (newAdminId) {
    r = await rpc('rpc_update_admin', {
      p_admin_id: newAdminId,
      p_display_name: '已更新的测试管理员',
      p_phone: '13900000002',
      p_role: 'store_admin',
      p_is_active: true,
    });
    log('rpc_update_admin', r.error ? 'fail' : 'pass', r.error?.message || '更新成功');

    r = await rpc('rpc_delete_admin', { p_admin_id: newAdminId });
    log('rpc_delete_admin', r.error ? 'fail' : 'pass', r.error?.message || '删除成功');
  }

  // ---- 4. 会员 CRUD ----
  console.log('\n--- 4. 会员 CRUD ---');

  r = await rpc('rpc_get_members');
  log('rpc_get_members', r.error ? 'fail' : 'pass', r.error?.message || `${Array.isArray(r.data) ? r.data.length : 0} 条`);

  const testPhone = `138${String(Date.now()).slice(-8)}`;
  r = await rpc('rpc_update_member', {
    p_member_id: (await rpc('rpc_get_members')).data?.[0]?.id,
    p_name: '测试会员更新',
    p_phone: testPhone,
  });
  log('rpc_update_member', r.error ? 'fail' : 'pass', r.error?.message || '更新成功');

  // ---- 5. 理发师 CRUD ----
  console.log('\n--- 5. 理发师 CRUD ---');

  r = await rpc('rpc_get_barbers');
  log('rpc_get_barbers', r.error ? 'fail' : 'pass', r.error?.message || `${Array.isArray(r.data) ? r.data.length : 0} 条`);

  const testBarberName = `测试理发师_${Date.now()}`;
  r = await rpc('rpc_create_barber', {
    p_name: testBarberName,
    p_phone: '13800000003',
    p_specialty: '剪发',
    p_store_id: admin.store_id,
  });
  const newBarberId = r.data?.[0]?.id;
  log('rpc_create_barber', r.error ? 'fail' : 'pass', r.error?.message || `id=${newBarberId}`);

  if (newBarberId) {
    r = await rpc('rpc_update_barber', {
      p_barber_id: newBarberId,
      p_name: `${testBarberName}_已更新`,
      p_phone: '13800000004',
      p_specialty: '剪发+染发',
      p_is_active: true,
    });
    log('rpc_update_barber', r.error ? 'fail' : 'pass', r.error?.message || '更新成功');

    r = await rpc('rpc_delete_barber', { p_barber_id: newBarberId });
    log('rpc_delete_barber', r.error ? 'fail' : 'pass', r.error?.message || '删除成功');
  }

  // ---- 6. 服务项目 CRUD ----
  console.log('\n--- 6. 服务项目 CRUD ---');

  r = await rpc('rpc_get_services');
  log('rpc_get_services', r.error ? 'fail' : 'pass', r.error?.message || `${Array.isArray(r.data) ? r.data.length : 0} 条`);

  const testServiceName = `测试服务_${Date.now()}`;
  r = await rpc('rpc_create_service', {
    p_name: testServiceName,
    p_price: 88,
    p_duration: 60,
    p_type: '其他',
    p_store_id: admin.store_id,
  });
  const newServiceId = r.data?.[0]?.id;
  log('rpc_create_service', r.error ? 'fail' : 'pass', r.error?.message || `id=${newServiceId}`);

  if (newServiceId) {
    r = await rpc('rpc_update_service', {
      p_service_id: newServiceId,
      p_name: `${testServiceName}_已更新`,
      p_price: 128,
      p_duration: 90,
      p_type: '其他',
    });
    log('rpc_update_service', r.error ? 'fail' : 'pass', r.error?.message || '更新成功');

    r = await rpc('rpc_delete_service', { p_service_id: newServiceId });
    log('rpc_delete_service', r.error ? 'fail' : 'pass', r.error?.message || '删除成功');
  }

  // ---- 7. 服务类型 CRUD ----
  console.log('\n--- 7. 服务类型 CRUD ---');

  r = await rpc('rpc_get_service_types');
  log('rpc_get_service_types', r.error ? 'fail' : 'pass', r.error?.message || `${Array.isArray(r.data) ? r.data.length : 0} 条`);

  const testTypeName = `测试类型_${Date.now()}`;
  r = await rpc('rpc_create_service_type', {
    p_name: testTypeName,
    p_store_id: null, // 全局类型
  });
  const newTypeId = r.data?.[0]?.id;
  log('rpc_create_service_type', r.error ? 'fail' : 'pass', r.error?.message || `id=${newTypeId}`);

  if (newTypeId) {
    r = await rpc('rpc_delete_service_type', { p_type_id: newTypeId });
    log('rpc_delete_service_type', r.error ? 'fail' : 'pass', r.error?.message || '删除成功');
  }

  // ---- 8. 充值套餐 CRUD ----
  console.log('\n--- 8. 充值套餐 CRUD ---');

  r = await rpc('rpc_get_packages');
  log('rpc_get_packages', r.error ? 'fail' : 'pass', r.error?.message || `${Array.isArray(r.data) ? r.data.length : 0} 条`);

  const testPkgName = `测试套餐_${Date.now()}`;
  r = await rpc('rpc_create_package', {
    p_name: testPkgName,
    p_amount: 500,
    p_bonus: 50,
    p_store_id: admin.store_id,
  });
  const newPkgId = r.data?.[0]?.id;
  log('rpc_create_package', r.error ? 'fail' : 'pass', r.error?.message || `id=${newPkgId}`);

  if (newPkgId) {
    r = await rpc('rpc_update_package', {
      p_package_id: newPkgId,
      p_name: `${testPkgName}_已更新`,
      p_amount: 888,
      p_bonus: 88,
    });
    log('rpc_update_package', r.error ? 'fail' : 'pass', r.error?.message || '更新成功');

    r = await rpc('rpc_delete_package', { p_package_id: newPkgId });
    log('rpc_delete_package', r.error ? 'fail' : 'pass', r.error?.message || '删除成功');
  }

  // ---- 9. 充值记录 ----
  console.log('\n--- 9. 充值记录 ---');

  r = await rpc('rpc_get_recharge_records');
  log('rpc_get_recharge_records', r.error ? 'fail' : 'pass', r.error?.message || `${Array.isArray(r.data) ? r.data.length : 0} 条`);

  // 获取第一个会员 ID 来测试充值
  const members = (await rpc('rpc_get_members')).data;
  const firstMemberId = members?.[0]?.id;

  if (firstMemberId) {
    r = await rpc('rpc_create_recharge_record', {
      p_member_id: firstMemberId,
      p_amount: 100,
      p_payment_method: '现金',
      p_operator_id: admin.id,
      p_package_id: null,
    });
    log('rpc_create_recharge_record', r.error ? 'fail' : 'pass', r.error?.message || '充值成功');
  } else {
    log('rpc_create_recharge_record', 'skip', '无会员数据');
  }

  // ---- 10. 消费记录 ----
  console.log('\n--- 10. 消费记录 ---');

  r = await rpc('rpc_get_consume_records');
  log('rpc_get_consume_records', r.error ? 'fail' : 'pass', r.error?.message || `${Array.isArray(r.data) ? r.data.length : 0} 条`);

  if (firstMemberId) {
    const services = (await rpc('rpc_get_services')).data;
    const firstServiceId = services?.[0]?.id;
    const barbers = (await rpc('rpc_get_barbers')).data;
    const firstBarberId = barbers?.[0]?.id;

    if (firstServiceId && firstBarberId) {
      r = await rpc('rpc_create_consume_record', {
        p_member_id: firstMemberId,
        p_amount: 50,
        p_service_id: firstServiceId,
        p_barber_id: firstBarberId,
        p_operator_id: admin.id,
        p_remark: '自动化测试消费',
      });
      log('rpc_create_consume_record', r.error ? 'fail' : 'pass', r.error?.message || '消费记录创建成功');
    } else {
      log('rpc_create_consume_record', 'skip', '无服务/理发师数据');
    }
  } else {
    log('rpc_create_consume_record', 'skip', '无会员数据');
  }

  // ---- 11. 预约 CRUD ----
  console.log('\n--- 11. 预约 CRUD ---');

  r = await rpc('rpc_get_appointments');
  log('rpc_get_appointments', r.error ? 'fail' : 'pass', r.error?.message || `${Array.isArray(r.data) ? r.data.length : 0} 条`);

  if (firstMemberId) {
    const services = (await rpc('rpc_get_services')).data;
    const firstServiceId = services?.[0]?.id;
    const barbers = (await rpc('rpc_get_barbers')).data;
    const firstBarberId = barbers?.[0]?.id;

    if (firstServiceId && firstBarberId) {
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(10, 0, 0, 0);

      r = await rpc('rpc_create_appointment', {
        p_member_id: firstMemberId,
        p_appointment_time: tomorrow.toISOString(),
        p_service_id: firstServiceId,
        p_barber_id: firstBarberId,
        p_store_id: admin.store_id,
        p_remark: '自动化测试预约',
      });
      const newAptId = r.data?.[0]?.id;
      log('rpc_create_appointment', r.error ? 'fail' : 'pass', r.error?.message || `id=${newAptId}`);

      if (newAptId) {
        r = await rpc('rpc_confirm_appointment', { p_appointment_id: newAptId });
        log('rpc_confirm_appointment', r.error ? 'fail' : 'pass', r.error?.message || '确认成功');

        r = await rpc('rpc_complete_appointment', { p_appointment_id: newAptId });
        log('rpc_complete_appointment', r.error ? 'fail' : 'pass', r.error?.message || '完成成功');
      }
    } else {
      log('rpc_create_appointment', 'skip', '无服务/理发师数据');
    }
  } else {
    log('rpc_create_appointment', 'skip', '无会员数据');
  }

  // ---- 12. 统计函数 ----
  console.log('\n--- 12. 统计函数 ---');

  r = await rpc('rpc_revenue_stats', { p_start_date: '2026-01-01', p_end_date: '2026-12-31' });
  log('rpc_revenue_stats', r.error ? 'fail' : 'pass', r.error?.message || '有数据返回');

  r = await rpc('rpc_member_growth_stats', { p_start_date: '2026-01-01', p_end_date: '2026-12-31' });
  log('rpc_member_growth_stats', r.error ? 'fail' : 'pass', r.error?.message || '有数据返回');

  r = await rpc('rpc_hot_services_stats', { p_start_date: '2026-01-01', p_end_date: '2026-12-31', p_limit: 10 });
  log('rpc_hot_services_stats', r.error ? 'fail' : 'pass', r.error?.message || '有数据返回');

  // ---- 13. 认证相关 ----
  console.log('\n--- 13. 认证相关 ---');

  r = await rpc('rpc_change_password', {
    p_old_password: 'admin123',
    p_new_password: 'admin123',
  });
  log('rpc_change_password', r.error ? 'fail' : 'pass', r.error?.message || '密码修改成功（相同密码）');

  // ---- 14. 积分（如果有） ----
  console.log('\n--- 14. 其他函数 ---');

  r = await rpc('rpc_check_store_access_v2', { p_store_id: admin.store_id });
  log('rpc_check_store_access_v2', r.error ? 'fail' : 'pass', r.error?.message || `has_access=${r.data}`);

  // ========== 结果汇总 ==========
  console.log('\n═══════════════════════════════════════');
  console.log('📊 测试结果汇总');
  console.log('═══════════════════════════════════════');
  console.log(`✅ 通过: ${passed}`);
  console.log(`❌ 失败: ${failed}`);
  console.log(`⏭️  跳过: ${skipped}`);
  console.log(`📈 总计: ${passed + failed + skipped}\n`);

  if (failed > 0) {
    console.log('❌ 失败的测试:');
    results.filter(r => r.status === 'fail').forEach(({ name, detail }) => {
      console.log(`   ❌ ${name}: ${detail}`);
    });
  }

  console.log('\n测试完成！');
}

// ========== 主流程 ==========
async function main() {
  try {
    const admin = await login();
    await runTests(admin);
  } catch (err) {
    console.error('💥 测试异常:', err.message);
    process.exit(1);
  }
}

main();
