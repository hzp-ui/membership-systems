-- 理发师表
CREATE TABLE barbers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) NOT NULL,
  phone VARCHAR(20),
  specialties TEXT[],
  status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  store_id UUID NOT NULL REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE barbers IS '理发师表';
COMMENT ON COLUMN barbers.specialties IS '擅长服务项目';
COMMENT ON COLUMN barbers.status IS '在职状态: active=在职, inactive=离职';

CREATE INDEX idx_barbers_store ON barbers(store_id);
CREATE INDEX idx_barbers_status ON barbers(status);
