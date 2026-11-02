-- NORVÉ Phase 4C: quotes, transactional simulated orders, and admin fulfillment.
-- Requires 20261029000000_catalogue_inventory.sql (public.is_admin and catalogue tables).

create table if not exists public.checkout_settings (
  singleton boolean primary key default true check (singleton),
  shipping_fee_inr numeric(12,2) not null default 0
    check (shipping_fee_inr >= 0 and shipping_fee_inr = trunc(shipping_fee_inr)),
  tax_fee_inr numeric(12,2) not null default 0
    check (tax_fee_inr >= 0 and tax_fee_inr = trunc(tax_fee_inr)),
  updated_at timestamptz not null default now()
);
insert into public.checkout_settings(singleton, shipping_fee_inr, tax_fee_inr)
values (true, 0, 0) on conflict (singleton) do nothing;
alter table public.checkout_settings enable row level security;
revoke all on public.checkout_settings from anon, authenticated;

create table if not exists public.checkout_quotes (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete restrict,
  items jsonb not null check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) > 0),
  subtotal_inr numeric(12,2) not null check (subtotal_inr >= 0),
  shipping_fee_inr numeric(12,2) not null check (shipping_fee_inr >= 0),
  tax_fee_inr numeric(12,2) not null check (tax_fee_inr >= 0),
  total_inr numeric(12,2) not null check (total_inr = subtotal_inr + shipping_fee_inr + tax_fee_inr),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists checkout_quotes_customer_created_idx
  on public.checkout_quotes(customer_id, created_at desc);
alter table public.checkout_quotes enable row level security;
drop policy if exists "customers read own checkout quotes" on public.checkout_quotes;
create policy "customers read own checkout quotes" on public.checkout_quotes
  for select to authenticated using (customer_id = (select auth.uid()));
