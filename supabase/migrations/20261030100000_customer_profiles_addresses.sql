-- NORVÉ Phase 5: customer profile and saved delivery address data.
-- Requires the catalogue and Phase 4C order migrations.

create table if not exists public.customer_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (length(trim(full_name)) between 1 and 120),
  phone text not null check (phone ~ '^[+]?[0-9() .-]{7,24}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.customer_profiles enable row level security;
drop policy if exists "customers manage own profile" on public.customer_profiles;
create policy "customers manage own profile" on public.customer_profiles
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
revoke all on public.customer_profiles from anon, authenticated;
grant select on public.customer_profiles to authenticated;

create table if not exists public.customer_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  address_label text not null check (address_label in ('Home', 'Work', 'Other')),
  recipient_name text not null check (length(trim(recipient_name)) between 1 and 120),
  phone text not null check (phone ~ '^[+]?[0-9() .-]{7,24}$'),
  house_flat_building text not null check (length(trim(house_flat_building)) between 1 and 120),
  street_area text not null check (length(trim(street_area)) between 1 and 160),
  landmark text not null default '' check (length(landmark) <= 120),
  city text not null check (length(trim(city)) between 1 and 100),
  state text not null check (length(trim(state)) between 1 and 100),
  postal_code text not null check (postal_code ~ '^[1-9][0-9]{5}$'),
  country text not null default 'India' check (length(trim(country)) between 1 and 80),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists customer_addresses_owner_created_idx
  on public.customer_addresses(user_id, created_at, id);
create unique index if not exists customer_addresses_one_default_per_user_idx
  on public.customer_addresses(user_id) where is_default;
alter table public.customer_addresses enable row level security;
drop policy if exists "customers manage own addresses" on public.customer_addresses;
create policy "customers manage own addresses" on public.customer_addresses
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
revoke all on public.customer_addresses from anon, authenticated;
grant select on public.customer_addresses to authenticated;

-- Addresses hold ordinary customer edits; profile ownership always comes from
-- auth.uid(), not a client-supplied user identifier.
create or replace function public.save_customer_profile(p_full_name text, p_phone text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.customer_profiles%rowtype;
begin
  if v_user_id is null then
    raise exception 'customer sign-in is required' using errcode = '28000';
  end if;
  if nullif(trim(p_full_name), '') is null or length(trim(p_full_name)) > 120
    or p_phone !~ '^[+]?[0-9() .-]{7,24}$'
  then
    raise exception 'profile details are invalid' using errcode = '22023';
  end if;
  insert into public.customer_profiles(user_id, full_name, phone)
    values (v_user_id, trim(p_full_name), trim(p_phone))
    on conflict (user_id) do update set
      full_name = excluded.full_name,
      phone = excluded.phone,
      updated_at = now()
    returning * into v_profile;
  return to_jsonb(v_profile);
end;
$$;

create or replace function public.save_customer_address(
  p_address_id uuid,
  p_address_label text,
  p_recipient_name text,
  p_phone text,
  p_house_flat_building text,
  p_street_area text,
  p_landmark text,
  p_city text,
  p_state text,
  p_postal_code text,
  p_country text,
  p_is_default boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_address public.customer_addresses%rowtype;
  v_make_default boolean;
begin
  if v_user_id is null then
    raise exception 'customer sign-in is required' using errcode = '28000';
  end if;
  if p_address_label not in ('Home', 'Work', 'Other')
    or nullif(trim(p_recipient_name), '') is null or length(trim(p_recipient_name)) > 120
    or p_phone !~ '^[+]?[0-9() .-]{7,24}$'
    or nullif(trim(p_house_flat_building), '') is null
      or length(trim(p_house_flat_building)) > 120
    or nullif(trim(p_street_area), '') is null or length(trim(p_street_area)) > 160
    or length(coalesce(p_landmark, '')) > 120
    or nullif(trim(p_city), '') is null or length(trim(p_city)) > 100
    or nullif(trim(p_state), '') is null or length(trim(p_state)) > 100
    or p_postal_code !~ '^[1-9][0-9]{5}$'
    or nullif(trim(p_country), '') is null or length(trim(p_country)) > 80
  then
    raise exception 'delivery address details are invalid' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 0)
  );
  if p_address_id is not null and not exists (
    select 1 from public.customer_addresses a
    where a.id = p_address_id and a.user_id = v_user_id
  ) then
    raise exception 'address was not found for this customer' using errcode = 'P0002';
  end if;
  v_make_default := coalesce(p_is_default, false) or not exists (
    select 1 from public.customer_addresses a
    where a.user_id = v_user_id and a.id is distinct from p_address_id
  );
  if v_make_default then
    update public.customer_addresses a set is_default = false, updated_at = now()
      where a.user_id = v_user_id and a.is_default;
  end if;

  insert into public.customer_addresses(
    id, user_id, address_label, recipient_name, phone, house_flat_building,
    street_area, landmark, city, state, postal_code, country, is_default
  ) values (
    coalesce(p_address_id, gen_random_uuid()), v_user_id, p_address_label,
    trim(p_recipient_name), trim(p_phone), trim(p_house_flat_building),
    trim(p_street_area), coalesce(trim(p_landmark), ''), trim(p_city),
    trim(p_state), trim(p_postal_code), trim(p_country), v_make_default
  )
  on conflict (id) do update set
    address_label = excluded.address_label,
    recipient_name = excluded.recipient_name,
    phone = excluded.phone,
    house_flat_building = excluded.house_flat_building,
    street_area = excluded.street_area,
    landmark = excluded.landmark,
    city = excluded.city,
    state = excluded.state,
    postal_code = excluded.postal_code,
    country = excluded.country,
    is_default = excluded.is_default,
    updated_at = now()
  where customer_addresses.user_id = v_user_id
  returning * into v_address;
  if not found then
    raise exception 'address could not be saved for this customer' using errcode = '42501';
  end if;
  return to_jsonb(v_address);
end;
$$;

create or replace function public.set_default_customer_address(p_address_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'customer sign-in is required' using errcode = '28000';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 0)
  );
  if not exists (
    select 1 from public.customer_addresses a
    where a.id = p_address_id and a.user_id = v_user_id
  ) then
    raise exception 'address was not found for this customer' using errcode = 'P0002';
  end if;
  update public.customer_addresses a set is_default = (a.id = p_address_id), updated_at = now()
    where a.user_id = v_user_id and a.is_default is distinct from (a.id = p_address_id);
