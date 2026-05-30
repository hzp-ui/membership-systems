-- 消费记录表
CREATE TABLE consumption_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES members(id),
  amount DECIMAL(10, 2) NOT NULL,
  original_price DECIMAL(10, 2) NOT NULL,
  discount DECIMAL(3, 2) NOT NULL,
  service_id UUID NOT NULL REFERENCES services(id),
  service_name VARCHAR(100) NOT NULL,
  barber_id UUID REFERENCES barbers(id),
  barber_name VARCHAR(50),
  points_earned INT NOT NULL DEFAULT 0,
  store_id UUID NOT NULL REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE consumption_records IS '消费记录表';
COMMENT ON COLUMN consumption_records.amount IS '实际消费金额(折扣后)';
COMMENT ON COLUMN consumption_records.original_price IS '服务原价';
COMMENT ON COLUMN consumption_records.discount IS '使用的折扣率';
COMMENT ON COLUMN consumption_records.points_earned IS '获得的积分';

CREATE INDEX idx_consumption_records_member ON consumption_records(member_id);
CREATE INDEX idx_consumption_records_store ON consumption_records(store_id);
CREATE INDEX idx_consumption_records_created ON consumption_records(created_at);
CREATE INDEX idx_consumption_records_service ON consumption_records(service_id);
