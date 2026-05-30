-- =============================================
-- 修复 rpc_get_stores：p_store_id 也返回数组
-- 之前 p_store_id 非空时返回单条对象，导致前端 .map() 报错
-- =============================================

CREATE OR REPLACE FUNCTION rpc_get_stores(p_store_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO v_result
  FROM (
    SELECT * FROM stores
    WHERE (p_store_id IS NULL OR id = p_store_id)
    ORDER BY created_at DESC
  ) t;
  RETURN jsonb_build_object('data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT '✅ rpc_get_stores 已修复，统一返回数组' AS result;
