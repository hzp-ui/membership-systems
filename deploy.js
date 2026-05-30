const fs = require('fs');
const path = require('path');
const https = require('https');

const PROJECT_REF = 'yknvmkzgsoirjfchabov';
const DB_PASS = 'Tb9tJaOkynXZ48d2';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlrbnZta3pnc29pcmpmY2hhYm92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkxNTg0NjksImV4cCI6MjA5NDczNDQ2OX0.1FLE8GXo9Xl43bwjLGC-nvUZ67Q8SVphx__pE4bW4lk';

function execSql(query) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({ query });
    const url = `https://${PROJECT_REF}.supabase.co/rest/v1/rpc`;
    const options = {
      hostname: `${PROJECT_REF}.supabase.co`,
      port: 443,
      path: `/rest/v1/rpc/exec_sql`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${ANON_KEY}`,
        'Content-Length': Buffer.byteLength(data)
      }
    };
    // This won't work - we need a different approach
    reject(new Error('Cannot execute DDL via REST API'));
  });
}

async function runViaPg() {
  // Try Session mode (direct connection, no pooler)
  const { Client } = require('pg');
  const client = new Client({
    host: 'db.yknvmkzgsoirjfchabov.supabase.co',
    port: 5432,
    database: 'postgres',
    user: 'postgres',
    password: DB_PASS,
    ssl: { rejectUnauthorized: false }
  });
  
  await client.connect();
  console.log('Connected!');
  
  const migrationsDir = path.join(__dirname, 'supabase', 'migrations');
  const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql')).sort();
  
  for (const file of files) {
    const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8').replace(/^\uFEFF/, '');
    console.log(`\nExecuting: ${file}`);
    try {
      await client.query(sql);
      console.log(`OK: ${file}`);
    } catch (err) {
      console.error(`ERROR ${file}: ${err.message.split('\n')[0]}`);
    }
  }
  
  const seedSql = fs.readFileSync(path.join(__dirname, 'supabase', 'seed.sql'), 'utf8').replace(/^\uFEFF/, '');
  console.log('\nExecuting: seed.sql');
  try {
    await client.query(seedSql);
    console.log('OK: seed.sql');
  } catch (err) {
    console.error(`ERROR seed.sql: ${err.message.split('\n')[0]}`);
  }
  
  await client.end();
  console.log('\nAll done!');
}

runViaPg().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