end;
$$;

create or replace function public.delete_customer_address(p_address_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_was_default boolean;
  v_next_id uuid;
begin
  if v_user_id is null then
    raise exception 'customer sign-in is required' using errcode = '28000';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 0)
  );
  select a.is_default into v_was_default from public.customer_addresses a
    where a.id = p_address_id and a.user_id = v_user_id for update;
  if not found then
    raise exception 'address was not found for this customer' using errcode = 'P0002';
  end if;
  delete from public.customer_addresses a
    where a.id = p_address_id and a.user_id = v_user_id;
  if v_was_default then
    select a.id into v_next_id from public.customer_addresses a
      where a.user_id = v_user_id order by a.created_at, a.id limit 1;
    if v_next_id is not null then
      update public.customer_addresses a set is_default = true, updated_at = now()
        where a.id = v_next_id and a.user_id = v_user_id;
    end if;
  end if;
end;
$$;

-- Add immutable order-time address snapshot fields without rewriting Phase 4C.
alter table public.orders
  add column if not exists address_label text not null default 'Other'
    check (address_label in ('Home', 'Work', 'Other')),
  add column if not exists street_area text not null default '',
  add column if not exists landmark text not null default '',
  add column if not exists country text not null default 'India';

create or replace function public.place_simulated_order_with_address(
  p_quote_id uuid,
  p_customer_name text,
  p_phone text,
  p_house_flat_building text,
  p_street_area text,
  p_landmark text,
  p_city text,
  p_state text,
  p_postal_code text,
  p_country text,
  p_address_label text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing_id uuid;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'customer sign-in is required' using errcode = '28000';
  end if;
  if nullif(trim(p_house_flat_building), '') is null
    or length(trim(p_house_flat_building)) > 120
    or nullif(trim(p_street_area), '') is null or length(trim(p_street_area)) > 160
    or length(coalesce(p_landmark, '')) > 120
    or nullif(trim(p_country), '') is null or length(trim(p_country)) > 80
    or p_address_label not in ('Home', 'Work', 'Other')
  then
    raise exception 'delivery address details are invalid' using errcode = '22023';
  end if;

  -- Serialize idempotent retries on the quote before deciding whether to
  -- write the address snapshot. A retry never rewrites the original snapshot.
  perform 1 from public.checkout_quotes q
    where q.id = p_quote_id and q.customer_id = v_user_id for update;
  if not found then
    raise exception 'checkout quote was not found' using errcode = 'P0002';
  end if;
  select o.id into v_existing_id from public.orders o
    where o.checkout_quote_id = p_quote_id;

  v_result := public.place_simulated_order(
    p_quote_id, p_customer_name, p_phone,
    trim(p_house_flat_building),
    trim(p_street_area),
    p_city, p_state, p_postal_code
  );

  if v_existing_id is null then
    update public.orders o set
      address_label = p_address_label,
      street_area = trim(p_street_area),
      landmark = coalesce(trim(p_landmark), ''),
      country = trim(p_country)
    where o.id = (v_result ->> 'id')::uuid and o.customer_id = v_user_id;
  end if;
  return v_result;
end;
$$;

revoke all on function public.save_customer_profile(text, text) from public, anon;
grant execute on function public.save_customer_profile(text, text) to authenticated;
revoke all on function public.save_customer_address(uuid,text,text,text,text,text,text,text,text,text,text,boolean) from public, anon;
grant execute on function public.save_customer_address(uuid,text,text,text,text,text,text,text,text,text,text,boolean) to authenticated;
revoke all on function public.set_default_customer_address(uuid) from public, anon;
grant execute on function public.set_default_customer_address(uuid) to authenticated;
revoke all on function public.delete_customer_address(uuid) from public, anon;
grant execute on function public.delete_customer_address(uuid) to authenticated;
revoke all on function public.place_simulated_order(uuid,text,text,text,text,text,text,text) from public, anon, authenticated;
revoke all on function public.place_simulated_order_with_address(uuid,text,text,text,text,text,text,text,text,text,text) from public, anon;
grant execute on function public.place_simulated_order_with_address(uuid,text,text,text,text,text,text,text,text,text,text) to authenticated;
