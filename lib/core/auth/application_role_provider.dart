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

  final adminAccess = ref.watch(adminAccessProvider);
  if (adminAccess.isLoading) {
    return const AsyncLoading();
  }
  if (adminAccess.hasError) {
    return AsyncError(adminAccess.error!, adminAccess.stackTrace!);
  }

  final isAdministrator = adminAccess.asData?.value ?? false;
  return AsyncData(
    isAdministrator
        ? ApplicationRole.administrator
        : ApplicationRole.customer,
  );
});
