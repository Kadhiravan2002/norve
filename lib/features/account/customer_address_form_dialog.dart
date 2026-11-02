import 'package:flutter/material.dart';

import 'customer_data_repository.dart';

Future<CustomerAddress?> showCustomerAddressForm(
  BuildContext context, {
  required String userId,
  CustomerAddress? address,
  bool makeDefault = false,
}) => showDialog<CustomerAddress>(
  context: context,
  builder: (context) => CustomerAddressFormDialog(
    userId: userId,
    address: address,
    makeDefault: makeDefault,
  ),
);

class CustomerAddressFormDialog extends StatefulWidget {
  const CustomerAddressFormDialog({
    super.key,
    required this.userId,
    this.address,
    this.makeDefault = false,
  });

  final String userId;
  final CustomerAddress? address;
  final bool makeDefault;

  @override
  State<CustomerAddressFormDialog> createState() =>
      _CustomerAddressFormDialogState();
}

class _CustomerAddressFormDialogState extends State<CustomerAddressFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _recipient;
  late final TextEditingController _phone;
  late final TextEditingController _house;
  late final TextEditingController _street;
  late final TextEditingController _landmark;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _postal;
  late final TextEditingController _country;
  late AddressLabel _label;
  late bool _isDefault;

  CustomerAddress? get _existing => widget.address;

  @override
  void initState() {
    super.initState();
    _recipient = TextEditingController(text: _existing?.recipientName ?? '');
    _phone = TextEditingController(text: _existing?.phone ?? '');
    _house = TextEditingController(text: _existing?.houseFlatBuilding ?? '');
    _street = TextEditingController(text: _existing?.streetArea ?? '');
    _landmark = TextEditingController(text: _existing?.landmark ?? '');
    _city = TextEditingController(text: _existing?.city ?? '');
    _state = TextEditingController(text: _existing?.state ?? '');
    _postal = TextEditingController(text: _existing?.postalCode ?? '');
    _country = TextEditingController(text: _existing?.country ?? 'India');
    _label = _existing?.label ?? AddressLabel.home;
    _isDefault = _existing?.isDefault ?? widget.makeDefault;
  }

  @override
  void dispose() {
    _recipient.dispose();
    _phone.dispose();
    _house.dispose();
    _street.dispose();
    _landmark.dispose();
    _city.dispose();
    _state.dispose();
    _postal.dispose();
    _country.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _existing == null ? 'Add delivery address' : 'Edit delivery address',
      style: Theme.of(context).textTheme.titleLarge,
    ),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AddressLabel>(
                initialValue: _label,
                decoration: const InputDecoration(labelText: 'Address label'),
                items: [
                  for (final label in AddressLabel.values)
                    DropdownMenuItem(value: label, child: Text(label.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _label = value);
                },
              ),
              const SizedBox(height: 12),
              _field(_recipient, 'Recipient full name', max: 120),
              _field(
                _phone,
                'Phone number',
                keyboard: TextInputType.phone,
                validator: _validatePhone,
                max: 24,
              ),
              _field(_house, 'House / Flat / Building', max: 120),
              _field(_street, 'Street / Area', max: 160),
              _field(
                _landmark,
                'Landmark (optional)',
                required: false,
                max: 120,
              ),
              _field(_city, 'City', max: 100),
              _field(_state, 'State', max: 100),
              _field(
                _postal,
                'Postal / PIN code',
                keyboard: TextInputType.number,
                validator: _validatePin,
                max: 6,
              ),
              _field(_country, 'Country', max: 80),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as default address'),
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _save,
        child: Text(_existing == null ? 'Save Address' : 'Save Changes'),
      ),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    int max = 180,
    TextInputType keyboard = TextInputType.streetAddress,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLength: max,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator:
          validator ??
          (value) => required && (value == null || value.trim().isEmpty)
              ? 'Enter $label.'
              : null,
    ),
  );

  String? _validatePhone(String? value) {
    final cleaned = value?.trim() ?? '';
    if (!RegExp(r'^\+?[0-9() .-]{7,24}$').hasMatch(cleaned)) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  String? _validatePin(String? value) {
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(value?.trim() ?? '')) {
      return 'Enter a valid 6-digit Indian PIN code.';
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CustomerAddress(
        id: _existing?.id,
        userId: widget.userId,
        label: _label,
        recipientName: _recipient.text.trim(),
        phone: _phone.text.trim(),
        houseFlatBuilding: _house.text.trim(),
        streetArea: _street.text.trim(),
        landmark: _landmark.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        postalCode: _postal.text.trim(),
        country: _country.text.trim(),
        isDefault: _isDefault,
      ),
    );
  }
}
