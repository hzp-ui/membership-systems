-- 管理员表（超级管理员 + 店长）
CREATE TABLE admins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(50) NOT NULL,
  phone VARCHAR(20),
  role VARCHAR(20) NOT NULL CHECK (role IN ('super_admin', 'store_admin')),
  store_id UUID REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_admins_store FOREIGN KEY (store_id) REFERENCES stores(id),
  CONSTRAINT store_admin_must_have_store CHECK (
    (role = 'store_admin' AND store_id IS NOT NULL) OR
    (role = 'super_admin' AND store_id IS NULL)
  )
);

COMMENT ON TABLE admins IS '管理员表';
COMMENT ON COLUMN admins.role IS '角色: super_admin=超级管理员, store_admin=店长';

CREATE INDEX idx_admins_role ON admins(role);
CREATE INDEX idx_admins_store ON admins(store_id);
