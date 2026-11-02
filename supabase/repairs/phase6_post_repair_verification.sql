-- Run after 20261031120000_phase6_product_store_repair.sql in Supabase SQL Editor.

-- Phase 6 columns and product image table.
select table_name, column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public'
  and (
    (table_name = 'categories' and column_name in ('description', 'image_url'))
    or (table_name = 'products' and column_name in ('sku', 'requires_size', 'requires_color'))
    or (table_name = 'product_variants' and column_name in ('sku', 'price_override_inr', 'is_available'))
    or (table_name = 'product_images' and column_name in (
      'id', 'product_id', 'image_url', 'storage_path', 'sort_order', 'is_primary'
    ))
  )
order by table_name, column_name;

-- Function identity, argument names, return types, security mode and privileges.
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  p.proargnames as argument_names,
  pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer,
  has_function_privilege('anon', p.oid, 'EXECUTE') as anon_can_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_can_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'is_admin', 'save_product', 'admin_set_variant_stock',
    'create_checkout_quote', 'place_simulated_order'
  )
order by p.proname, pg_get_function_identity_arguments(p.oid);

-- Confirm the administrator policies remain membership-gated.
select n.nspname as schema_name, c.relname as table_name,
       c.relrowsecurity as rls_enabled, c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where (n.nspname = 'public' and c.relname in (
         'admin_users', 'categories', 'products', 'product_variants', 'product_images'
       ))
   or (n.nspname = 'storage' and c.relname = 'objects')
order by schema_name, table_name;

select schemaname, tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where (schemaname = 'public' and tablename in (
         'admin_users', 'categories', 'products', 'product_variants', 'product_images'
       ))
   or (schemaname = 'storage' and tablename = 'objects'
       and (coalesce(qual, '') || ' ' || coalesce(with_check, '')) ilike '%norve-product-images%')
order by schemaname, tablename, policyname;

-- Verify image bucket configuration without returning any credentials.
select id, name, public, file_size_limit, allowed_mime_types
from storage.buckets
where id = 'norve-product-images';

-- Indexes and the variant price constraint.
select schemaname, tablename, indexname, indexdef
from pg_indexes
where schemaname = 'public'
  and indexname in (
    'products_sku_ci_unique', 'product_variants_sku_ci_unique',
    'product_images_one_primary_idx', 'product_images_order_idx'
  )
order by tablename, indexname;

select conname, pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = 'public.product_variants'::regclass
  and conname = 'product_variants_price_override_check';
