-- ==========================================
-- 交易系统修复：添加原子性操作支持
-- ==========================================

-- 1. 创建原子性交易接受函数（带行级锁和事务）
CREATE OR REPLACE FUNCTION accept_trade_offer(
    p_offer_id UUID,
    p_buyer_id UUID,
    p_buyer_username TEXT
)
RETURNS JSON AS $$
DECLARE
    v_offer RECORD;
    v_item RECORD;
    v_current_qty INTEGER;
    v_new_qty INTEGER;
    v_result JSON;
BEGIN
    -- 1. 使用 FOR UPDATE 行级锁获取挂单
    SELECT * INTO v_offer
    FROM trade_offers
    WHERE id = p_offer_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', '挂单不存在');
    END IF;

    -- 2. 验证挂单状态
    IF v_offer.status != 'active' THEN
        RETURN json_build_object('success', false, 'error', '挂单已失效');
    END IF;

    IF v_offer.expires_at < NOW() THEN
        RETURN json_build_object('success', false, 'error', '挂单已过期');
    END IF;

    IF v_offer.owner_id = p_buyer_id THEN
        RETURN json_build_object('success', false, 'error', '不能接受自己的挂单');
    END IF;

    -- 3. 验证买家物品是否足够
    FOR v_item IN SELECT * FROM jsonb_to_recordset(v_offer.requesting_items) AS x(item_id TEXT, quantity INTEGER)
    LOOP
        SELECT COALESCE(quantity, 0) INTO v_current_qty
        FROM inventory
        WHERE user_id = p_buyer_id AND item_id = v_item.item_id;

        IF v_current_qty < v_item.quantity THEN
            RETURN json_build_object(
                'success', false,
                'error', format('物品不足：%s，还需 %s 个', v_item.item_id, v_item.quantity - v_current_qty)
            );
        END IF;
    END LOOP;

    -- 4. 扣除买家的物品（卖家请求的物品）
    FOR v_item IN SELECT * FROM jsonb_to_recordset(v_offer.requesting_items) AS x(item_id TEXT, quantity INTEGER)
    LOOP
        SELECT quantity INTO v_current_qty
        FROM inventory
        WHERE user_id = p_buyer_id AND item_id = v_item.item_id
        FOR UPDATE;

        v_new_qty := v_current_qty - v_item.quantity;

        IF v_new_qty <= 0 THEN
            DELETE FROM inventory
            WHERE user_id = p_buyer_id AND item_id = v_item.item_id;
        ELSE
            UPDATE inventory
            SET quantity = v_new_qty, updated_at = NOW()
            WHERE user_id = p_buyer_id AND item_id = v_item.item_id;
        END IF;
    END LOOP;

    -- 5. 买家获得卖家的物品（卖家提供的物品）
    FOR v_item IN SELECT * FROM jsonb_to_recordset(v_offer.offering_items) AS x(item_id TEXT, quantity INTEGER)
    LOOP
        SELECT quantity INTO v_current_qty
        FROM inventory
        WHERE user_id = p_buyer_id AND item_id = v_item.item_id
        FOR UPDATE;

        IF FOUND THEN
            UPDATE inventory
            SET quantity = v_current_qty + v_item.quantity, updated_at = NOW()
            WHERE user_id = p_buyer_id AND item_id = v_item.item_id;
        ELSE
            INSERT INTO inventory (user_id, item_id, item_name, quantity, quality)
            VALUES (p_buyer_id, v_item.item_id, v_item.item_id, v_item.quantity, 'normal');
        END IF;
    END LOOP;

    -- 6. 卖家获得买家的物品（卖家请求的物品）
    FOR v_item IN SELECT * FROM jsonb_to_recordset(v_offer.requesting_items) AS x(item_id TEXT, quantity INTEGER)
    LOOP
        SELECT quantity INTO v_current_qty
        FROM inventory
        WHERE user_id = v_offer.owner_id AND item_id = v_item.item_id
        FOR UPDATE;

        IF FOUND THEN
            UPDATE inventory
            SET quantity = v_current_qty + v_item.quantity, updated_at = NOW()
            WHERE user_id = v_offer.owner_id AND item_id = v_item.item_id;
        ELSE
            INSERT INTO inventory (user_id, item_id, item_name, quantity, quality)
            VALUES (v_offer.owner_id, v_item.item_id, v_item.item_id, v_item.quantity, 'normal');
        END IF;
    END LOOP;

    -- 7. 更新挂单状态
    UPDATE trade_offers
    SET status = 'completed',
        completed_at = NOW(),
        completed_by_user_id = p_buyer_id,
        completed_by_username = p_buyer_username
    WHERE id = p_offer_id;

    -- 8. 创建交易历史记录
    INSERT INTO trade_history (
        offer_id,
        seller_id,
        seller_username,
        buyer_id,
        buyer_username,
        items_exchanged,
        completed_at
    ) VALUES (
        p_offer_id,
        v_offer.owner_id,
        v_offer.owner_username,
        p_buyer_id,
        p_buyer_username,
        json_build_object(
            'offered', v_offer.offering_items,
            'requested', v_offer.requesting_items
        ),
        NOW()
    );

    RETURN json_build_object('success', true, 'message', '交易成功');

EXCEPTION WHEN OTHERS THEN
    -- 发生错误时自动回滚
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. 修复过期清理函数：添加物品退还逻辑
CREATE OR REPLACE FUNCTION cleanup_expired_trade_offers()
RETURNS INTEGER AS $$
DECLARE
    v_expired_offer RECORD;
    v_item RECORD;
    v_current_qty INTEGER;
    v_expired_count INTEGER := 0;
BEGIN
    -- 遍历所有过期的活跃挂单
    FOR v_expired_offer IN
        SELECT id, owner_id, offering_items
        FROM trade_offers
        WHERE status = 'active' AND expires_at < NOW()
        FOR UPDATE
    LOOP
        -- 退还物品给发布者
        FOR v_item IN SELECT * FROM jsonb_to_recordset(v_expired_offer.offering_items) AS x(item_id TEXT, quantity INTEGER)
        LOOP
            SELECT quantity INTO v_current_qty
            FROM inventory
            WHERE user_id = v_expired_offer.owner_id AND item_id = v_item.item_id
            FOR UPDATE;

            IF FOUND THEN
                UPDATE inventory
                SET quantity = v_current_qty + v_item.quantity, updated_at = NOW()
                WHERE user_id = v_expired_offer.owner_id AND item_id = v_item.item_id;
            ELSE
                INSERT INTO inventory (user_id, item_id, item_name, quantity, quality)
                VALUES (v_expired_offer.owner_id, v_item.item_id, v_item.item_id, v_item.quantity, 'normal');
            END IF;
        END LOOP;

        -- 更新挂单状态为过期
        UPDATE trade_offers
        SET status = 'expired'
        WHERE id = v_expired_offer.id;

        v_expired_count := v_expired_count + 1;
    END LOOP;

    RETURN v_expired_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 添加注释
COMMENT ON FUNCTION accept_trade_offer IS '原子性交易接受函数 - 使用行级锁和事务确保数据一致性';
COMMENT ON FUNCTION cleanup_expired_trade_offers IS '清理过期挂单并退还物品给发布者';
