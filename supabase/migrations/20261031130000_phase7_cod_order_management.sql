-- NORVÉ Phase 7: Cash on Delivery and guarded order lifecycle.
-- Apply after 20261029000000_catalogue_inventory.sql,
-- 20261029130000_phase4c_orders.sql, 20261030100000_customer_profiles_addresses.sql,
-- and 20261031120000_phase6_product_store.sql.
-- This migration is additive and does not delete order or inventory records.

begin;

do $$
begin
  if to_regclass('public.orders') is null
     or to_regclass('public.order_items') is null
     or to_regclass('public.checkout_quotes') is null
     or to_regclass('public.product_variants') is null then
    raise exception 'Phase 7 requires the Phase 4C order and Phase 6 catalogue schema';
  end if;
  if to_regprocedure('public.is_admin()') is null
     or to_regprocedure('public.create_checkout_quote(jsonb)') is null
     or to_regprocedure('public.place_simulated_order(uuid,text,text,text,text,text,text,text)') is null
     or to_regprocedure('public.place_simulated_order_with_address(uuid,text,text,text,text,text,text,text,text,text,text)') is null then
    raise exception 'Phase 7 requires the Phase 4C–6 authorization and checkout RPCs';
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='product_variants'
                   and column_name='price_override_inr')
     or not exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='product_variants'
                   and column_name='is_available') then
    raise exception 'Phase 7 requires Phase 6 variant pricing and availability columns';
  end if;
end $$;

-- Replace legacy simulated payment values conservatively. Nothing is marked
-- collected from historical simulated/paid states without verified cash receipt.
alter table public.orders alter column payment_method set default 'cod';
alter table public.orders alter column payment_status set default 'pending';
alter table public.orders drop constraint if exists orders_status_check;
alter table public.orders drop constraint if exists orders_payment_method_check;
alter table public.orders drop constraint if exists orders_payment_status_check;
update public.orders
set payment_method = 'cod',
    payment_status = case when payment_status = 'collected' then 'collected' else 'pending' end
where payment_method is distinct from 'cod'
   or payment_status not in ('pending', 'collected');

alter table public.orders add constraint orders_status_check
  check (status in ('pending','confirmed','processing','shipped','out_for_delivery','delivered','cancelled'));
alter table public.orders add constraint orders_payment_method_check
  check (payment_method = 'cod');
alter table public.orders add constraint orders_payment_status_check
  check (payment_status in ('pending','collected'));
create index if not exists orders_payment_status_created_idx
  on public.orders(payment_status, created_at desc);

