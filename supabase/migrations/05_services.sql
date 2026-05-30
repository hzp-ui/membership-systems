-- 服务项目表
CREATE TYPE service_type AS ENUM ('wash', 'cut', 'color', 'perm', 'treatment', 'other');

CREATE TABLE services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type service_type NOT NULL,
  name VARCHAR(100) NOT NULL,
  price DECIMAL(10, 2) NOT NULL,
  discount_normal DECIMAL(3, 2) NOT NULL DEFAULT 1.00,
  discount_silver DECIMAL(3, 2) NOT NULL DEFAULT 0.95,
  discount_gold DECIMAL(3, 2) NOT NULL DEFAULT 0.90,
  discount_diamond DECIMAL(3, 2) NOT NULL DEFAULT 0.80,
  store_id UUID NOT NULL REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE services IS '服务项目表';
COMMENT ON COLUMN services.type IS '服务类型: wash=洗发, cut=剪发, color=染发, perm=烫发, treatment=护理, other=其他';
COMMENT ON COLUMN services.price IS '原价';
COMMENT ON COLUMN services.discount_normal IS '普通会员折扣(0-1)';
COMMENT ON COLUMN services.discount_silver IS '银卡会员折扣(0-1)';
COMMENT ON COLUMN services.discount_gold IS '金卡会员折扣(0-1)';
COMMENT ON COLUMN services.discount_diamond IS '钻石会员折扣(0-1)';

CREATE INDEX idx_services_store ON services(store_id);
CREATE INDEX idx_services_type ON services(type);
