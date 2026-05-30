-- 迁移 services.type 英文枚举值 → 中文
-- 适用于 12_service_types.sql 执行前的旧数据

UPDATE services SET type = '洗发' WHERE type = 'wash';
UPDATE services SET type = '剪发' WHERE type = 'cut';
UPDATE services SET type = '染发' WHERE type = 'color';
UPDATE services SET type = '烫发' WHERE type = 'perm';
UPDATE services SET type = '护理' WHERE type = 'treatment';
UPDATE services SET type = '其他' WHERE type = 'other';

-- 验证
SELECT id, name, type FROM services;