-- Server-priced COD placement. This keeps Phase 6 quote validation, stable row
-- locks, stock checks/deduction, quote idempotency and immutable item snapshots.
create or replace function public.place_cod_order(
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
    or nullif(trim(p_postal_code), '') is null or length(trim(p_postal_code)) not between 3 and 16 then
    raise exception 'delivery details are invalid' using errcode = '22023';
  end if;

  select * into v_quote from public.checkout_quotes q
    where q.id = p_quote_id and q.customer_id = v_customer_id for update;
  if not found then raise exception 'checkout quote was not found' using errcode = 'P0002'; end if;
  select * into v_existing from public.orders o where o.checkout_quote_id = v_quote.id;
  if found then
    return jsonb_build_object('id',v_existing.id,'order_reference',v_existing.order_reference,
      'subtotal_inr',v_existing.subtotal_inr,'shipping_fee_inr',v_existing.shipping_fee_inr,
      'tax_fee_inr',v_existing.tax_fee_inr,'total_inr',v_existing.total_inr,
      'status',v_existing.status,'payment_method',v_existing.payment_method,
      'payment_status',v_existing.payment_status,'created_at',v_existing.created_at);
  end if;
  if v_quote.expires_at <= now() then
    raise exception 'checkout quote expired; review your order again' using errcode = 'P0001';
  end if;

  for v_product_id in
    select distinct i.product_id
    from jsonb_to_recordset(v_quote.items) as i(product_id uuid, variant_id uuid,
      product_name text, product_image_url text, size text, color_name text,
      quantity integer, unit_price_inr numeric, line_total_inr numeric)
    order by i.product_id
  loop
    perform 1 from public.products p where p.id = v_product_id for update;
    if not found then raise exception 'a selected product is no longer available' using errcode = 'P0001'; end if;
  end loop;
  for v_variant_id in
    select i.variant_id from jsonb_to_recordset(v_quote.items) as i(
      product_id uuid, variant_id uuid, product_name text, product_image_url text,
      size text, color_name text, quantity integer, unit_price_inr numeric, line_total_inr numeric)
    order by i.variant_id
  loop
    perform 1 from public.product_variants pv where pv.id = v_variant_id for update;
    if not found then raise exception 'a selected variant is no longer available' using errcode = 'P0001'; end if;
  end loop;

  for v_item in
    select i.product_id,i.variant_id,i.size,i.color_name,i.quantity,i.unit_price_inr
    from jsonb_to_recordset(v_quote.items) as i(product_id uuid,variant_id uuid,
      product_name text,product_image_url text,size text,color_name text,
      quantity integer,unit_price_inr numeric,line_total_inr numeric)
    order by i.variant_id
  loop
    select p.id,pv.id,p.name,p.image_url,coalesce(pv.price_override_inr,p.price_inr),
      p.is_active,pv.stock_quantity,pv.is_available
      into v_product_id,v_variant_id,v_name,v_image,v_price,v_active,v_stock,v_available
      from public.products p join public.product_variants pv on pv.product_id=p.id
      where p.id=v_item.product_id and pv.id=v_item.variant_id
        and pv.size=v_item.size and pv.color_name=v_item.color_name;
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

  select s.shipping_fee_inr,s.tax_fee_inr into v_shipping,v_tax
    from public.checkout_settings s where s.singleton=true for share;
  if not found or v_shipping <> v_quote.shipping_fee_inr or v_tax <> v_quote.tax_fee_inr then
    raise exception 'delivery or tax charges changed; review your order again' using errcode = 'P0001';
  end if;
  select u.email into v_email from auth.users u where u.id=v_customer_id;
  if v_email is null then raise exception 'customer email is unavailable' using errcode = 'P0001'; end if;

  insert into public.orders(customer_id,checkout_quote_id,customer_email,customer_name,phone,
    address_line_1,address_line_2,city,region,postal_code,subtotal_inr,shipping_fee_inr,
    tax_fee_inr,total_inr,status,payment_method,payment_status)
  values(v_customer_id,v_quote.id,v_email,trim(p_customer_name),trim(p_phone),
    trim(p_address_line_1),coalesce(trim(p_address_line_2),''),trim(p_city),trim(p_region),
    trim(p_postal_code),v_quote.subtotal_inr,v_quote.shipping_fee_inr,v_quote.tax_fee_inr,
    v_quote.total_inr,'pending','cod','pending') returning * into v_order;

  for v_item in
    select i.product_id,i.variant_id,i.product_name,i.product_image_url,i.size,i.color_name,
      i.quantity,i.unit_price_inr
    from jsonb_to_recordset(v_quote.items) as i(product_id uuid,variant_id uuid,
      product_name text,product_image_url text,size text,color_name text,
      quantity integer,unit_price_inr numeric,line_total_inr numeric)
    order by i.variant_id
  loop
    update public.product_variants pv set stock_quantity=pv.stock_quantity-v_item.quantity,updated_at=now()
      where pv.id=v_item.variant_id;
    insert into public.order_items(order_id,product_id,variant_id,product_name,product_image_url,
      size,color_name,quantity,unit_price_inr)
    values(v_order.id,v_item.product_id,v_item.variant_id,v_item.product_name,
      v_item.product_image_url,v_item.size,v_item.color_name,v_item.quantity,v_item.unit_price_inr);
  end loop;
  update public.checkout_quotes q set consumed_at=now() where q.id=v_quote.id;
  return jsonb_build_object('id',v_order.id,'order_reference',v_order.order_reference,
    'subtotal_inr',v_order.subtotal_inr,'shipping_fee_inr',v_order.shipping_fee_inr,
    'tax_fee_inr',v_order.tax_fee_inr,'total_inr',v_order.total_inr,'status',v_order.status,
    'payment_method',v_order.payment_method,'payment_status',v_order.payment_status,
    'created_at',v_order.created_at);
end;
$$;

-- The existing Phase 5 address snapshot wrapper serializes by quote. This
-- COD counterpart preserves that behavior and only writes the snapshot once.
create or replace function public.place_cod_order_with_address(
  p_quote_id uuid,p_customer_name text,p_phone text,p_house_flat_building text,
  p_street_area text,p_landmark text,p_city text,p_state text,p_postal_code text,
  p_country text,p_address_label text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_user_id uuid := auth.uid(); v_existing_id uuid; v_result jsonb;
begin
  if v_user_id is null then raise exception 'customer sign-in is required' using errcode='28000'; end if;
  if nullif(trim(p_house_flat_building),'') is null or length(trim(p_house_flat_building))>120
    or nullif(trim(p_street_area),'') is null or length(trim(p_street_area))>160
    or length(coalesce(p_landmark,''))>120 or nullif(trim(p_country),'') is null
    or length(trim(p_country))>80 or p_address_label not in ('Home','Work','Other') then
    raise exception 'delivery address details are invalid' using errcode='22023';
  end if;
  perform 1 from public.checkout_quotes q where q.id=p_quote_id and q.customer_id=v_user_id for update;
  if not found then raise exception 'checkout quote was not found' using errcode='P0002'; end if;
  select o.id into v_existing_id from public.orders o where o.checkout_quote_id=p_quote_id;
  v_result := public.place_cod_order(p_quote_id,p_customer_name,p_phone,
    trim(p_house_flat_building),trim(p_street_area),p_city,p_state,p_postal_code);
  if v_existing_id is null then
    update public.orders o set address_label=p_address_label,street_area=trim(p_street_area),
      landmark=coalesce(trim(p_landmark),''),country=trim(p_country)
      where o.id=(v_result->>'id')::uuid and o.customer_id=v_user_id;
  end if;
  return v_result;
end;
$$;

create or replace function public.admin_update_order_status(p_order_id uuid,p_new_status text)
returns text language plpgsql security definer set search_path = '' as $$
declare v_order public.orders%rowtype; v_item record;
begin
  if not public.is_admin() then raise exception 'administrator authorization required' using errcode='42501'; end if;
  select * into v_order from public.orders o where o.id=p_order_id for update;
  if not found then raise exception 'order was not found' using errcode='P0002'; end if;
  if not ((v_order.status='pending' and p_new_status in ('confirmed','cancelled'))
    or (v_order.status='confirmed' and p_new_status in ('processing','cancelled'))
    or (v_order.status='processing' and p_new_status in ('shipped','cancelled'))
    or (v_order.status='shipped' and p_new_status='out_for_delivery')
    or (v_order.status='out_for_delivery' and p_new_status='delivered')) then
    raise exception 'invalid order status transition: % to %',v_order.status,p_new_status using errcode='22023';
  end if;
  if p_new_status='cancelled' then
    for v_item in select oi.variant_id,oi.quantity from public.order_items oi
      where oi.order_id=v_order.id and oi.variant_id is not null order by oi.variant_id
    loop
      update public.product_variants pv set stock_quantity=pv.stock_quantity+v_item.quantity,updated_at=now()
        where pv.id=v_item.variant_id;
    end loop;
  end if;
  update public.orders o set status=p_new_status,updated_at=now() where o.id=v_order.id;
  return p_new_status;
end;
$$;

create or replace function public.admin_mark_cod_collected(p_order_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare v_order public.orders%rowtype;
begin
  if not public.is_admin() then raise exception 'administrator authorization required' using errcode='42501'; end if;
  select * into v_order from public.orders o where o.id=p_order_id for update;
  if not found then raise exception 'order was not found' using errcode='P0002'; end if;
  if v_order.payment_method <> 'cod' or v_order.status <> 'delivered' or v_order.payment_status <> 'pending' then
    raise exception 'COD collection can only be recorded once for a delivered order' using errcode='22023';
  end if;
  update public.orders o set payment_status='collected',updated_at=now() where o.id=v_order.id;
  return 'collected';
end;
$$;

-- Retire client access to every legacy payment-simulation placement RPC.
revoke all on function public.place_simulated_order(uuid,text,text,text,text,text,text,text) from public,anon,authenticated;
revoke all on function public.place_simulated_order_with_address(uuid,text,text,text,text,text,text,text,text,text,text) from public,anon,authenticated;
revoke all on function public.place_cod_order(uuid,text,text,text,text,text,text,text) from public,anon,authenticated;
revoke all on function public.place_cod_order_with_address(uuid,text,text,text,text,text,text,text,text,text,text) from public,anon;
grant execute on function public.place_cod_order_with_address(uuid,text,text,text,text,text,text,text,text,text,text) to authenticated;
revoke all on function public.admin_update_order_status(uuid,text) from public,anon;
grant execute on function public.admin_update_order_status(uuid,text) to authenticated;
revoke all on function public.admin_mark_cod_collected(uuid) from public,anon;
grant execute on function public.admin_mark_cod_collected(uuid) to authenticated;

commit;
