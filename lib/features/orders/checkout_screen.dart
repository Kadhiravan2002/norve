import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/theme/norve_theme.dart';
import '../account/customer_address_form_dialog.dart';
import '../account/customer_data_providers.dart';
import '../account/customer_data_repository.dart';
import '../bag/bag_provider.dart';
import '../products/product.dart';
import '../products/product_catalog_provider.dart';
import '../products/widgets/product_image.dart';
import 'order_providers.dart';
import 'order_repository.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _region = TextEditingController();
  final _postal = TextEditingController();
  final _landmark = TextEditingController();
  final _country = TextEditingController(text: 'India');
  bool _review = false;
  bool _quoting = false;
  bool _savingAddress = false;
  String? _error;
  CheckoutQuote? _quote;
  String? _selectedAddressId;
  String? _addressOwnerId;
  String _addressLabel = 'Other';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(checkoutControllerProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _region.dispose();
    _postal.dispose();
    _landmark.dispose();
    _country.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    ref.listen(authSessionProvider, (previous, next) {
      final oldId = previous?.asData?.value?.userId;
      final newId = next.asData?.value?.userId;
      if (oldId != newId) {
        setState(() {
          _addressOwnerId = null;
          _selectedAddressId = null;
          _addressLabel = 'Other';
          _name.clear();
          _phone.clear();
          _line1.clear();
          _line2.clear();
          _landmark.clear();
          _city.clear();
          _region.clear();
          _postal.clear();
          _country.text = 'India';
          _quote = null;
          _review = false;
        });
      }
    });
    final bag = ref.watch(bagProvider);
    final controller = ref.watch(checkoutControllerProvider);
    final products = ref.watch(productCatalogProvider);
    final confirmation = controller.confirmation;

    if (confirmation != null) {
      return _checkoutFrame(
        context,
        _confirmation(
          context,
          confirmation,
          onBack: () => _leaveCheckout(context, confirmation: true),
        ),
      );
    }
    if (session.isLoading) {
      return _checkoutFrame(
        context,
        const Center(child: CircularProgressIndicator()),
      );
    }
    if (session.hasError) {
      return _checkoutFrame(
        context,
        _message(
          context,
          'Your sign-in could not be checked. Try again before placing an order.',
          action: TextButton(
            onPressed: () => ref.invalidate(authSessionProvider),
            child: const Text('Retry'),
          ),
        ),
      );
    }
    if (session.asData?.value == null) {
      return _checkoutFrame(
        context,
        _message(
          context,
          'Sign in to review and place an order.',
          action: FilledButton(
            onPressed: () => context.go('/account'),
            child: const Text('Sign In'),
          ),
        ),
      );
    }
    final userId = session.asData!.value!.userId;
    final addressState = ref.watch(customerAddressesProvider(userId));
    final savedAddresses = addressState.asData?.value;
    if (savedAddresses != null && _addressOwnerId != userId) {
      _addressOwnerId = userId;
      final preferred = savedAddresses.where((address) => address.isDefault);
      if (preferred.isNotEmpty) {
        final address = preferred.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedAddressId == null) _applyAddress(address);
        });
      }
    }
    if (bag.isEmpty) {
      return _checkoutFrame(
        context,
        _message(
          context,
          'Your bag is empty.',
          action: FilledButton(
            onPressed: () => context.go('/shop'),
            child: const Text('Continue Shopping'),
          ),
        ),
      );
    }

    return _checkoutFrame(
      context,
      Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width >= 1024
                ? 1000
                : MediaQuery.sizeOf(context).width >= 768
                ? 840
                : 720,
          ),
          child: CustomScrollView(
            key: const ValueKey('checkout-scroll'),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (MediaQuery.sizeOf(context).width < 768)
                            IconButton(
                              tooltip: 'Back',
                              onPressed: () => _leaveCheckout(context),
                              icon: const Icon(Icons.arrow_back),
                            ),
                          Expanded(
                            child: Text(
                              'Checkout',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: NorveColors.charcoal),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _review
                            ? 'Review your delivery details and order.'
                            : 'Delivery details',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: NorveColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _review
                      ? _reviewCard(
                          context,
                          ref,
                          session.asData!.value!.email ?? '',
                          bag,
                          products,
                        )
                      : _deliveryForm(
                          context,
                          session.asData!.value!.email ?? '',
                          userId,
                          addressState,
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Text(
                          _error!,
                          key: const ValueKey('checkout-error'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: NorveColors.charcoal),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (!_review)
                        _totalsCard(
                          context,
                          items: bag
                              .map((item) => _estimatedLine(item, products))
                              .toList(),
                          subtotal: bag.fold(
                            0,
                            (sum, item) => sum + item.lineTotal,
                          ),
                          shipping: null,
                          tax: null,
                          total: null,
                          estimated: true,
                        ),
                      const SizedBox(height: 16),
                      if (_review)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: controller.isSubmitting
                                    ? null
                                    : () => setState(() => _review = false),
                                child: const Text('Edit Details'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                key: const ValueKey('confirm-cod-order'),
                                onPressed: controller.isSubmitting
                                    ? null
                                    : _placeOrder,
                                style: FilledButton.styleFrom(
                                  backgroundColor: NorveColors.charcoal,
                                  foregroundColor: NorveColors.white,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: const RoundedRectangleBorder(),
                                ),
                                child: controller.isSubmitting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Place COD Order'),
                              ),
                            ),
                          ],
                        )
                      else
                        FilledButton(
                          key: const ValueKey('review-order'),
                          onPressed: _quoting ? null : _createQuote,
                          style: FilledButton.styleFrom(
                            backgroundColor: NorveColors.charcoal,
                            foregroundColor: NorveColors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: const RoundedRectangleBorder(),
                          ),
                          child: _quoting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Review Order'),
                        ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      canPop: !_review || controller.confirmation != null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _review && controller.confirmation == null && mounted) {
          setState(() => _review = false);
        }
      },
    );
  }

  Widget _checkoutFrame(
    BuildContext context,
    Widget child, {
    bool canPop = true,
    void Function(bool didPop, Object? result)? onPopInvokedWithResult,
  }) => Scaffold(
    backgroundColor: NorveColors.ivory,
    body: PopScope<Object?>(
      canPop: canPop,
      onPopInvokedWithResult: onPopInvokedWithResult,
      child: SafeArea(child: child),
    ),
  );

  void _leaveCheckout(BuildContext context, {bool confirmation = false}) {
    if (!confirmation && _review) {
      setState(() => _review = false);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(confirmation ? '/account/orders' : '/bag');
    }
  }

  Widget _deliveryForm(
    BuildContext context,
    String email,
    String userId,
    AsyncValue<List<CustomerAddress>> addressState,
  ) => Material(
    color: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NorveColors.white,
        border: Border.all(color: NorveColors.line),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Contact', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              email,
              key: const ValueKey('checkout-email'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            _field(_name, 'Full name'),
            _field(
              _phone,
              'Phone number',
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  value == null ||
                      !RegExp(r'^[0-9+() .-]{7,24}$').hasMatch(value.trim())
                  ? 'Enter a valid phone number.'
                  : null,
            ),
            const SizedBox(height: 10),
            Text(
              'Delivery address',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _savedAddressPicker(context, userId, addressState),
            Text(
              'Selecting a saved address fills these fields. Changes here apply to this order only.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: NorveColors.muted),
            ),
            const SizedBox(height: 12),
            _field(_line1, 'House / Flat / Building'),
            _field(_line2, 'Street / Area'),
            _field(_landmark, 'Landmark (optional)', optional: true),
            _field(_city, 'City'),
            _field(_region, 'State'),
            _field(
              _postal,
              'Postal / PIN code',
              keyboardType: TextInputType.number,
              validator: (value) =>
                  !RegExp(r'^[1-9][0-9]{5}$').hasMatch(value?.trim() ?? '')
                  ? 'Enter a valid 6-digit Indian PIN code.'
                  : null,
            ),
            _field(_country, 'Country'),
          ],
        ),
      ),
    ),
  );

  Widget _savedAddressPicker(
    BuildContext context,
    String userId,
    AsyncValue<List<CustomerAddress>> state,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      state.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, stack) => Row(
          children: [
            const Expanded(
              child: Text(
                'Saved addresses are unavailable. You can enter delivery details below.',
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.invalidate(customerAddressesProvider(userId)),
              child: const Text('Retry'),
            ),
          ],
        ),
        data: (addresses) => addresses.isEmpty
            ? const Text('No saved addresses yet.')
            : RadioGroup<String>(
                groupValue: _selectedAddressId,
                onChanged: (id) {
                  if (id == null) return;
                  for (final address in addresses) {
                    if (address.id == id) {
                      _applyAddress(address);
                      break;
                    }
                  }
                },
                child: Column(
                  children: [
                    for (final address in addresses)
                      Material(
                        color: Colors.transparent,
                        child: RadioListTile<String>(
                          key: ValueKey('checkout-address-${address.id}'),
                          value: address.id!,
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Text(address.label.label),
                              if (address.isDefault) ...[
                                const SizedBox(width: 8),
                                const Text(
                                  'Default',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${address.recipientName} · ${address.houseFlatBuilding}, ${address.streetArea}, ${address.city} ${address.postalCode}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _savingAddress ? null : () => _addAddress(userId),
          icon: const Icon(Icons.add, size: 18),
          label: Text(_savingAddress ? 'Saving address…' : 'Add a new address'),
        ),
      ),
      if (_error != null)
        Text(_error!, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool optional = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: optional
          ? null
          : validator ??
                (value) => value == null || value.trim().isEmpty
                    ? 'This field is required.'
                    : null,
    ),
  );

  void _applyAddress(CustomerAddress address) {
    setState(() {
      _selectedAddressId = address.id;
      _addressLabel = address.label.label;
      _name.text = address.recipientName;
      _phone.text = address.phone;
      _line1.text = address.houseFlatBuilding;
      _line2.text = address.streetArea;
      _landmark.text = address.landmark;
      _city.text = address.city;
      _region.text = address.state;
      _postal.text = address.postalCode;
      _country.text = address.country;
      _quote = null;
      _review = false;
      _error = null;
    });
  }

  Future<void> _addAddress(String userId) async {
    final addressState = ref.read(customerAddressesProvider(userId));
    final address = await showCustomerAddressForm(
      context,
      userId: userId,
      makeDefault: addressState.asData?.value.isEmpty == true,
    );
    if (address == null) return;
    setState(() {
      _savingAddress = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(customerDataRepositoryProvider)
          .saveAddress(address);
      ref.invalidate(customerAddressesProvider(userId));
      if (mounted) _applyAddress(saved);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is CustomerDataRepositoryException
              ? error.message
              : 'Address could not be saved. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingAddress = false);
    }
  }

  Widget _reviewCard(
    BuildContext context,
    WidgetRef ref,
    String email,
    List<BagItem> bag,
    List<Product> products,
  ) {
    final quote = _quote;
    if (quote == null) {
      return _message(
        context,
        'The order quote is unavailable. Review the bag again.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: NorveColors.white,
            border: Border.all(color: NorveColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivery to',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'PlayfairDisplay',
                  color: NorveColors.charcoal,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _addressLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'Inter',
                  color: NorveColors.muted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _name.text.trim(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Inter',
                  color: NorveColors.charcoal,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'Inter',
                  color: NorveColors.charcoal,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                _phone.text.trim(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'Inter',
                  color: NorveColors.charcoal,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_line1.text.trim()}${_line2.text.trim().isEmpty ? '' : ', ${_line2.text.trim()}'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Inter',
                  color: NorveColors.charcoal,
                  height: 1.45,
                  decoration: TextDecoration.none,
                ),
              ),
              if (_landmark.text.trim().isNotEmpty)
                Text(
                  'Landmark: ${_landmark.text.trim()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'Inter',
                    color: NorveColors.muted,
                    decoration: TextDecoration.none,
                  ),
                ),
              Text(
                '${_city.text.trim()}, ${_region.text.trim()} ${_postal.text.trim()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Inter',
                  color: NorveColors.charcoal,
                  height: 1.45,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                _country.text.trim(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Inter',
                  color: NorveColors.charcoal,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _totalsCard(
          context,
          items: quote.items.map((item) => _quotedLine(context, item)).toList(),
          subtotal: quote.subtotal,
          shipping: quote.shipping,
          tax: quote.tax,
          total: quote.total,
          estimated: false,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: NorveColors.ivory,
            border: Border.all(color: NorveColors.line),
          ),
          child: Text(
            'Cash on Delivery. Pay in cash when your order is delivered. Payment remains pending until an administrator confirms collection. Prices and stock will be checked again when you place the order.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _totalsCard(
    BuildContext context, {
    required List<Widget> items,
    required int subtotal,
    required int? shipping,
    required int? tax,
    required int? total,
    required bool estimated,
  }) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: NorveColors.white,
      border: Border.all(color: NorveColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          estimated ? 'Order summary' : 'Final order summary',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...items,
        const Divider(height: 24),
        _priceRow(context, 'Items subtotal', subtotal),
        if (shipping != null) _priceRow(context, 'Delivery', shipping),
        if (tax != null) _priceRow(context, 'Tax', tax),
        if (total != null) ...[
          const Divider(height: 22),
          _priceRow(context, 'Total', total, strong: true),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Live price, delivery and tax amounts are confirmed before the final step.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: NorveColors.muted, height: 1.4),
          ),
        ],
      ],
    ),
  );

  Widget _priceRow(
    BuildContext context,
    String label,
    int amount, {
    bool strong = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: strong ? FontWeight.w600 : null),
          ),
        ),
        Text(
          formatInr(amount),
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: strong ? FontWeight.w700 : null),
        ),
      ],
    ),
  );

  Widget _estimatedLine(BagItem item, List<Product> products) {
    final matches = products.where((product) => product.id == item.productId);
    final name = matches.isEmpty ? 'Unavailable product' : matches.first.name;
    final image = matches.isEmpty ? '' : matches.first.imageUrl;
    return _lineRow(
      context,
      name,
      image,
      item.size,
      item.color,
      item.quantity,
      item.unitPrice,
      item.lineTotal,
    );
  }

  Widget _quotedLine(BuildContext context, QuoteItem item) => _lineRow(
    context,
    item.productName,
    item.imageUrl,
    item.size,
    item.color,
    item.quantity,
    item.unitPrice,
    item.lineTotal,
  );

  Widget _lineRow(
    BuildContext context,
    String name,
    String image,
    String size,
    String color,
    int quantity,
    int unitPrice,
    int lineTotal,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 60, height: 76, child: ProductImage(url: image)),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: NorveColors.charcoal,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${productVariantLabel(size, color).isEmpty ? 'Single option' : productVariantLabel(size, color)} · Qty $quantity',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: NorveColors.muted),
              ),
              Text(
                '${formatInr(unitPrice)} each',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: NorveColors.charcoal),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: Text(
            formatInr(lineTotal),
            maxLines: 1,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: NorveColors.charcoal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _createQuote() async {
    if (!_formKey.currentState!.validate()) return;
    final items = ref.read(bagProvider);
    if (items.isEmpty) return;
    setState(() {
      _quoting = true;
      _error = null;
    });
    try {
      final quote = await ref.read(orderRepositoryProvider).createQuote(items);
      if (mounted) {
        setState(() {
          _quote = quote;
          _review = true;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _placeOrder() async {
    final quote = _quote;
    if (quote == null) return;
    try {
      await ref
          .read(checkoutControllerProvider.notifier)
          .placeOrder(
            quote.id,
            DeliveryDetails(
              customerName: _name.text,
              phone: _phone.text,
              addressLine1: _line1.text,
              addressLine2: _line2.text,
              city: _city.text,
              region: _region.text,
              postalCode: _postal.text,
              addressLabel: _addressLabel,
              streetArea: _line2.text,
              landmark: _landmark.text,
              country: _country.text,
            ),
          );
      ref.invalidate(customerOrdersProvider);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    final text = message.toLowerCase();
    if (text.contains('stock') ||
        text.contains('variant') ||
        text.contains('price') ||
        text.contains('quote')) {
      return message;
    }
    if (text.contains('42501') ||
        text.contains('authorization') ||
        text.contains('jwt')) {
      return 'Your sign-in could not be verified. Sign in again and retry.';
    }
    if (error is OrderRepositoryException) return error.message;
    return 'We could not place the order. Check your connection and try again.';
  }

  Widget _confirmation(
    BuildContext context,
    OrderConfirmation order, {
    required VoidCallback onBack,
  }) => SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          width: double.infinity,
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 380 ? 16 : 24,
          ),
          decoration: BoxDecoration(
            color: NorveColors.white,
            border: Border.all(color: NorveColors.line),
          ),
          child: DefaultTextStyle(
            style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
                .copyWith(
                  fontFamily: 'Inter',
                  color: NorveColors.charcoal,
                  decoration: TextDecoration.none,
                ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                const Icon(
                  Icons.check_circle_outline,
                  size: 40,
                  color: NorveColors.charcoal,
                ),
                const SizedBox(height: 14),
                Text(
                  'Your order is confirmed',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFamily: 'PlayfairDisplay',
                    color: NorveColors.charcoal,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Reference ${order.reference}',
                  key: const ValueKey('order-reference'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Inter',
                    color: NorveColors.charcoal,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 18),
                _priceRow(context, 'Order total', order.total, strong: true),
                _confirmationRow(
                  context,
                  'Order status',
                  orderStatusLabel(order.status),
                ),
                _confirmationRow(context, 'Payment method', 'Cash on Delivery'),
                _confirmationRow(
                  context,
                  'Payment',
                  paymentStatusLabel(order.paymentStatus),
                ),
                const SizedBox(height: 14),
                Text(
                  'Pay in cash when your order is delivered. Payment remains pending until collection is confirmed.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'Inter',
                    color: NorveColors.muted,
                    height: 1.45,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => context.go('/account/orders'),
                  style: FilledButton.styleFrom(
                    backgroundColor: NorveColors.charcoal,
                    foregroundColor: NorveColors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: const Text('View Your Orders'),
                ),
                TextButton(
                  onPressed: () => context.go('/shop'),
                  child: const Text('Continue Shopping'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _confirmationRow(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'Inter',
                color: NorveColors.muted,
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'Inter',
                color: NorveColors.charcoal,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      );

  Widget _message(BuildContext context, String message, {Widget? action}) =>
      SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (action != null) ...[const SizedBox(height: 16), action],
              ],
            ),
          ),
        ),
      );
}
