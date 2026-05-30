-- 充值套餐表
CREATE TABLE recharge_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  amount DECIMAL(10, 2) NOT NULL,
  bonus DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  store_id UUID NOT NULL REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE recharge_packages IS '充值套餐表';
COMMENT ON COLUMN recharge_packages.amount IS '充值金额';
COMMENT ON COLUMN recharge_packages.bonus IS '赠送金额';

CREATE INDEX idx_recharge_packages_store ON recharge_packages(store_id);
