-- 1) 先创建存储桶（公开读，上传由 RLS 控制）
insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

-- 2) 照片表
create table if not exists public.photos (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    description text default '',
    image_url text not null,
    captured_at timestamptz not null default now(),
    author text not null,
    owner_id uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz not null default now()
);

alter table public.photos enable row level security;

-- 3) 白名单函数（只允许两个邮箱写入）
create or replace function public.is_allowed_email()
returns boolean
language sql
stable
as $$
    select lower(coalesce(auth.jwt() ->> 'email', '')) in (
        '1609634550@qq.com',
        '3386164850@qq.com'
    );
$$;

-- 4) photos 表策略：所有人可读，白名单可写
drop policy if exists "photos_select_all" on public.photos;
create policy "photos_select_all"
on public.photos
for select
to anon, authenticated
using (true);

drop policy if exists "photos_insert_whitelist" on public.photos;
create policy "photos_insert_whitelist"
on public.photos
for insert
to authenticated
with check (
    public.is_allowed_email() and owner_id = auth.uid()
);

drop policy if exists "photos_update_own_whitelist" on public.photos;
create policy "photos_update_own_whitelist"
on public.photos
for update
to authenticated
using (
    public.is_allowed_email() and owner_id = auth.uid()
)
with check (
    public.is_allowed_email() and owner_id = auth.uid()
);

drop policy if exists "photos_delete_own_whitelist" on public.photos;
create policy "photos_delete_own_whitelist"
on public.photos
for delete
to authenticated
using (
    public.is_allowed_email() and owner_id = auth.uid()
);

-- 5) storage.objects 策略：公开读 + 白名单可写
drop policy if exists "storage_public_read_photos" on storage.objects;
create policy "storage_public_read_photos"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'photos');

drop policy if exists "storage_insert_whitelist_photos" on storage.objects;
create policy "storage_insert_whitelist_photos"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'photos'
    and public.is_allowed_email()
    and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "storage_update_whitelist_photos" on storage.objects;
create policy "storage_update_whitelist_photos"
on storage.objects
for update
to authenticated
using (
    bucket_id = 'photos'
    and public.is_allowed_email()
    and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
    bucket_id = 'photos'
    and public.is_allowed_email()
    and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "storage_delete_whitelist_photos" on storage.objects;
create policy "storage_delete_whitelist_photos"
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'photos'
    and public.is_allowed_email()
    and (storage.foldername(name))[1] = auth.uid()::text
);

-- 6) Roche Log 表（白名单成员共享可见）
create table if not exists public.roche_logs (
    id uuid primary key default gen_random_uuid(),
    content text not null,
    author text not null,
    owner_id uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz not null default now()
);

alter table public.roche_logs enable row level security;

drop policy if exists "roche_logs_select_whitelist" on public.roche_logs;
create policy "roche_logs_select_whitelist"
on public.roche_logs
for select
to authenticated
using (public.is_allowed_email());

drop policy if exists "roche_logs_insert_whitelist" on public.roche_logs;
create policy "roche_logs_insert_whitelist"
on public.roche_logs
for insert
to authenticated
with check (
    public.is_allowed_email()
    and owner_id = auth.uid()
);

drop policy if exists "roche_logs_update_own_whitelist" on public.roche_logs;
create policy "roche_logs_update_own_whitelist"
on public.roche_logs
for update
to authenticated
using (
    public.is_allowed_email()
    and owner_id = auth.uid()
)
with check (
    public.is_allowed_email()
    and owner_id = auth.uid()
);

drop policy if exists "roche_logs_delete_own_whitelist" on public.roche_logs;
create policy "roche_logs_delete_own_whitelist"
on public.roche_logs
for delete
to authenticated
using (
    public.is_allowed_email()
    and owner_id = auth.uid()
);

-- 7) 电子鱼缸：共享鱼苗（云端同步）
create table if not exists public.aquarium_fish_seeds (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null references auth.users(id) on delete cascade,
    emoji text not null,
    name text not null,
    -- 位置：用比例存储，适配不同分辨率
    rx double precision not null,
    ry double precision not null,
    -- 动画参数（主要用于首段穿过；后续随机由前端自行演进）
    dir int not null check (dir in (-1, 1)),
    size double precision not null,
    speed double precision not null,
    phase double precision not null,
    straight_line boolean not null default true,
    pass_end_rx double precision not null default 0,
    start_rx double precision not null default 0,
    end_rx double precision not null default 0,
    wobble double precision not null default 0,
    created_at timestamptz not null default now()
);

alter table public.aquarium_fish_seeds enable row level security;

drop policy if exists "aquarium_fish_seeds_select_whitelist" on public.aquarium_fish_seeds;
create policy "aquarium_fish_seeds_select_whitelist"
on public.aquarium_fish_seeds
for select
to authenticated
using (public.is_allowed_email());

drop policy if exists "aquarium_fish_seeds_insert_whitelist" on public.aquarium_fish_seeds;
create policy "aquarium_fish_seeds_insert_whitelist"
on public.aquarium_fish_seeds
for insert
to authenticated
with check (
    public.is_allowed_email()
);

drop policy if exists "aquarium_fish_seeds_delete_whitelist" on public.aquarium_fish_seeds;
create policy "aquarium_fish_seeds_delete_whitelist"
on public.aquarium_fish_seeds
for delete
to authenticated
using (
    public.is_allowed_email()
);

drop policy if exists "aquarium_fish_seeds_update_whitelist" on public.aquarium_fish_seeds;
create policy "aquarium_fish_seeds_update_whitelist"
on public.aquarium_fish_seeds
for update
to authenticated
using (public.is_allowed_email())
with check (public.is_allowed_email());

-- 8) 电子鱼缸：喂食日志（云端同步）
create table if not exists public.aquarium_feed_logs (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null references auth.users(id) on delete cascade,
    author text not null,
    feed_strength int not null default 1 check (feed_strength >= 0 and feed_strength <= 10),
    message text default '',
    created_at timestamptz not null default now()
);

alter table public.aquarium_feed_logs enable row level security;

drop policy if exists "aquarium_feed_logs_select_whitelist" on public.aquarium_feed_logs;
create policy "aquarium_feed_logs_select_whitelist"
on public.aquarium_feed_logs
for select
to authenticated
using (public.is_allowed_email());

drop policy if exists "aquarium_feed_logs_insert_whitelist" on public.aquarium_feed_logs;
create policy "aquarium_feed_logs_insert_whitelist"
on public.aquarium_feed_logs
for insert
to authenticated
with check (
    public.is_allowed_email()
);
