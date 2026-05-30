import { createClient } from '@supabase/supabase-js';

const sb = createClient(
  'https://yknvmkzgsoirjfchabov.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlrbnZta3pnc29pcmpmY2hhYm92Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTE1ODQ2OSwiZXhwIjoyMDk0NzM0NDY5fQ.vhWyPfQGxQYkP3ApPtsayb5kq4uChngbo2l-iehbbI8',
  { auth: { autoRefreshToken: false, persistSession: false } }
);

async function backfill() {
  console.log('=== 回填 auth_user_id ===\n');

  // 1. 获取所有 auth.users
  const { data: authData, error: authErr } = await sb.auth.admin.listUsers();
  if (authErr) {
    console.error('获取 auth.users 失败:', authErr.message);
    return;
  }

  const users = authData.users || [];
  console.log(`auth.users 共 ${users.length} 条记录`);

  // 2. 构建 email → id 映射
  const emailToId = {};
  users.forEach(u => {
    emailToId[u.email] = u.id;
  });

  // 3. 回填 admins
  const { data: admins, error: adminErr } = await sb.from('admins').select('id, username');
  if (adminErr) {
    console.error('查询 admins 失败:', adminErr.message);
    return;
  }

  let adminUpdated = 0;
  for (const admin of admins) {
    const email = `${admin.username}@membership.internal`;
    const authUserId = emailToId[email];
    if (!authUserId) {
      console.log(`跳过 ${admin.username}（auth.users 中不存在）`);
      continue;
    }

    const { error: updateErr } = await sb.from('admins').update({ auth_user_id: authUserId }).eq('id', admin.id);
    if (updateErr) {
      console.error(`更新 ${admin.username} 失败:`, updateErr.message);
    } else {
      console.log(`✓ ${admin.username} → ${authUserId}`);
      adminUpdated++;
    }
  }

  // 4. 回填 members
  const { data: members, error: memberErr } = await sb.from('members').select('id, phone, store_id');
  if (memberErr) {
    console.error('查询 members 失败:', memberErr.message);
    return;
  }

  let memberUpdated = 0;
  for (const member of members) {
    const email = `${member.phone}_${member.store_id}@membership.internal`;
    const authUserId = emailToId[email];
    if (!authUserId) continue;

    const { error: updateErr } = await sb.from('members').update({ auth_user_id: authUserId }).eq('id', member.id);
    if (!updateErr) {
      memberUpdated++;
    }
  }

  console.log(`\n✅ 回填完成: ${adminUpdated} 管理员, ${memberUpdated} 会员`);
}

backfill().catch(console.error);
