-- Day 28: 创建玩家建筑表
-- 用于存储玩家建造的建筑数据

-- 创建玩家建筑表
create table if not exists player_buildings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  territory_id text not null,
  template_id text not null,
  building_name text not null,
  status text default 'constructing',
  level int default 1,
  location_lat double precision,
  location_lon double precision,
  build_started_at timestamptz default now(),
  build_completed_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 创建索引（加速查询）
create index if not exists idx_player_buildings_user_id on player_buildings(user_id);
create index if not exists idx_player_buildings_territory_id on player_buildings(territory_id);
create index if not exists idx_player_buildings_status on player_buildings(status);

-- 启用 RLS
alter table player_buildings enable row level security;

-- RLS 策略：用户只能操作自己的建筑
create policy "用户可以查看自己的建筑"
  on player_buildings for select
  using (auth.uid() = user_id);

create policy "用户可以创建自己的建筑"
  on player_buildings for insert
  with check (auth.uid() = user_id);

create policy "用户可以更新自己的建筑"
  on player_buildings for update
  using (auth.uid() = user_id);

create policy "用户可以删除自己的建筑"
  on player_buildings for delete
  using (auth.uid() = user_id);

-- 添加注释
comment on table player_buildings is '玩家建筑表';
comment on column player_buildings.template_id is '建筑模板ID（如 campfire, shelter）';
comment on column player_buildings.status is '建筑状态：constructing（建造中）, active（运行中）';
comment on column player_buildings.level is '建筑等级，默认1级';
comment on column player_buildings.build_completed_at is '预计建造完成时间';
