import { createClient } from '@supabase/supabase-js';

const sb = createClient(
  'https://yknvmkzgsoirjfchabov.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlrbnZta3pnc29pcmpmY2hhYm92Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTE1ODQ2OSwiZXhwIjoyMDk0NzM0NDY5fQ.vhWyPfQGxQYkP3ApPtsayb5kq4uChngbo2l-iehbbI8'
);

async function check() {
  // 检查 admins 表的 auth_user_id 列
  const { data: admins, error: adminErr } = await sb.from('admins').select('id, username, auth_user_id');
  if (adminErr) {
    console.error('Admins query error:', adminErr.message);
  } else {
    console.log('Admins:', JSON.stringify(admins, null, 2));
  }

  // 检查 members 表的 auth_user_id 列
  const { data: members, error: memberErr } = await sb.from('members').select('id, phone, auth_user_id').limit(3);
  if (memberErr) {
    console.error('Members query error:', memberErr.message);
  } else {
    console.log('Members (sample):', JSON.stringify(members, null, 2));
  }

  // 检查 auth.users 中是否有管理员
  const { data: users, error: userErr } = await sb.auth.admin.listUsers();
  if (userErr) {
    console.error('Auth users error:', userErr.message);
  } else {
    console.log('Auth users count:', users.users.length);
    users.users.forEach(u => console.log('  -', u.email, u.id));
  }
}

check().catch(console.error);