grant select on public.checkout_quotes to authenticated;
revoke insert, update, delete on public.checkout_quotes from anon, authenticated;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_reference text not null unique default
    ('NRV-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  customer_id uuid not null references auth.users(id) on delete restrict,
  checkout_quote_id uuid not null unique references public.checkout_quotes(id) on delete restrict,
  customer_email text not null,
  customer_name text not null check (length(trim(customer_name)) between 1 and 120),
  phone text not null check (length(trim(phone)) between 7 and 24),
  address_line_1 text not null check (length(trim(address_line_1)) between 3 and 180),
  address_line_2 text not null default '',
  city text not null check (length(trim(city)) between 1 and 100),
  region text not null check (length(trim(region)) between 1 and 100),
  postal_code text not null check (length(trim(postal_code)) between 3 and 16),
  subtotal_inr numeric(12,2) not null check (subtotal_inr >= 0),
  shipping_fee_inr numeric(12,2) not null check (shipping_fee_inr >= 0),
  tax_fee_inr numeric(12,2) not null check (tax_fee_inr >= 0),
  total_inr numeric(12,2) not null check (total_inr = subtotal_inr + shipping_fee_inr + tax_fee_inr),
  status text not null default 'pending'
    check (status in ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')),
  payment_method text not null default 'simulation'
    check (payment_method in ('simulation', 'provider')),
  payment_status text not null default 'simulated'
    check (payment_status in ('simulated', 'pending', 'paid', 'failed', 'refunded')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists orders_customer_created_idx
  on public.orders(customer_id, created_at desc);
create index if not exists orders_status_created_idx
  on public.orders(status, created_at desc);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  variant_id uuid references public.product_variants(id) on delete set null,
  product_name text not null,
  product_image_url text not null,
  size text not null,
  color_name text not null,
  quantity integer not null check (quantity between 1 and 50),
  unit_price_inr numeric(12,2) not null check (unit_price_inr > 0),
  line_total_inr numeric(12,2) generated always as (unit_price_inr * quantity) stored,
  created_at timestamptz not null default now()
);
create index if not exists order_items_order_idx on public.order_items(order_id, created_at);
create index if not exists order_items_variant_idx on public.order_items(variant_id);

alter table public.orders enable row level security;
alter table public.order_items enable row level security;
drop policy if exists "customers and admins read orders" on public.orders;
create policy "customers and admins read orders" on public.orders
  for select to authenticated using (
    customer_id = (select auth.uid()) or public.is_admin()
  );
drop policy if exists "customers and admins read order items" on public.order_items;
create policy "customers and admins read order items" on public.order_items
  for select to authenticated using (
    exists (
      select 1 from public.orders o
      where o.id = order_id
        and (o.customer_id = (select auth.uid()) or public.is_admin())
    )
  );
grant select on public.orders, public.order_items to authenticated;
revoke insert, update, delete on public.orders, public.order_items from anon, authenticated;

-- Returns a ten-minute, server-priced quote. The client sends selections and
-- quantities only; this function never reads client prices or totals.
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
    select p.id, pv.id, p.name, p.image_url, p.price_inr, p.is_active, pv.stock_quantity
      into v_product_id, v_variant_id, v_name, v_image, v_price, v_active, v_stock
      from public.products p
      join public.product_variants pv on pv.product_id = p.id
      where p.id = v_item.product_id
        and pv.size = v_item.size and pv.color_name = v_item.color_name;
    if not found or not v_active then
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

-- Validates the quote again while locking products/variants, snapshots the
-- order, and decrements stock in the same transaction. Retrying a quote is
-- idempotent: the existing order confirmation is returned.
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
    select p.id, pv.id, p.name, p.image_url, p.price_inr, p.is_active, pv.stock_quantity
      into v_product_id, v_variant_id, v_name, v_image, v_price, v_active, v_stock
      from public.products p
      join public.product_variants pv on pv.product_id = p.id
      where p.id = v_item.product_id and pv.id = v_item.variant_id
        and pv.size = v_item.size and pv.color_name = v_item.color_name;
    if not found or not v_active then
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

create or replace function public.admin_update_order_status(p_order_id uuid, p_new_status text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order public.orders%rowtype;
  v_item record;
begin
  if not public.is_admin() then
    raise exception 'administrator authorization required' using errcode = '42501';
  end if;
  select * into v_order from public.orders o where o.id = p_order_id for update;
  if not found then
    raise exception 'order was not found' using errcode = 'P0002';
  end if;
  if not (
    (v_order.status = 'pending' and p_new_status in ('confirmed', 'cancelled')) or
    (v_order.status = 'confirmed' and p_new_status in ('shipped', 'cancelled')) or
    (v_order.status = 'shipped' and p_new_status = 'delivered')
  ) then
    raise exception 'invalid order status transition: % to %', v_order.status, p_new_status using errcode = '22023';
  end if;
  if p_new_status = 'cancelled' then
    for v_item in select oi.variant_id, oi.quantity from public.order_items oi
      where oi.order_id = v_order.id and oi.variant_id is not null order by oi.variant_id
    loop
      update public.product_variants pv
        set stock_quantity = pv.stock_quantity + v_item.quantity, updated_at = now()
        where pv.id = v_item.variant_id;
    end loop;
  end if;
  update public.orders o set status = p_new_status, updated_at = now()
    where o.id = v_order.id;
  return p_new_status;
end;
$$;

create or replace function public.admin_order_summary()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total bigint;
  v_pending bigint;
begin
  if not public.is_admin() then
    raise exception 'administrator authorization required' using errcode = '42501';
  end if;
  select count(*), count(*) filter (where o.status = 'pending')
    into v_total, v_pending from public.orders o;
  return jsonb_build_object('total_orders', v_total, 'pending_orders', v_pending);
end;
$$;

revoke all on function public.create_checkout_quote(jsonb) from public, anon;
grant execute on function public.create_checkout_quote(jsonb) to authenticated;
revoke all on function public.place_simulated_order(uuid,text,text,text,text,text,text,text) from public, anon;
grant execute on function public.place_simulated_order(uuid,text,text,text,text,text,text,text) to authenticated;
revoke all on function public.admin_update_order_status(uuid,text) from public, anon;
grant execute on function public.admin_update_order_status(uuid,text) to authenticated;
revoke all on function public.admin_order_summary() from public, anon;
grant execute on function public.admin_order_summary() to authenticated;
