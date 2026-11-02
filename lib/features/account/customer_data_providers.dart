import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import 'customer_data_repository.dart';

final customerDataRepositoryProvider = Provider<CustomerDataRepository>((ref) {
  return SupabaseCustomerDataRepository(ref.watch(supabaseClientProvider));
});

final customerProfileProvider = FutureProvider.family<CustomerProfile?, String>(
  (ref, userId) async {
    final session = ref.watch(authSessionProvider).asData?.value;
    if (session == null || session.userId != userId) {
      throw const CustomerDataRepositoryException(
        'Sign in to view your profile.',
      );
    }
    final profile = await ref
        .watch(customerDataRepositoryProvider)
        .loadProfile();
    if (profile != null && profile.userId != userId) {
      throw const CustomerDataRepositoryException(
        'The profile does not belong to the signed-in customer.',
      );
    }
    return profile;
  },
);

final customerAddressesProvider =
    FutureProvider.family<List<CustomerAddress>, String>((ref, userId) async {
      final session = ref.watch(authSessionProvider).asData?.value;
      if (session == null || session.userId != userId) {
        throw const CustomerDataRepositoryException(
          'Sign in to view saved addresses.',
        );
      }
      final addresses = await ref
          .watch(customerDataRepositoryProvider)
          .loadAddresses();
      if (addresses.any((address) => address.userId != userId)) {
        throw const CustomerDataRepositoryException(
          'An address does not belong to the signed-in customer.',
        );
      }
      return addresses;
    });
