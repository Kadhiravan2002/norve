import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/norve_theme.dart';
import 'customer_data_providers.dart';
import 'customer_data_repository.dart';

class CustomerProfileSection extends ConsumerStatefulWidget {
  const CustomerProfileSection({
    super.key,
    required this.userId,
    required this.email,
  });

  final String userId;
  final String email;

  @override
  ConsumerState<CustomerProfileSection> createState() =>
      _CustomerProfileSectionState();
}

class _CustomerProfileSectionState
    extends ConsumerState<CustomerProfileSection> {
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(customerProfileProvider(widget.userId));
    return _panel(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Personal details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (profile.hasValue)
                TextButton.icon(
                  onPressed: _saving ? null : () => _edit(profile.value),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Email', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 3),
          Text(widget.email, key: const ValueKey('profile-email')),
          const Divider(height: 24),
          profile.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => Row(
              children: [
                const Expanded(
                  child: Text('Profile details could not be loaded.'),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(customerProfileProvider(widget.userId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
            data: (value) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail('Full name', value?.fullName ?? ''),
                const SizedBox(height: 10),
                _detail('Phone number', value?.phone ?? ''),
                if (_saving) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 3),
      Text(value.isEmpty ? 'Not added yet' : value),
    ],
  );

  Widget _panel(BuildContext context, {required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: NorveColors.white,
      border: Border.all(color: NorveColors.line),
    ),
    child: child,
  );

  Future<void> _edit(CustomerProfile? profile) async {
    final edited = await showDialog<_ProfileFormValue>(
      context: context,
      builder: (context) => _ProfileFormDialog(profile: profile),
    );
    if (edited == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(customerDataRepositoryProvider)
          .saveProfile(fullName: edited.fullName, phone: edited.phone);
      ref.invalidate(customerProfileProvider(widget.userId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile details saved.')));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Profile could not be saved. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ProfileFormValue {
  const _ProfileFormValue(this.fullName, this.phone);
  final String fullName;
  final String phone;
}

class _ProfileFormDialog extends StatefulWidget {
  const _ProfileFormDialog({required this.profile});
  final CustomerProfile? profile;

  @override
  State<_ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends State<_ProfileFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile?.fullName ?? '');
    _phone = TextEditingController(text: widget.profile?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      'Edit personal details',
      style: Theme.of(context).textTheme.titleLarge,
    ),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your full name.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 24,
              decoration: const InputDecoration(labelText: 'Phone number'),
              validator: (value) =>
                  RegExp(r'^\+?[0-9() .-]{7,24}$').hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Enter a valid phone number.',
            ),
            const SizedBox(height: 4),
            const Text(
              'Email is managed by your sign-in and cannot be changed here.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _ProfileFormValue(_name.text.trim(), _phone.text.trim()),
          );
        },
        child: const Text('Save Changes'),
      ),
    ],
  );
}
