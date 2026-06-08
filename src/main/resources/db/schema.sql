-- 理发店会员管理系统 MySQL DDL
-- 对齐 Supabase PostgreSQL 原始表结构
-- membership database (create manually)

-- 门店表
CREATE TABLE IF NOT EXISTS stores (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    address VARCHAR(500),
    phone VARCHAR(20),
    manager VARCHAR(50),
    status VARCHAR(20) DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 管理员表
CREATE TABLE IF NOT EXISTS admins (
    id VARCHAR(36) PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(50) NOT NULL,
    phone VARCHAR(20),
    role VARCHAR(20) NOT NULL DEFAULT 'store_admin',
    store_id VARCHAR(36),
    status VARCHAR(20) DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_admins_store_id (store_id),
    INDEX idx_admins_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 会员表
CREATE TABLE IF NOT EXISTS members (
    id VARCHAR(36) PRIMARY KEY,
    phone VARCHAR(20) NOT NULL,
    password_hash VARCHAR(255),
    name VARCHAR(50) NOT NULL,
    level VARCHAR(20) DEFAULT 'normal',
    balance DECIMAL(10,2) DEFAULT 0.00,
    points BIGINT DEFAULT 0,
    store_id VARCHAR(36),
    status VARCHAR(20) DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE INDEX idx_members_phone_store (phone, store_id),
    INDEX idx_members_store_id (store_id),
    INDEX idx_members_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 理发师表
CREATE TABLE IF NOT EXISTS barbers (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    phone VARCHAR(20),
    specialties TEXT,
    status VARCHAR(20) DEFAULT 'active',
    store_id VARCHAR(36),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_barbers_store_id (store_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 服务类型表
CREATE TABLE IF NOT EXISTS service_types (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    store_id VARCHAR(36),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 服务项目表
CREATE TABLE IF NOT EXISTS services (
    id VARCHAR(36) PRIMARY KEY,
    type VARCHAR(50),
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    discount_normal DECIMAL(3,2) DEFAULT 1.00,
    discount_silver DECIMAL(3,2) DEFAULT 0.95,
    discount_gold DECIMAL(3,2) DEFAULT 0.90,
    discount_diamond DECIMAL(3,2) DEFAULT 0.80,
    store_id VARCHAR(36),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_services_type (type),
    INDEX idx_services_store_id (store_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 充值套餐表
CREATE TABLE IF NOT EXISTS recharge_packages (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    bonus DECIMAL(10,2) DEFAULT 0.00,
    status VARCHAR(20) DEFAULT 'active',
    store_id VARCHAR(36),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 充值记录表
CREATE TABLE IF NOT EXISTS recharge_records (
    id VARCHAR(36) PRIMARY KEY,
    member_id VARCHAR(36) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    bonus DECIMAL(10,2) DEFAULT 0.00,
    package_name VARCHAR(100),
    store_id VARCHAR(36),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_recharge_member_id (member_id),
    INDEX idx_recharge_store_id (store_id),
    INDEX idx_recharge_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 消费记录表
CREATE TABLE IF NOT EXISTS consumption_records (
    id VARCHAR(36) PRIMARY KEY,
    member_id VARCHAR(36) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    original_price DECIMAL(10,2),
    discount DECIMAL(3,2),
    service_name VARCHAR(100),
    barber_name VARCHAR(50),
    points_earned INT DEFAULT 0,
    store_id VARCHAR(36),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_consumption_member_id (member_id),
    INDEX idx_consumption_store_id (store_id),
    INDEX idx_consumption_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 预约表
CREATE TABLE IF NOT EXISTS appointments (
    id VARCHAR(36) PRIMARY KEY,
    member_id VARCHAR(36) NOT NULL,
    barber_id VARCHAR(36) NOT NULL,
    service_id VARCHAR(36),
    appointment_time DATETIME NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    store_id VARCHAR(36),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_appointment_member_id (member_id),
    INDEX idx_appointment_barber_id (barber_id),
    INDEX idx_appointment_store_id (store_id),
    INDEX idx_appointment_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 登录尝试表（限流用）
CREATE TABLE IF NOT EXISTS login_attempts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    phone VARCHAR(50) NOT NULL,
    success TINYINT(1) NOT NULL,
    ip_address VARCHAR(45),
    attempt_time DATETIME NOT NULL,
    INDEX idx_login_phone_time (phone, attempt_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 审计日志表
CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(36),
    user_role VARCHAR(20),
    action VARCHAR(50) NOT NULL,
    target_type VARCHAR(50),
    target_id VARCHAR(36),
    detail TEXT,
    store_id VARCHAR(36),
    ip_address VARCHAR(45),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_user_id (user_id),
    INDEX idx_audit_action (action),
    INDEX idx_audit_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================
-- 种子数据
-- =====================

INSERT INTO stores (id, name, address, phone, manager, status) VALUES
('store-001', '国贸分店', '深圳市罗湖区国贸大厦1楼', '0755-12345678', '张经理', 'active'),
('store-002', '南山分店', '深圳市南山区科技园南路8号', '0755-87654321', '李经理', 'active');

-- 密码: admin123 (bcrypt hash)
INSERT INTO admins (id, username, password_hash, name, phone, role, store_id, status) VALUES
('admin-001', 'admin', '$2b$10$9lfS1Z1uNM8Insyaoaph1ufJDoqRl64lZuunJymJjwSQriwv9.LnS', '超级管理员', '13800000000', 'super_admin', NULL, 'active'),
('admin-002', 'admin1', '$2b$10$9lfS1Z1uNM8Insyaoaph1ufJDoqRl64lZuunJymJjwSQriwv9.LnS', '国贸店长', '13800000001', 'store_admin', 'store-001', 'active');

INSERT INTO service_types (id, name, store_id) VALUES
('stype-001', '剪发', NULL),
('stype-002', '染发', NULL),
('stype-003', '烫发', NULL),
('stype-004', '护理', NULL);

INSERT INTO services (id, type, name, price, discount_normal, discount_silver, discount_gold, discount_diamond, store_id) VALUES
('svc-001', '剪发', '男士精剪', 68.00, 1.00, 0.95, 0.90, 0.80, NULL),
('svc-002', '剪发', '女士精剪', 98.00, 1.00, 0.95, 0.90, 0.80, NULL),
('svc-003', '染发', '时尚染发', 198.00, 1.00, 0.95, 0.90, 0.80, NULL),
('svc-004', '烫发', '冷烫', 268.00, 1.00, 0.95, 0.90, 0.80, NULL),
('svc-005', '护理', '深层护理', 128.00, 1.00, 0.95, 0.90, 0.80, NULL);

INSERT INTO recharge_packages (id, name, amount, bonus, status, store_id) VALUES
('pkg-001', '充200送20', 200.00, 20.00, 'active', NULL),
('pkg-002', '充500送80', 500.00, 80.00, 'active', NULL),
('pkg-003', '充1000送200', 1000.00, 200.00, 'active', NULL);

INSERT INTO barbers (id, name, phone, specialties, status, store_id) VALUES
('barber-001', 'Tony老师', '13900000001', '剪发,烫发', 'active', 'store-001'),
('barber-002', 'Kevin老师', '13900000002', '染发,护理', 'active', 'store-001'),
('barber-003', 'Amy老师', '13900000003', '剪发,染发', 'active', 'store-002');
