import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase initialisation + convenience accessors.
///
/// Call [SupabaseService.init] exactly once at app startup (from `main`).
/// After that, use [SupabaseService.client] anywhere in the app, or the
/// short-hand [SupabaseService.auth] / [SupabaseService.db] getters.
///
/// The service degrades gracefully: if the `.env` file is missing the
/// Supabase entries, [isConfigured] stays `false` and the rest of the app
/// keeps running against the local Riverpod-only mock state.
class SupabaseService {
  SupabaseService._();

  static bool _initialised = false;

  /// `true` once [init] has completed successfully with real credentials.
  static bool get isConfigured => _initialised;

  /// The underlying Supabase client. Throws if [init] hasn't been called.
  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;
  static SupabaseQueryBuilder db(String table) => client.from(table);

  /// Currently signed-in user, or `null` if anonymous.
  static User? get currentUser => auth.currentUser;

  /// Broadcast stream of auth state changes (sign-in, sign-out, token refresh).
  static Stream<AuthState> get onAuthStateChange => auth.onAuthStateChange;

  /// Reads credentials from `dotenv` and initialises the Supabase SDK.
  ///
  /// No-op if either credential is missing — the app will still boot, just
  /// without a real backend.
  static Future<void> init() async {
    if (_initialised) return;

    final url = dotenv.maybeGet('SUPABASE_URL') ?? '';
    final publishableKey = dotenv.maybeGet('SUPABASE_PUBLISHABLE_KEY') ?? '';

    if (url.isEmpty || publishableKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'Cheers: SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY missing in .env — '
          'running without backend.',
        );
      }
      return;
    }

    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      debug: kDebugMode,
    );
    _initialised = true;
  }
}
