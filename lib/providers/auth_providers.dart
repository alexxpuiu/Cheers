import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../services/trips_repository.dart';

/// The Supabase client singleton, exposed to Riverpod.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => SupabaseService.client,
);

/// Repository facade for `trips` / `trip_members`.
final tripsRepositoryProvider = Provider<TripsRepository>(
  (ref) => TripsRepository(ref.watch(supabaseClientProvider)),
);

/// Broadcast stream of auth changes — emits `null` when signed out.
final authStateProvider = StreamProvider<User?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  yield client.auth.currentUser;
  await for (final state in client.auth.onAuthStateChange) {
    yield state.session?.user;
  }
});

/// Currently signed-in [User], or `null` — reactive but non-async at read time.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).asData?.value;
});

/// Convenience wrapper around Supabase auth calls (anonymous sign-in +
/// display-name updates + sign-out). Kept as an ordinary controller — the
/// screens await these methods and show their own error state.
class AuthController {
  AuthController(this._ref);

  final Ref _ref;

  GoTrueClient get _auth => _ref.read(supabaseClientProvider).auth;

  Future<User> signInAnonymouslyAs(String displayName) async {
    final trimmed = displayName.trim();
    // Guard against the request hanging (unreachable Supabase URL, offline,
    // DNS stalls, etc). The gotrue SDK has no default HTTP timeout.
    final response = await _auth
        .signInAnonymously(
          data: {
            if (trimmed.isNotEmpty) 'display_name': trimmed,
          },
        )
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () => throw const _SignInTimeout(),
        );
    final user = response.user;
    if (user == null) {
      throw StateError('Anonymous sign-in returned no user.');
    }
    return user;
  }

  Future<void> updateDisplayName(String displayName) async {
    await _auth.updateUser(
      UserAttributes(data: {'display_name': displayName.trim()}),
    );
  }

  Future<void> signOut() => _auth.signOut();
}

final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(ref),
);

/// Thrown when `signInAnonymously` doesn't respond within the timeout. Kept
/// as a distinct type so [LoginScreen] can render a friendlier message.
class _SignInTimeout implements Exception {
  const _SignInTimeout();
  @override
  String toString() =>
      "Couldn't reach Supabase. Check your connection and the SUPABASE_URL "
      'in your .env, then try again.';
}
