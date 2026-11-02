import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/norve_theme.dart';
import 'customer_address_form_dialog.dart';
import 'customer_data_providers.dart';
import 'customer_data_repository.dart';

class CustomerAddressesSection extends ConsumerStatefulWidget {
  const CustomerAddressesSection({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<CustomerAddressesSection> createState() =>
      _CustomerAddressesSectionState();
}

class _CustomerAddressesSectionState
    extends ConsumerState<CustomerAddressesSection> {
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(customerAddressesProvider(widget.userId));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NorveColors.white,
        border: Border.all(color: NorveColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saved addresses',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: Theme.of(context).textTheme.bodySmall),
          ],
          addresses.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Saved addresses could not be loaded.'),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      customerAddressesProvider(widget.userId),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (values) => values.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Text(
                      'Add a delivery address to make checkout quicker.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : Column(
                    children: [
                      for (final address in values)
                        _addressTile(context, address),
                    ],
                  ),
          ),
          if (addresses.hasValue)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _edit(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Address'),
              ),
            ),
          if (_saving) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _addressTile(
    BuildContext context,
    CustomerAddress address,
  ) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: NorveColors.ivory,
      border: Border.all(color: NorveColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              address.label.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (address.isDefault) ...[
              const SizedBox(width: 8),
              const Chip(
                label: Text('Default'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
            const Spacer(),
            PopupMenuButton<String>(
              tooltip: 'Address options',
              onSelected: (action) {
                if (action == 'edit') _edit(address);
                if (action == 'default') _setDefault(address);
                if (action == 'delete') _delete(address);
              },
              itemBuilder: (context) => [
                if (!address.isDefault)
                  const PopupMenuItem(
                    value: 'default',
                    child: Text('Set as default'),
                  ),
                const PopupMenuItem(value: 'edit', child: Text('Edit address')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete address'),
                ),
              ],
            ),
          ],
        ),
        Text(address.recipientName),
        Text(address.phone),
        const SizedBox(height: 4),
        Text('${address.houseFlatBuilding}, ${address.streetArea}'),
        if (address.landmark.isNotEmpty) Text('Landmark: ${address.landmark}'),
        Text('${address.city}, ${address.state} ${address.postalCode}'),
        Text(address.country),
      ],
    ),
  );

  Future<void> _edit([CustomerAddress? existing]) async {
    final addressState = ref.read(customerAddressesProvider(widget.userId));
    final updated = await showCustomerAddressForm(
      context,
      userId: widget.userId,
      address: existing,
      makeDefault: addressState.asData?.value.isEmpty == true,
    );
    if (updated == null) return;
    await _perform(() async {
      await ref.read(customerDataRepositoryProvider).saveAddress(updated);
      ref.invalidate(customerAddressesProvider(widget.userId));
    }, success: existing == null ? 'Address saved.' : 'Address updated.');
  }

  Future<void> _setDefault(CustomerAddress address) => _perform(() async {
    await ref
        .read(customerDataRepositoryProvider)
        .setDefaultAddress(address.id!);
    ref.invalidate(customerAddressesProvider(widget.userId));
  }, success: 'Default address updated.');

  Future<void> _delete(CustomerAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${address.label.label.toLowerCase()} address?'),
        content: const Text(
          'This address will be removed from your saved addresses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Address'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Address'),
          ),
        ],
      ),
    );
    if (confirmed != true || address.id == null) return;
    await _perform(() async {
      await ref.read(customerDataRepositoryProvider).deleteAddress(address.id!);
      ref.invalidate(customerAddressesProvider(widget.userId));
    }, success: 'Address deleted.');
  }

  Future<void> _perform(
    Future<void> Function() action, {
    required String success,
  }) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is CustomerDataRepositoryException) return error.message;
    return 'Address could not be saved. Check your connection and try again.';
  }
}
