# NORVÉ

NORVÉ is a Flutter fashion storefront with a shared customer/admin product catalogue. Local products are development fixtures; live catalogue, inventory, and account actions require a configured Supabase project. Customer screens do not display development-catalogue notices.

## Supabase setup

1. Create a Supabase project and apply all versioned migrations in `supabase/migrations/` using the Supabase CLI (`supabase db push`) or the dashboard SQL Editor. The catalogue migration enables RLS and limits catalogue writes to users whose UUID is in `admin_users`. The Phase 4C migration creates checkout quotes, orders, order-item snapshots, and trusted checkout/fulfilment RPCs. The Phase 5 migration adds own-user customer profiles and saved addresses, plus an order-time address snapshot extension. Applying a migration locally does not apply it to a remote Supabase project.
2. In Supabase Auth, enable the Email provider. Choose whether sign-up requires email confirmation and configure the confirmation and password-recovery email templates.
3. Configure the Supabase Auth URL Configuration. Add the deployed NORVÉ account callback URL to the redirect allow list and set it as the Site URL or pass it as `SUPABASE_AUTH_REDIRECT_URL`. For native builds, register the matching deep-link scheme with each target platform and add that URI to Supabase's allowed redirects. Password recovery links open the app's password update screen when the recovery link returns through the registered callback.
4. Create the first administrator account through Supabase Auth (or the project owner's trusted dashboard). From the trusted SQL Editor, provision its Auth UUID:

   ```sql
   insert into public.admin_users (user_id)
   select id from auth.users where email = 'admin@example.com';
   ```

   Verify that exactly one row was inserted. Never provision membership from the app, user-editable metadata, or a client role flag. Remove access by deleting that row. The app allows customer self-registration; administrator registration remains owner-controlled.
5. The workspace-root `supabase.local.json` supplies `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and `SUPABASE_AUTH_REDIRECT_URL` as Dart defines. Keep this local file out of version control. Use only a Supabase publishable key in the Flutter client. Start Chrome with:

   ```powershell
   flutter run -d chrome --web-port=3000 --dart-define-from-file=supabase.local.json
   ```

   The app accepts an `sb_publishable_` key, not a secret or service-role key. Never put a service-role key, secret key, or database password in the app or this file.
6. Customers can create accounts and sign in from Account. Supabase Auth restores saved sessions when the app starts. Admin Sign In authenticates through the same Auth provider, then verifies membership against `admin_users`; catalogue writes are independently protected by the migration's RLS policies and `is_admin()` database function.

The account, sign-in, recovery, profile and address management, checkout, order history, and administrator order-management flows are implemented. Before live use, apply all migrations to the target Supabase project, configure email confirmation/recovery redirects, provision the first administrator, and confirm the project's RLS/RPC policies. Live backend security has not been asserted based only on client code.

## Data behavior

Products and variants are stored in `products` and `product_variants`, with exact whole-rupee `numeric(12,2)` prices. Product changes are saved atomically through `save_product`, then the shared Riverpod catalogue refreshes when administrator access changes. Public users can read active products and their categories/variants. Only explicitly provisioned administrators can modify catalogue and inventory.

Checkout requests a short-lived quote from `create_checkout_quote`; the client sends product/variant selections and quantities, never prices or totals. The quote and `place_simulated_order_with_address` use current database prices and settings. Order insertion, item snapshots, inventory decrement, quote consumption, and the full delivery-address snapshot run within one database transaction. Customer reads are restricted to their own rows; administrator visibility and status changes depend on `is_admin()` and database policies. The current shipping and tax policy is configurable in the owner-managed singleton `checkout_settings` row; both fees default to ₹0 until the project owner sets approved values. Customers see those exact configured amounts before placing an order.

Profile writes use the signed-in Auth UUID on the server, while the email shown in Account comes from the current Auth session. Saved address reads and writes are protected by own-user RLS and server-side RPC ownership checks. The database serializes default-address changes and promotes the earliest remaining address when a default is deleted. Checkout preselects the saved default when available; its order call snapshots the chosen delivery fields so later address edits do not rewrite existing orders.

The checkout confirmation is explicitly simulated: no payment method is collected and no money is taken. Dashboard summaries count persisted orders only; no sample orders, sales, or revenue are generated.

## Development checks

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port=3000 --dart-define-from-file=supabase.local.json
```
