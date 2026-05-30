-- 12_service_types.sql
-- 动态服务类型表 + 修改 services.type 为 TEXT

-- 1. 创建服务类型表
CREATE TABLE IF NOT EXISTS service_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(name, store_id)
);

-- 2. 修改 services.type 从 enum 改为 TEXT
-- 先删除 enum 约束（如果存在）
ALTER TABLE services ALTER COLUMN type TYPE TEXT USING type::text;

-- 3. 插入默认服务类型（所有门店通用，store_id 为 NULL 表示全局类型）
INSERT INTO service_types (name, store_id) VALUES
  ('洗发', NULL),
  ('剪发', NULL),
  ('染发', NULL),
  ('烫发', NULL),
  ('护理', NULL)
ON CONFLICT (name, store_id) DO NOTHING;


