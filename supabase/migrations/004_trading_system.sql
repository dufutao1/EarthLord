-- ==========================================
-- 交易系统数据层
-- ==========================================

-- 1. 交易挂单表
CREATE TABLE IF NOT EXISTS trade_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    owner_username TEXT,

    -- 交易内容（JSON 格式）
    -- 格式: [{"item_id": "wood", "quantity": 10}, ...]
    offering_items JSONB NOT NULL,
    requesting_items JSONB NOT NULL,

    -- 状态管理
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled', 'expired')),
    message TEXT,

    -- 时间戳
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,

    -- 完成信息
    completed_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    completed_by_username TEXT
);

-- 2. 交易历史表
CREATE TABLE IF NOT EXISTS trade_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    offer_id UUID REFERENCES trade_offers(id) ON DELETE SET NULL,

    -- 交易双方
    seller_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    seller_username TEXT,
    buyer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    buyer_username TEXT,

    -- 交易详情（JSON 格式）
    -- 格式: {"offered": [...], "requested": [...]}
    items_exchanged JSONB NOT NULL,

    -- 时间戳
    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- 评价系统
    seller_rating INTEGER CHECK (seller_rating >= 1 AND seller_rating <= 5),
    seller_comment TEXT,
    buyer_rating INTEGER CHECK (buyer_rating >= 1 AND buyer_rating <= 5),
    buyer_comment TEXT
);

-- 3. 创建索引（提升查询性能）
CREATE INDEX IF NOT EXISTS idx_trade_offers_owner ON trade_offers(owner_id);
CREATE INDEX IF NOT EXISTS idx_trade_offers_status ON trade_offers(status);
CREATE INDEX IF NOT EXISTS idx_trade_offers_expires_at ON trade_offers(expires_at);
CREATE INDEX IF NOT EXISTS idx_trade_history_seller ON trade_history(seller_id);
CREATE INDEX IF NOT EXISTS idx_trade_history_buyer ON trade_history(buyer_id);
CREATE INDEX IF NOT EXISTS idx_trade_history_completed_at ON trade_history(completed_at);

-- 4. 行级安全策略（RLS）

-- 启用 RLS
ALTER TABLE trade_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE trade_history ENABLE ROW LEVEL SECURITY;

-- trade_offers 策略
-- 所有已登录用户可以查看 active 状态的挂单
CREATE POLICY "Anyone can view active trade offers"
    ON trade_offers FOR SELECT
    USING (
        auth.role() = 'authenticated' AND
        (status = 'active' AND expires_at > NOW())
    );

-- 用户可以查看自己的所有挂单
CREATE POLICY "Users can view own trade offers"
    ON trade_offers FOR SELECT
    USING (auth.uid() = owner_id);

-- 用户可以创建挂单
CREATE POLICY "Users can create trade offers"
    ON trade_offers FOR INSERT
    WITH CHECK (auth.uid() = owner_id);

-- 用户可以更新自己的挂单
CREATE POLICY "Users can update own trade offers"
    ON trade_offers FOR UPDATE
    USING (auth.uid() = owner_id);

-- trade_history 策略
-- 用户只能查看自己参与的交易历史
CREATE POLICY "Users can view own trade history"
    ON trade_history FOR SELECT
    USING (
        auth.uid() = seller_id OR
        auth.uid() = buyer_id
    );

-- 用户可以创建交易历史记录
CREATE POLICY "Users can create trade history"
    ON trade_history FOR INSERT
    WITH CHECK (
        auth.uid() = seller_id OR
        auth.uid() = buyer_id
    );

-- 用户可以更新自己参与的交易评价
CREATE POLICY "Users can update own trade ratings"
    ON trade_history FOR UPDATE
    USING (
        auth.uid() = seller_id OR
        auth.uid() = buyer_id
    );

-- 5. 辅助函数：清理过期挂单
CREATE OR REPLACE FUNCTION cleanup_expired_trade_offers()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    -- 更新过期的挂单状态
    WITH updated AS (
        UPDATE trade_offers
        SET status = 'expired'
        WHERE status = 'active'
          AND expires_at < NOW()
        RETURNING id
    )
    SELECT COUNT(*) INTO expired_count FROM updated;

    RETURN expired_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. 视图：可用的交易挂单（方便查询）
CREATE OR REPLACE VIEW available_trade_offers AS
SELECT
    t.*,
    u.raw_user_meta_data->>'username' as owner_username_display
FROM trade_offers t
LEFT JOIN auth.users u ON t.owner_id = u.id
WHERE t.status = 'active'
  AND t.expires_at > NOW()
ORDER BY t.created_at DESC;

COMMENT ON TABLE trade_offers IS '交易挂单表 - 用户发布的物品交换请求';
COMMENT ON TABLE trade_history IS '交易历史表 - 记录所有完成的交易';
COMMENT ON FUNCTION cleanup_expired_trade_offers IS '清理过期挂单的函数，可用于定时任务';
COMMENT ON VIEW available_trade_offers IS '可用的交易挂单视图 - 只显示活跃且未过期的挂单';
