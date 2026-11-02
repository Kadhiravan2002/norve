-- NORVÉ Phase 6: catalogue metadata, image gallery, variant attributes and stock RPC.
-- Existing order RPCs remain responsible for checkout pricing and atomic stock deduction.
-- This migration is safe to retry after a partial SQL Editor execution.

begin;

alter table public.categories
  add column if not exists description text not null default '',
  add column if not exists image_url text;

alter table public.products
  add column if not exists sku text,
  add column if not exists requires_size boolean not null default true,
  add column if not exists requires_color boolean not null default true;

update public.products
set sku = 'NRV-' || upper(substr(replace(id::text, '-', ''), 1, 10))
where sku is null or length(trim(sku)) = 0;
alter table public.products alter column sku set not null;
alter table public.products alter column sku set default
  ('NRV-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)));
create unique index if not exists products_sku_ci_unique on public.products (lower(sku));

alter table public.product_variants
  add column if not exists sku text,
  add column if not exists price_override_inr numeric(12,2),
  add column if not exists is_available boolean not null default true;

update public.product_variants pv
set sku = p.sku || '-' || upper(substr(replace(pv.id::text, '-', ''), 1, 6))
from public.products p
where pv.product_id = p.id and (pv.sku is null or length(trim(pv.sku)) = 0);
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.product_variants'::regclass
      and conname = 'product_variants_price_override_check'
  ) then
    alter table public.product_variants
      add constraint product_variants_price_override_check
      check (price_override_inr is null or
        (price_override_inr > 0 and price_override_inr = trunc(price_override_inr)));
  end if;
end;
$$;
create unique index if not exists product_variants_sku_ci_unique
  on public.product_variants (lower(sku)) where sku is not null;

create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  image_url text not null check (image_url ~ '^https?://'),
  storage_path text,
  sort_order integer not null default 0 check (sort_order >= 0),
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  unique(product_id, image_url)
);
create unique index if not exists product_images_one_primary_idx
  on public.product_images(product_id) where is_primary;
create index if not exists product_images_order_idx
  on public.product_images(product_id, sort_order);
insert into public.product_images(product_id, image_url, sort_order, is_primary)
select id, image_url, 0, true from public.products
on conflict (product_id, image_url) do nothing;

alter table public.product_images enable row level security;
drop policy if exists "public reads published product images" on public.product_images;
create policy "public reads published product images" on public.product_images
  for select to anon, authenticated using (
    exists (select 1 from public.products p where p.id = product_id and p.is_active)
    or public.is_admin()
  );
drop policy if exists "admins manage product images" on public.product_images;
create policy "admins manage product images" on public.product_images
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
grant select on public.product_images to anon, authenticated;
grant insert, update, delete on public.product_images to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('norve-product-images', 'norve-product-images', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "public reads NORVE product images" on storage.objects;
create policy "public reads NORVE product images" on storage.objects
  for select to anon, authenticated using (bucket_id = 'norve-product-images');
drop policy if exists "admins upload NORVE product images" on storage.objects;
create policy "admins upload NORVE product images" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'norve-product-images' and public.is_admin()
  );
drop policy if exists "admins update NORVE product images" on storage.objects;
create policy "admins update NORVE product images" on storage.objects
  for update to authenticated using (
    bucket_id = 'norve-product-images' and public.is_admin()
  ) with check (bucket_id = 'norve-product-images' and public.is_admin());
drop policy if exists "admins delete NORVE product images" on storage.objects;
create policy "admins delete NORVE product images" on storage.objects
  for delete to authenticated using (
    bucket_id = 'norve-product-images' and public.is_admin()
  );

