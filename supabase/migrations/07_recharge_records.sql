-- 充值记录表
CREATE TABLE recharge_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES members(id),
  amount DECIMAL(10, 2) NOT NULL,
  bonus DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  package_name VARCHAR(100),
  store_id UUID NOT NULL REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE recharge_records IS '充值记录表';
COMMENT ON COLUMN recharge_records.amount IS '充值金额';
COMMENT ON COLUMN recharge_records.bonus IS '赠送金额';

CREATE INDEX idx_recharge_records_member ON recharge_records(member_id);
CREATE INDEX idx_recharge_records_store ON recharge_records(store_id);
CREATE INDEX idx_recharge_records_created ON recharge_records(created_at);
