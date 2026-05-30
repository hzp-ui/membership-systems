const { Client } = require('pg');
const c = new Client({
  host: 'db.yknvmkzgsoirjfchabov.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'Tb9tJaOkynXZ48d2',
  ssl: { rejectUnauthorized: false }
});

async function run() {
  await c.connect();
  const r = await c.query("SELECT proname FROM pg_proc WHERE proname = 'rpc_custom_recharge'");
  console.log('RPC exists:', r.rows.length > 0 ? 'YES' : 'NO');
  if (r.rows.length === 0) {
    console.log('Creating rpc_custom_recharge...');
    await c.query(`
CREATE OR REPLACE FUNCTION rpc_custom_recharge(p_member_id UUID, p_amount DECIMAL, p_bonus DECIMAL DEFAULT 0)
RETURNS JSONB AS $$
DECLARE
  v_member RECORD;
BEGIN
  SELECT * INTO v_member FROM members WHERE id = p_member_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', '会员不存在');
  END IF;
  UPDATE members SET balance = balance + p_amount + p_bonus WHERE id = p_member_id;
  INSERT INTO recharge_records (member_id, amount, bonus, package_name, store_id)
  VALUES (p_member_id, p_amount, p_bonus, '自定义充值', v_member.store_id);
  RETURN jsonb_build_object('data', jsonb_build_object(
    'new_balance', v_member.balance + p_amount + p_bonus,
    'recharge_amount', p_amount,
    'bonus', p_bonus
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
    `);
    console.log('OK: rpc_custom_recharge created');
  }
  await c.end();
}
run().catch(e => { console.error(e.message); process.exit(1); });
