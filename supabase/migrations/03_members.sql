-- 会员表
CREATE TABLE members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone VARCHAR(20) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(50),
  level VARCHAR(20) NOT NULL DEFAULT 'normal' CHECK (level IN ('normal', 'silver', 'gold', 'diamond')),
  points INT NOT NULL DEFAULT 0,
  balance DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  store_id UUID NOT NULL REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uk_members_phone_store UNIQUE (phone, store_id)
);

COMMENT ON TABLE members IS '会员表';
COMMENT ON COLUMN members.level IS '会员等级: normal=普通, silver=银卡, gold=金卡, diamond=钻石';
COMMENT ON COLUMN members.points IS '积分';
COMMENT ON COLUMN members.balance IS '余额';

CREATE INDEX idx_members_store ON members(store_id);
CREATE INDEX idx_members_level ON members(level);
CREATE INDEX idx_members_phone ON members(phone);
