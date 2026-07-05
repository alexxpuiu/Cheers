import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/create_trip_screen.dart';
import 'screens/home_screen.dart';
import 'screens/itinerary_screen.dart';
import 'screens/map_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/aurora_background.dart';

class CheersApp extends StatelessWidget {
  const CheersApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (_, state) =>
              _fadePage(state, const HomeScreen()),
        ),
        GoRoute(
          path: '/create',
          pageBuilder: (_, state) =>
              _slidePage(state, const CreateTripScreen()),
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

    return MaterialApp.router(
      title: 'Cheers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) => AuroraBackground(child: child!),
    );
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
