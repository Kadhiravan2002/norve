import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_providers.dart';
import 'auth_providers.dart';

enum ApplicationRole { signedOut, customer, administrator }

final applicationRoleProvider = Provider<AsyncValue<ApplicationRole>>((ref) {
  final session = ref.watch(authSessionProvider);
  if (session.isLoading) return const AsyncLoading();
  if (session.hasError) {
    return AsyncError(session.error!, session.stackTrace!);
  }
  if (session.asData?.value == null) {
    return const AsyncData(ApplicationRole.signedOut);
  }

  return ref
      .watch(adminAccessProvider)
      .when(
        data: (isAdministrator) => AsyncData(
          isAdministrator
              ? ApplicationRole.administrator
              : ApplicationRole.customer,
        ),
        error: AsyncError.new,
        loading: () => const AsyncLoading(),
      );
});
