const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const client = new Client({
  host: 'db.yknvmkzgsoirjfchabov.supabase.co',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'Tb9tJaOkynXZ48d2',
  ssl: { rejectUnauthorized: false }
});

async function run() {
  await client.connect();
  console.log('Connected');

  const sql = fs.readFileSync(path.join(__dirname, 'supabase', 'rpc_functions.sql'), 'utf8').replace(/^\uFEFF/, '');
  try {
    await client.query(sql);
    console.log('OK: rpc_functions.sql - All 14 RPC functions created!');
  } catch (err) {
    console.error('ERROR:', err.message);
  }

  await client.end();
}

run().catch(err => { console.error('Connection error:', err.message); process.exit(1); });
