-- ============================================
-- 地球新主 - 核心数据表迁移脚本
-- 创建时间: 2025-12-26
-- ============================================

-- 1. profiles（用户资料）
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 启用 RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- RLS 策略：用户可以查看所有资料
CREATE POLICY "Profiles are viewable by everyone"
    ON profiles FOR SELECT
    USING (true);

-- RLS 策略：用户只能更新自己的资料
CREATE POLICY "Users can update own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

-- RLS 策略：用户可以插入自己的资料
CREATE POLICY "Users can insert own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- 2. territories（领地）
CREATE TABLE IF NOT EXISTS territories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    path JSONB NOT NULL,  -- 路径点数组 [{lat, lng}, ...]
    area DOUBLE PRECISION NOT NULL,  -- 面积（平方米）
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS territories_user_id_idx ON territories(user_id);

-- 启用 RLS
ALTER TABLE territories ENABLE ROW LEVEL SECURITY;

-- RLS 策略：所有人可以查看领地
CREATE POLICY "Territories are viewable by everyone"
    ON territories FOR SELECT
    USING (true);

-- RLS 策略：用户只能创建自己的领地
CREATE POLICY "Users can create own territories"
    ON territories FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- RLS 策略：用户只能更新自己的领地
CREATE POLICY "Users can update own territories"
    ON territories FOR UPDATE
    USING (auth.uid() = user_id);

-- RLS 策略：用户只能删除自己的领地
CREATE POLICY "Users can delete own territories"
    ON territories FOR DELETE
    USING (auth.uid() = user_id);

-- 3. pois（兴趣点）
CREATE TABLE IF NOT EXISTS pois (
    id TEXT PRIMARY KEY,  -- 外部ID（如 Apple MapKit 的 POI ID）
    poi_type TEXT NOT NULL,  -- 类型：hospital, supermarket, factory, park, bank 等
    name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    discovered_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    discovered_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS pois_poi_type_idx ON pois(poi_type);
CREATE INDEX IF NOT EXISTS pois_discovered_by_idx ON pois(discovered_by);
CREATE INDEX IF NOT EXISTS pois_location_idx ON pois(latitude, longitude);

-- 启用 RLS
ALTER TABLE pois ENABLE ROW LEVEL SECURITY;

-- RLS 策略：所有人可以查看 POI
CREATE POLICY "POIs are viewable by everyone"
    ON pois FOR SELECT
    USING (true);

-- RLS 策略：已登录用户可以创建 POI
CREATE POLICY "Authenticated users can create POIs"
    ON pois FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- RLS 策略：发现者可以更新 POI
CREATE POLICY "Discoverers can update POIs"
    ON pois FOR UPDATE
    USING (auth.uid() = discovered_by);

-- ============================================
-- 自动创建用户资料的触发器
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, avatar_url)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 删除已存在的触发器（如果有）
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 创建触发器：当新用户注册时自动创建 profile
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 完成
-- ============================================
