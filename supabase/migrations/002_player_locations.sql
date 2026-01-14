-- ============================================
-- 地球新主 - 玩家位置迁移脚本
-- 创建时间: 2025-01-14
-- 用途: 附近玩家检测系统
-- ============================================

-- 1. player_locations（玩家位置）
-- 存储玩家的实时位置信息，用于计算附近玩家密度
CREATE TABLE IF NOT EXISTS player_locations (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_online BOOLEAN DEFAULT TRUE
);

-- 创建索引
-- 在线玩家索引：快速过滤在线玩家
CREATE INDEX IF NOT EXISTS idx_player_locations_online
    ON player_locations (is_online)
    WHERE is_online = TRUE;

-- 更新时间索引：用于判断玩家是否超时离线
CREATE INDEX IF NOT EXISTS idx_player_locations_updated
    ON player_locations (updated_at);

-- 启用 RLS
ALTER TABLE player_locations ENABLE ROW LEVEL SECURITY;

-- RLS 策略：用户可以插入自己的位置
CREATE POLICY "Users can insert own location"
    ON player_locations FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- RLS 策略：用户可以更新自己的位置
CREATE POLICY "Users can update own location"
    ON player_locations FOR UPDATE
    USING (auth.uid() = user_id);

-- RLS 策略：用户可以查看自己的位置（不允许查看他人位置）
CREATE POLICY "Users can view own location"
    ON player_locations FOR SELECT
    USING (auth.uid() = user_id);

-- ============================================
-- 2. 查询附近玩家数量的 RPC 函数
-- ============================================
-- 使用 Haversine 公式计算球面距离
-- 参数:
--   p_lat: 查询中心点纬度
--   p_lng: 查询中心点经度
--   p_radius_meters: 搜索半径（米），默认 1000
--   p_timeout_minutes: 在线超时时间（分钟），默认 5
-- 返回: 附近在线玩家数量（不含自己）

CREATE OR REPLACE FUNCTION count_nearby_players(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION,
    p_radius_meters DOUBLE PRECISION DEFAULT 1000,
    p_timeout_minutes INT DEFAULT 5
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    player_count INT;
BEGIN
    SELECT COUNT(*)
    INTO player_count
    FROM player_locations
    WHERE user_id != auth.uid()                                    -- 排除自己
      AND is_online = TRUE                                          -- 只统计在线玩家
      AND updated_at > NOW() - (p_timeout_minutes || ' minutes')::INTERVAL  -- 超时检查
      AND (
          -- Haversine 公式计算距离（单位：米）
          -- 地球平均半径 6371000 米
          6371000 * acos(
              LEAST(1.0, GREATEST(-1.0,  -- 防止 acos 参数超出 [-1, 1] 范围
                  cos(radians(p_lat)) * cos(radians(latitude)) *
                  cos(radians(longitude) - radians(p_lng)) +
                  sin(radians(p_lat)) * sin(radians(latitude))
              ))
          )
      ) <= p_radius_meters;

    RETURN COALESCE(player_count, 0);
END;
$$;

-- ============================================
-- 3. 上报/更新玩家位置的 RPC 函数
-- ============================================
-- 使用 UPSERT 模式：存在则更新，不存在则插入
-- 参数:
--   p_lat: 玩家当前纬度
--   p_lng: 玩家当前经度
-- 返回: 是否成功

CREATE OR REPLACE FUNCTION report_player_location(
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO player_locations (user_id, latitude, longitude, updated_at, is_online)
    VALUES (auth.uid(), p_lat, p_lng, NOW(), TRUE)
    ON CONFLICT (user_id)
    DO UPDATE SET
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        updated_at = NOW(),
        is_online = TRUE;

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$;

-- ============================================
-- 4. 标记玩家离线的 RPC 函数
-- ============================================

CREATE OR REPLACE FUNCTION mark_player_offline()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE player_locations
    SET is_online = FALSE, updated_at = NOW()
    WHERE user_id = auth.uid();

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$;

-- ============================================
-- 5. 标记玩家在线的 RPC 函数
-- ============================================

CREATE OR REPLACE FUNCTION mark_player_online()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE player_locations
    SET is_online = TRUE, updated_at = NOW()
    WHERE user_id = auth.uid();

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$;

-- ============================================
-- 完成
-- ============================================