create or replace function public.save_product(
  p_product_id uuid,
  p_sku text,
  p_name text,
  p_description text,
  p_price_inr numeric,
  p_original_price_inr numeric,
  p_category_id uuid,
  p_image_url text,
  p_is_active boolean,
  p_requires_size boolean,
  p_requires_color boolean,
  p_variants jsonb,
  p_images jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  saved_id uuid;
  variant jsonb;
  variant_id uuid;
  existing_variant_id uuid;
  kept_variant_ids uuid[] := array[]::uuid[];
  primary_count integer;
begin
  if not public.is_admin() then
    raise exception 'administrator authorization required' using errcode = '42501';
  end if;
  if nullif(trim(p_sku), '') is null or nullif(trim(p_name), '') is null then
    raise exception 'product name and SKU are required' using errcode = '22023';
  end if;
  if jsonb_typeof(p_variants) is distinct from 'array'
     or jsonb_array_length(p_variants) < 1 then
    raise exception 'at least one inventory variant is required' using errcode = '22023';
  end if;
  if jsonb_typeof(p_images) is distinct from 'array'
     or jsonb_array_length(p_images) < 1 then
    raise exception 'at least one product image is required' using errcode = '22023';
  end if;
  select count(*) into primary_count
  from jsonb_array_elements(p_images) as i(value)
  where (i.value ->> 'is_primary')::boolean is true;
  if primary_count <> 1 then
    raise exception 'exactly one primary product image is required' using errcode = '22023';
  end if;

  if p_product_id is null then
    insert into public.products(name, sku, description, price_inr,
      original_price_inr, category_id, image_url, is_active, requires_size,
      requires_color)
    values (trim(p_name), trim(p_sku), coalesce(p_description, ''), p_price_inr,
      p_original_price_inr, p_category_id, p_image_url, coalesce(p_is_active, true),
      coalesce(p_requires_size, true), coalesce(p_requires_color, true))
    returning id into saved_id;
  else
    update public.products set name = trim(p_name), sku = trim(p_sku),
      description = coalesce(p_description, ''), price_inr = p_price_inr,
      original_price_inr = p_original_price_inr, category_id = p_category_id,
      image_url = p_image_url, is_active = coalesce(p_is_active, true),
      requires_size = coalesce(p_requires_size, true),
      requires_color = coalesce(p_requires_color, true), updated_at = now()
    where id = p_product_id returning id into saved_id;
    if saved_id is null then
      raise exception 'product not found or inaccessible' using errcode = 'P0002';
    end if;
  end if;

  for variant in select value from jsonb_array_elements(p_variants)
  loop
    if nullif(trim(variant ->> 'sku'), '') is null
       or nullif(trim(variant ->> 'size'), '') is null
       or nullif(trim(variant ->> 'color_name'), '') is null
       or coalesce((variant ->> 'stock_quantity')::integer, -1) < 0 then
      raise exception 'variant SKU, option values and non-negative stock are required' using errcode = '22023';
    end if;
    variant_id := nullif(variant ->> 'id', '')::uuid;
    existing_variant_id := null;
    if variant_id is not null then
      update public.product_variants set sku = trim(variant ->> 'sku'),
        size = trim(variant ->> 'size'), color_name = trim(variant ->> 'color_name'),
        color_hex = variant ->> 'color_hex',
        price_override_inr = nullif(variant ->> 'price_override_inr', '')::numeric,
        stock_quantity = (variant ->> 'stock_quantity')::integer,
        is_available = coalesce((variant ->> 'is_available')::boolean, true),
        updated_at = now()
      where id = variant_id and product_id = saved_id
      returning id into existing_variant_id;
      if existing_variant_id is null then
        raise exception 'variant does not belong to this product' using errcode = '22023';
      end if;
    else
      select id into existing_variant_id from public.product_variants
      where product_id = saved_id and size = trim(variant ->> 'size')
        and color_name = trim(variant ->> 'color_name') for update;
      if existing_variant_id is null then
        insert into public.product_variants(product_id, sku, size, color_name,
          color_hex, price_override_inr, stock_quantity, is_available)
        values (saved_id, trim(variant ->> 'sku'), trim(variant ->> 'size'),
          trim(variant ->> 'color_name'), variant ->> 'color_hex',
          nullif(variant ->> 'price_override_inr', '')::numeric,
          (variant ->> 'stock_quantity')::integer,
          coalesce((variant ->> 'is_available')::boolean, true))
        returning id into existing_variant_id;
      else
        update public.product_variants set sku = trim(variant ->> 'sku'),
          color_hex = variant ->> 'color_hex',
          price_override_inr = nullif(variant ->> 'price_override_inr', '')::numeric,
          stock_quantity = (variant ->> 'stock_quantity')::integer,
          is_available = coalesce((variant ->> 'is_available')::boolean, true),
          updated_at = now()
        where id = existing_variant_id;
      end if;
    end if;
    kept_variant_ids := array_append(kept_variant_ids, existing_variant_id);
  end loop;

  delete from public.product_variants pv
  where pv.product_id = saved_id and not (pv.id = any(kept_variant_ids));

  delete from public.product_images where product_id = saved_id;
  insert into public.product_images(product_id, image_url, storage_path,
    sort_order, is_primary)
  select saved_id, i.image_url, i.storage_path, i.sort_order, i.is_primary
  from jsonb_to_recordset(p_images) as i(
    image_url text, storage_path text, sort_order integer, is_primary boolean
  );
  return saved_id;
end;
$$;
revoke all on function public.save_product(uuid,text,text,numeric,numeric,uuid,text,boolean,jsonb) from public, anon;
revoke all on function public.save_product(uuid,text,text,text,numeric,numeric,uuid,text,boolean,boolean,boolean,jsonb,jsonb) from public, anon;
grant execute on function public.save_product(uuid,text,text,numeric,numeric,uuid,text,boolean,boolean,boolean,jsonb,jsonb) to authenticated;

create or replace function public.admin_set_variant_stock(
  p_variant_id uuid,
  p_stock_quantity integer,
  p_is_available boolean default null
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'administrator authorization required' using errcode = '42501';
  end if;
  if (p_stock_quantity is not null and p_stock_quantity < 0)
     or (p_stock_quantity is null and p_is_available is null) then
    raise exception 'stock quantity must be zero or greater' using errcode = '22023';
  end if;
  update public.product_variants set
    stock_quantity = coalesce(p_stock_quantity, stock_quantity),
    is_available = coalesce(p_is_available, is_available),
    updated_at = now() where id = p_variant_id;
  if not found then
    raise exception 'variant not found' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.admin_set_variant_stock(uuid,integer,boolean) from public, anon;
grant execute on function public.admin_set_variant_stock(uuid,integer,boolean) to authenticated;

-- Use per-variant prices and availability while preserving the existing atomic order locks/deduction.
create or replace function public.create_checkout_quote(p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid := auth.uid();
  v_item record;
  v_product_id uuid;
  v_variant_id uuid;
  v_name text;
  v_image text;
  v_price numeric(12,2);
  v_active boolean;
  v_available boolean;
  v_stock integer;
  v_item_count integer;
  v_unique_count integer;
  v_subtotal numeric(12,2) := 0;
  v_shipping numeric(12,2);
  v_tax numeric(12,2);
  v_items jsonb := '[]'::jsonb;
  v_quote_id uuid;
begin
  if v_customer_id is null then
    raise exception 'customer sign-in is required' using errcode = '28000';
  end if;
  if p_items is null or jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'the shopping bag must be a JSON array' using errcode = '22023';
  end if;
  if jsonb_array_length(p_items) not between 1 and 50 then
    raise exception 'the shopping bag must contain between 1 and 50 items' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_items) as entry(value)
    where case jsonb_typeof(entry.value -> 'quantity')
      when 'number' then
        (entry.value ->> 'quantity')::numeric <> trunc((entry.value ->> 'quantity')::numeric)
      else true
    end
  ) then
    raise exception 'item quantities must be whole numbers' using errcode = '22023';
  end if;
  select count(*), count(distinct row(i.product_id, i.size, i.color_name))
    into v_item_count, v_unique_count
    from jsonb_to_recordset(p_items) as i(product_id uuid, size text, color_name text, quantity integer);
  if v_item_count <> v_unique_count then
    raise exception 'duplicate variants must be combined before checkout' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_to_recordset(p_items) as i(product_id uuid, size text, color_name text, quantity integer)
    where i.product_id is null or nullif(trim(i.size), '') is null
      or nullif(trim(i.color_name), '') is null or i.quantity is null
      or i.quantity not between 1 and 50
  ) then
    raise exception 'one or more checkout items are invalid' using errcode = '22023';
  end if;

  for v_item in
    select i.product_id, i.size, i.color_name, i.quantity
    from jsonb_to_recordset(p_items) as i(product_id uuid, size text, color_name text, quantity integer)
    order by i.product_id, i.size, i.color_name
  loop
    select p.id, pv.id, p.name, p.image_url, coalesce(pv.price_override_inr, p.price_inr), p.is_active, pv.stock_quantity, pv.is_available
      into v_product_id, v_variant_id, v_name, v_image, v_price, v_active, v_stock, v_available
      from public.products p
      join public.product_variants pv on pv.product_id = p.id
      where p.id = v_item.product_id
        and pv.size = v_item.size and pv.color_name = v_item.color_name;
    if not found or not v_active or not v_available then
      raise exception 'a selected product or variant is unavailable' using errcode = 'P0001';
    end if;
    if v_stock < v_item.quantity then
      raise exception 'insufficient stock for % (% / %)', v_name, v_item.size, v_item.color_name using errcode = 'P0001';
    end if;
    v_subtotal := v_subtotal + (v_price * v_item.quantity);
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'product_id', v_product_id,
      'variant_id', v_variant_id,
      'product_name', v_name,
      'product_image_url', v_image,
      'size', v_item.size,
      'color_name', v_item.color_name,
      'quantity', v_item.quantity,
      'unit_price_inr', v_price,
      'line_total_inr', v_price * v_item.quantity
    ));
  end loop;

  select s.shipping_fee_inr, s.tax_fee_inr
    into v_shipping, v_tax from public.checkout_settings s
    where s.singleton = true;
  if not found then
    raise exception 'checkout charges are not configured' using errcode = '55000';
  end if;
  insert into public.checkout_quotes(customer_id, items, subtotal_inr, shipping_fee_inr,
    tax_fee_inr, total_inr, expires_at)
  values (v_customer_id, v_items, v_subtotal, v_shipping, v_tax,
    v_subtotal + v_shipping + v_tax, now() + interval '10 minutes')
  returning id into v_quote_id;
  return jsonb_build_object(
    'quote_id', v_quote_id, 'items', v_items, 'subtotal_inr', v_subtotal,
    'shipping_fee_inr', v_shipping, 'tax_fee_inr', v_tax,
    'total_inr', v_subtotal + v_shipping + v_tax,
    'expires_at', now() + interval '10 minutes'
  );
