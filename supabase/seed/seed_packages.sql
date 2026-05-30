-- 插入测试用充值套餐数据
-- 用于 RPC 回归测试中的 recharge 测试

INSERT INTO recharge_packages (id, name, amount, bonus, store_id, status, created_at)
VALUES 
    ('p0000000-0000-0000-0000-000000000001', '测试套餐-500送100', 500, 100, 'a0000000-0000-0000-0000-000000000001', 'active', NOW()),
    ('p0000000-0000-0000-0000-000000000002', '测试套餐-1000送300', 1000, 300, 'a0000000-0000-0000-0000-000000000001', 'active', NOW()),
    ('p0000000-0000-0000-0000-000000000003', '测试套餐-2000送800', 2000, 800, 'a0000000-0000-0000-0000-000000000001', 'active', NOW())
ON CONFLICT (id) DO NOTHING;

-- 验证插入结果
SELECT id, name, amount, bonus, store_id, status FROM recharge_packages ORDER BY amount;
