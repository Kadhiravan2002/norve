-- NORVÉ catalogue and inventory foundation. Apply with Supabase CLI or SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  description text not null default '',
  price_inr numeric(12,2) not null check (price_inr > 0 and price_inr = trunc(price_inr)),
  original_price_inr numeric(12,2) check (original_price_inr is null or (original_price_inr > 0 and original_price_inr = trunc(original_price_inr))),
  category_id uuid not null references public.categories(id) on update cascade on delete restrict,
  image_url text not null check (image_url ~ '^https?://'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  size text not null check (length(trim(size)) > 0),
  color_name text not null check (length(trim(color_name)) > 0),
  color_hex text not null check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(product_id, size, color_name)
);

-- Membership is provisioned by the project owner; clients cannot grant roles.
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  provisioned_at timestamptz not null default now()
);

create index if not exists products_active_created_idx on public.products(is_active, created_at desc);
create index if not exists products_category_idx on public.products(category_id);
create index if not exists variants_product_stock_idx on public.product_variants(product_id, stock_quantity);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admin_users au where au.user_id = (select auth.uid())
  );
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.admin_users enable row level security;

drop policy if exists "public reads categories used by active products" on public.categories;
create policy "public reads categories used by active products" on public.categories
  for select to anon, authenticated using (
    exists (select 1 from public.products p where p.category_id = id and p.is_active)
    or public.is_admin()
  );
drop policy if exists "admins manage categories" on public.categories;
create policy "admins manage categories" on public.categories
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "public reads active products" on public.products;
create policy "public reads active products" on public.products
  for select to anon, authenticated using (is_active or public.is_admin());
drop policy if exists "admins manage products" on public.products;
create policy "admins manage products" on public.products
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "public reads variants of active products" on public.product_variants;
create policy "public reads variants of active products" on public.product_variants
  for select to anon, authenticated using (
    exists (select 1 from public.products p where p.id = product_id and p.is_active)
    or public.is_admin()
  );
drop policy if exists "admins manage variants" on public.product_variants;
create policy "admins manage variants" on public.product_variants
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admins read own membership" on public.admin_users;
create policy "admins read own membership" on public.admin_users
  for select to authenticated using (user_id = (select auth.uid()));
revoke all on public.admin_users from anon, authenticated;
grant select on public.admin_users to authenticated;
grant select on public.categories, public.products, public.product_variants to anon, authenticated;
grant insert, update, delete on public.categories, public.products, public.product_variants to authenticated;

-- Atomic administrator save: product and all variants commit together.
create or replace function public.save_product(
  p_product_id uuid,
  p_name text,
  p_description text,
  p_price_inr numeric,
  p_original_price_inr numeric,
  p_category_id uuid,
  p_image_url text,
  p_is_active boolean,
  p_variants jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  saved_id uuid;
begin
  if not public.is_admin() then
    raise exception 'administrator authorization required' using errcode = '42501';
  end if;
  if jsonb_typeof(p_variants) <> 'array' or jsonb_array_length(p_variants) = 0 then
    raise exception 'at least one variant is required' using errcode = '22023';
  end if;
  if p_product_id is null then
    insert into public.products(name, description, price_inr, original_price_inr, category_id, image_url, is_active)
    values (p_name, coalesce(p_description, ''), p_price_inr, p_original_price_inr, p_category_id, p_image_url, coalesce(p_is_active, true))
    returning id into saved_id;
  else
    update public.products set name = p_name, description = coalesce(p_description, ''),
      price_inr = p_price_inr, original_price_inr = p_original_price_inr,
      category_id = p_category_id, image_url = p_image_url, is_active = coalesce(p_is_active, true), updated_at = now()
      where id = p_product_id returning id into saved_id;
    if saved_id is null then
      raise exception 'product not found or inaccessible' using errcode = 'P0002';
    end if;
    delete from public.product_variants where product_id = saved_id;
  end if;
  insert into public.product_variants(product_id, size, color_name, color_hex, stock_quantity)
  select saved_id, v.size, v.color_name, v.color_hex, v.stock_quantity
  from jsonb_to_recordset(p_variants) as v(size text, color_name text, color_hex text, stock_quantity integer);
  return saved_id;
end;
$$;
revoke all on function public.save_product(uuid,text,text,numeric,numeric,uuid,text,boolean,jsonb) from public, anon;
grant execute on function public.save_product(uuid,text,text,numeric,numeric,uuid,text,boolean,jsonb) to authenticated;

insert into public.categories(name, slug) values
  ('T-shirts', 't-shirts'), ('Shirts', 'shirts'), ('Knitwear', 'knitwear'), ('Trousers', 'trousers')
on conflict (slug) do nothing;