end;
$$;
create or replace function public.place_simulated_order(
  p_quote_id uuid,
  p_customer_name text,
  p_phone text,
  p_address_line_1 text,
  p_address_line_2 text,
  p_city text,
  p_region text,
  p_postal_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid := auth.uid();
  v_quote public.checkout_quotes%rowtype;
  v_existing public.orders%rowtype;
  v_item record;
  v_product_id uuid;
  v_variant_id uuid;
  v_name text;
  v_image text;
  v_price numeric(12,2);
  v_active boolean;
  v_available boolean;
  v_stock integer;
  v_shipping numeric(12,2);
  v_tax numeric(12,2);
  v_email text;
  v_order public.orders%rowtype;
begin
  if v_customer_id is null then
    raise exception 'customer sign-in is required' using errcode = '28000';
  end if;
  if nullif(trim(p_customer_name), '') is null or length(trim(p_customer_name)) > 120
    or nullif(trim(p_phone), '') is null or length(trim(p_phone)) not between 7 and 24
    or p_phone !~ '^[0-9+() .-]+$'
    or nullif(trim(p_address_line_1), '') is null or length(trim(p_address_line_1)) > 180
    or length(coalesce(p_address_line_2, '')) > 180
    or nullif(trim(p_city), '') is null or length(trim(p_city)) > 100
    or nullif(trim(p_region), '') is null or length(trim(p_region)) > 100
    or nullif(trim(p_postal_code), '') is null or length(trim(p_postal_code)) not between 3 and 16
  then
    raise exception 'delivery details are invalid' using errcode = '22023';
  end if;

  select * into v_quote from public.checkout_quotes q
    where q.id = p_quote_id and q.customer_id = v_customer_id
    for update;
  if not found then
    raise exception 'checkout quote was not found' using errcode = 'P0002';
  end if;
  select * into v_existing from public.orders o
    where o.checkout_quote_id = v_quote.id;
  if found then
    return jsonb_build_object('id', v_existing.id, 'order_reference', v_existing.order_reference,
      'subtotal_inr', v_existing.subtotal_inr, 'shipping_fee_inr', v_existing.shipping_fee_inr,
      'tax_fee_inr', v_existing.tax_fee_inr, 'total_inr', v_existing.total_inr,
      'status', v_existing.status, 'payment_status', v_existing.payment_status,
      'created_at', v_existing.created_at);
  end if;
  if v_quote.expires_at <= now() then
    raise exception 'checkout quote expired; review your order again' using errcode = 'P0001';
  end if;

  -- Lock product rows in stable order before variants to avoid deadlocks with
  -- concurrent orders and catalogue edits.
  for v_product_id in
    select distinct i.product_id
    from jsonb_to_recordset(v_quote.items) as i(product_id uuid, variant_id uuid,
      product_name text, product_image_url text, size text, color_name text,
      quantity integer, unit_price_inr numeric, line_total_inr numeric)
    order by i.product_id
  loop
    perform 1 from public.products p where p.id = v_product_id for update;
    if not found then
      raise exception 'a selected product is no longer available' using errcode = 'P0001';
    end if;
  end loop;
  for v_variant_id in
    select i.variant_id
    from jsonb_to_recordset(v_quote.items) as i(product_id uuid, variant_id uuid,
      product_name text, product_image_url text, size text, color_name text,
      quantity integer, unit_price_inr numeric, line_total_inr numeric)
    order by i.variant_id
  loop
    perform 1 from public.product_variants pv where pv.id = v_variant_id for update;
    if not found then
      raise exception 'a selected variant is no longer available' using errcode = 'P0001';
    end if;
  end loop;

  for v_item in
    select i.product_id, i.variant_id, i.product_name, i.product_image_url,
      i.size, i.color_name, i.quantity, i.unit_price_inr
    from jsonb_to_recordset(v_quote.items) as i(product_id uuid, variant_id uuid,
      product_name text, product_image_url text, size text, color_name text,
      quantity integer, unit_price_inr numeric, line_total_inr numeric)
    order by i.variant_id
  loop
    select p.id, pv.id, p.name, p.image_url, coalesce(pv.price_override_inr, p.price_inr), p.is_active, pv.stock_quantity, pv.is_available
      into v_product_id, v_variant_id, v_name, v_image, v_price, v_active, v_stock, v_available
      from public.products p
      join public.product_variants pv on pv.product_id = p.id
      where p.id = v_item.product_id and pv.id = v_item.variant_id
        and pv.size = v_item.size and pv.color_name = v_item.color_name;
    if not found or not v_active or not v_available then
      raise exception 'a selected product or variant is no longer available' using errcode = 'P0001';
    end if;
    if v_price <> v_item.unit_price_inr then
      raise exception 'product prices changed; review your order again' using errcode = 'P0001';
    end if;
    if v_stock < v_item.quantity then
      raise exception 'stock changed; review your order again' using errcode = 'P0001';
    end if;
  end loop;

  select s.shipping_fee_inr, s.tax_fee_inr into v_shipping, v_tax
    from public.checkout_settings s where s.singleton = true for share;
  if not found or v_shipping <> v_quote.shipping_fee_inr or v_tax <> v_quote.tax_fee_inr then
    raise exception 'delivery or tax charges changed; review your order again' using errcode = 'P0001';
  end if;
  select u.email into v_email from auth.users u where u.id = v_customer_id;
  if v_email is null then
    raise exception 'customer email is unavailable' using errcode = 'P0001';
  end if;

  insert into public.orders(customer_id, checkout_quote_id, customer_email, customer_name,
    phone, address_line_1, address_line_2, city, region, postal_code,
    subtotal_inr, shipping_fee_inr, tax_fee_inr, total_inr,
    status, payment_method, payment_status)
  values (v_customer_id, v_quote.id, v_email, trim(p_customer_name), trim(p_phone),
    trim(p_address_line_1), coalesce(trim(p_address_line_2), ''), trim(p_city),
    trim(p_region), trim(p_postal_code), v_quote.subtotal_inr,
    v_quote.shipping_fee_inr, v_quote.tax_fee_inr, v_quote.total_inr,
    'pending', 'simulation', 'simulated')
  returning * into v_order;

  for v_item in
    select i.product_id, i.variant_id, i.product_name, i.product_image_url,
      i.size, i.color_name, i.quantity, i.unit_price_inr
    from jsonb_to_recordset(v_quote.items) as i(product_id uuid, variant_id uuid,
      product_name text, product_image_url text, size text, color_name text,
      quantity integer, unit_price_inr numeric, line_total_inr numeric)
    order by i.variant_id
  loop
    update public.product_variants pv
      set stock_quantity = pv.stock_quantity - v_item.quantity, updated_at = now()
      where pv.id = v_item.variant_id;
    insert into public.order_items(order_id, product_id, variant_id, product_name,
      product_image_url, size, color_name, quantity, unit_price_inr)
    values (v_order.id, v_item.product_id, v_item.variant_id, v_item.product_name,
      v_item.product_image_url, v_item.size, v_item.color_name,
      v_item.quantity, v_item.unit_price_inr);
  end loop;
  update public.checkout_quotes q set consumed_at = now() where q.id = v_quote.id;
  return jsonb_build_object('id', v_order.id, 'order_reference', v_order.order_reference,
    'subtotal_inr', v_order.subtotal_inr, 'shipping_fee_inr', v_order.shipping_fee_inr,
    'tax_fee_inr', v_order.tax_fee_inr, 'total_inr', v_order.total_inr,
    'status', v_order.status, 'payment_status', v_order.payment_status,
    'created_at', v_order.created_at);
end;
$$;

commit;
