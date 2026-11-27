-- =====================================================================
--  화이트 보드 홍보판 · Supabase 스키마
--  Supabase 대시보드 → SQL Editor 에 이 파일 전체를 붙여넣고 [Run] 한 번만 누르세요.
--  여러 번 실행해도 오류가 나지 않도록(idempotent) 작성했습니다.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. 확장 / 권한 기본값
-- ---------------------------------------------------------------------
create extension if not exists pgcrypto;              -- gen_random_uuid()

grant usage on schema public to anon, authenticated;

-- ---------------------------------------------------------------------
-- 1. 홍보 카드 테이블
-- ---------------------------------------------------------------------
create table if not exists public.promo_items (
  id          uuid        primary key default gen_random_uuid(),
  nickname    text        check (nickname is null or char_length(nickname) between 1 and 20),
  title       text        not null check (char_length(title) between 1 and 60),
  description text        not null default '' check (char_length(description) <= 200),
  link_url    text        check (link_url is null or link_url ~* '^https?://'),
  image_url   text        not null,
  boost_count integer     not null default 1 check (boost_count >= 1),
  created_at  timestamptz not null default now()
);

-- 이미 테이블이 있던 경우에도 빠진 컬럼이 있으면 채워 넣기
-- 작성자 닉네임 — 이미 테이블이 있는 프로젝트는 이 한 줄만 실행해도 됩니다.
--   alter table public.promo_items add column if not exists nickname text;
alter table public.promo_items add column if not exists nickname    text;
alter table public.promo_items add column if not exists description text not null default '';
alter table public.promo_items add column if not exists link_url    text;
alter table public.promo_items add column if not exists boost_count integer not null default 1;
alter table public.promo_items add column if not exists created_at  timestamptz not null default now();

-- 정렬(부스트 많은 순 → 먼저 올린 순)용 인덱스
create index if not exists promo_items_rank_idx
  on public.promo_items (boost_count desc, created_at asc);

-- ---------------------------------------------------------------------
-- 2. RLS — 누구나 읽고, 누구나 새 카드를 올릴 수 있다
-- ---------------------------------------------------------------------
alter table public.promo_items enable row level security;

drop policy if exists "promo_items read"   on public.promo_items;
create policy "promo_items read"
  on public.promo_items for select
  using (true);

-- 새 카드는 boost_count = 1 로만 올릴 수 있습니다(부스트 수 조작 방지).
-- 부스트는 아래 increment_boost() RPC 로만 올라갑니다.
drop policy if exists "promo_items insert" on public.promo_items;
create policy "promo_items insert"
  on public.promo_items for insert
  with check (boost_count = 1);

grant select, insert on public.promo_items to anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. 부스트 RPC — 클라이언트가 직접 UPDATE 하지 않고 이 함수만 호출
--    security definer: 테이블 UPDATE 권한 없이도 boost_count 만 안전하게 +1
-- ---------------------------------------------------------------------
create or replace function public.increment_boost(item_id uuid, amount integer default 1)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  new_count integer;
begin
  -- 기본 범위 검사: 한 번 호출에 1회만 허용
  if amount is null or amount < 1 or amount > 1 then
    raise exception 'amount must be 1' using errcode = '22023';
  end if;

  update public.promo_items
     set boost_count = boost_count + amount
   where id = item_id
  returning boost_count into new_count;

  if new_count is null then
    raise exception 'promo item % not found', item_id using errcode = 'P0002';
  end if;

  return new_count;
end;
$$;

revoke all on function public.increment_boost(uuid, integer) from public;
grant execute on function public.increment_boost(uuid, integer) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. Realtime — 새 카드/부스트/삭제가 모든 접속자 화면에 즉시 반영
--    replica identity full: DELETE 이벤트에도 old.id 가 실려 옆 탭에서 거품이 바로 사라집니다.
-- ---------------------------------------------------------------------
alter table public.promo_items replica identity full;

do $$
begin
  begin
    alter publication supabase_realtime add table public.promo_items;
  exception
    when duplicate_object then null;   -- 이미 추가됨
    when undefined_object then null;   -- publication 이 없는 프로젝트
  end;
end;
$$;

-- ---------------------------------------------------------------------
-- 4-b. 사이트 주인 전용 관리자 삭제 RPC
--    - 비밀번호는 여기(서버)에만 있습니다. index.html 에는 절대 쓰지 마세요.
--    - 아래 'CHANGE_ME_PIN' 을 원하는 비밀번호로 바꾼 뒤 이 블록 전체를 실행하세요.
--      (영문·숫자 섞은 12자 이상을 권합니다. 페이지 소스에는 남지 않습니다.)
--    - security definer + delete 정책 없음 → 이 함수를 통해서만 카드를 지울 수 있습니다.
-- ---------------------------------------------------------------------
create or replace function public.admin_delete_promo(p_id uuid, p_pin text)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  removed integer;
begin
  -- 서버에서만 확인하는 관리자 비밀번호
  if coalesce(p_pin, '') <> 'CHANGE_ME_PIN' then
    raise exception 'invalid_admin_pin' using errcode = '28000';
  end if;

  if p_id is null then
    return false;
  end if;

  delete from public.promo_items where id = p_id;
  get diagnostics removed = row_count;

  return removed > 0;   -- 없던 카드면 false
end;
$$;

revoke all on function public.admin_delete_promo(uuid, text) from public;
grant execute on function public.admin_delete_promo(uuid, text) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 5. Storage — 이미지 버킷 'board-images' (공개 읽기 / 누구나 업로드)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('board-images', 'board-images', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "board-images read"   on storage.objects;
create policy "board-images read"
  on storage.objects for select
  using (bucket_id = 'board-images');

drop policy if exists "board-images upload" on storage.objects;
create policy "board-images upload"
  on storage.objects for insert
  with check (bucket_id = 'board-images');

-- ---------------------------------------------------------------------
-- 6. 확인용 (결과가 0이면 아직 카드가 없는 정상 상태입니다)
-- ---------------------------------------------------------------------
select
  (select count(*) from public.promo_items)                       as promo_items_count,
  (select count(*) from storage.buckets where id = 'board-images') as bucket_ok,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_delete_promo') as admin_rpc_ok;
