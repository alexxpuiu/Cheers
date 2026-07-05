import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_providers.dart';
import 'screens/create_trip_screen.dart';
import 'screens/home_screen.dart';
import 'screens/itinerary_screen.dart';
import 'screens/join_trip_screen.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/aurora_background.dart';

class CheersApp extends ConsumerWidget {
  const CheersApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = _buildRouter(ref);

    return MaterialApp.router(
      title: 'Cheers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) => AuroraBackground(child: child!),
    );
  }
}

GoRouter _buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      // Read the auth client directly: `currentUser` is updated synchronously
      // by Supabase inside `signInAnonymously` (via `_saveSession`), whereas
      // `authStateProvider` is a StreamProvider whose `async*` generator only
      // yields after several microtask hops. Using the stream here caused the
      // login screen to redirect back to `/login` immediately after a
      // successful sign-in, leaving the UI stuck on "Signing in…".
      final signedIn =
          ref.read(supabaseClientProvider).auth.currentUser != null;
      final atLogin = state.matchedLocation == '/login';
      if (!signedIn && !atLogin) return '/login';
      if (signedIn && atLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fadePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (_, state) => _fadePage(state, const HomeScreen()),
      ),
      GoRoute(
        path: '/create',
        pageBuilder: (_, state) =>
            _slidePage(state, const CreateTripScreen()),
      ),
      GoRoute(
        path: '/join',
        pageBuilder: (_, state) =>
            _slidePage(state, const JoinTripScreen()),
      ),
      GoRoute(
        path: '/trip/:id/map',
        pageBuilder: (_, state) => _fadePage(
          state,
          MapScreen(tripId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/trip/:id/itinerary',
        pageBuilder: (_, state) => _slidePage(
          state,
          ItineraryScreen(tripId: state.pathParameters['id']!),
        ),
      ),
    ],
  );
}

/// Bridges the Riverpod auth stream into a [Listenable] so GoRouter re-runs
/// its `redirect` whenever the signed-in user changes.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(WidgetRef ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: Transform.scale(
          scale: 0.98 + 0.02 * curved.value,
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 420),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}
