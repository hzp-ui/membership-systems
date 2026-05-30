import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://yknvmkzgsoirjfchabov.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlrbnZta3pnc29pcmpmY2hhYm92Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTE1ODQ2OSwiZXhwIjoyMDk0NzM0NDY5fQ.vhWyPfQGxQYkP3ApPtsayb5kq4uChngbo2l-iehbbI8';

const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

// 密码映射（根据seed数据）
const PASSWORDS = {
  'superadmin': 'admin123',
  'admin': 'admin123',
  'store_admin_1': 'store123',
  'zhang_manager': 'store123',
  'li_manager': 'store123',
  'default': 'TempPass123!'
};

async function migrateAdmins() {
  console.log('=== 开始迁移管理员到 auth.users ===\n');

  const { data: admins, error } = await sb.from('admins').select('id, username, auth_user_id');
  if (error) {
    console.error('查询失败:', error.message);
    return;
  }

  let created = 0, skipped = 0, failed = 0;

  for (const admin of admins) {
    if (admin.auth_user_id) {
      console.log(`✓ 跳过 ${admin.username}（已有 auth_user_id）`);
      skipped++;
      continue;
    }

    const email = `${admin.username}@membership.internal`;
    const password = PASSWORDS[admin.username] || PASSWORDS['default'];

    // 检查是否已存在
    const { data: existing } = await sb.auth.admin.listUsers();
    const found = existing?.users?.find(u => u.email === email);
    if (found) {
      console.log(`✓ 跳过 ${admin.username}（auth.users 已存在）`);
      await sb.from('admins').update({ auth_user_id: found.id }).eq('id', admin.id);
      skipped++;
      continue;
    }

    // 创建 auth.users
    const { data: user, error: createErr } = await sb.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { admin_id: admin.id, username: admin.username }
    });

    if (createErr) {
      console.error(`✗ 创建失败 ${admin.username}:`, createErr.message);
      failed++;
      continue;
    }

    // 回填 auth_user_id
    const { error: updateErr } = await sb.from('admins').update({ auth_user_id: user.id }).eq('id', admin.id);
    if (updateErr) {
      console.error(`✗ 回填失败 ${admin.username}:`, updateErr.message);
      failed++;
    } else {
      console.log(`✓ 迁移成功: ${admin.username} → ${user.id}`);
      created++;
    }
  }

  console.log(`\n=== 迁移完成: ${created} 创建, ${skipped} 跳过, ${failed} 失败 ===`);
}

async function migrateMembers() {
  console.log('\n=== 开始迁移会员到 auth.users ===\n');

  const { data: members, error } = await sb.from('members').select('id, phone, store_id, auth_user_id').limit(100);
  if (error) {
    console.error('查询失败:', error.message);
    return;
  }

  let created = 0, skipped = 0;

  for (const member of members) {
    if (member.auth_user_id) {
      skipped++;
      continue;
    }

    const email = `${member.phone}_${member.store_id}@membership.internal`;
    const password = `Member_${member.id.toString().slice(0, 8)}!`;

    const { data: user, error: createErr } = await sb.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { member_id: member.id, phone: member.phone }
    });

    if (createErr) {
      if (createErr.message?.includes('already')) {
        skipped++;
        continue;
      }
      console.error(`创建失败 ${member.phone}:`, createErr.message);
      continue;
    }

    await sb.from('members').update({ auth_user_id: user.id }).eq('id', member.id);
    console.log(`✓ 会员: ${member.phone} → ${user.id}`);
    created++;
  }

  console.log(`\n=== 会员迁移: ${created} 创建, ${skipped} 跳过 ===`);
}

// 先迁管理员，再迁会员
await migrateAdmins();
await migrateMembers();

console.log('\n✅ Phase 1 完成');
