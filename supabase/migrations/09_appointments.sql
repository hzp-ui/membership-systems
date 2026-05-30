-- 预约表
CREATE TABLE appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES members(id),
  barber_id UUID NOT NULL REFERENCES barbers(id),
  service_id UUID NOT NULL REFERENCES services(id),
  appointment_time TIMESTAMPTZ NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
  store_id UUID NOT NULL REFERENCES stores(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE appointments IS '预约表';
COMMENT ON COLUMN appointments.status IS '预约状态: pending=待确认, confirmed=已确认, completed=已完成, cancelled=已取消';

CREATE INDEX idx_appointments_member ON appointments(member_id);
CREATE INDEX idx_appointments_barber ON appointments(barber_id);
CREATE INDEX idx_appointments_store ON appointments(store_id);
CREATE INDEX idx_appointments_status ON appointments(status);
CREATE INDEX idx_appointments_time ON appointments(appointment_time);
