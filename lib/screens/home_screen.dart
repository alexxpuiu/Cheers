import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/trip.dart';
import '../providers/trip_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/glass.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripStoreProvider).trips;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cheers',
                                  style: Theme.of(context).textTheme.displayLarge)
                              .animate()
                              .fadeIn(duration: 500.ms)
                              .slideY(begin: 0.15, curve: Curves.easeOutCubic),
                          const SizedBox(height: 6),
                          Text(
                            'Plans that feel like a night out.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ).animate().fadeIn(delay: 120.ms, duration: 500.ms),
                        ],
                      ),
                    ),
                    _AvatarPill(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Your trips',
                        style: Theme.of(context).textTheme.headlineSmall),
                    GlassButton(
                      label: 'New trip',
                      icon: Icons.add_rounded,
                      primary: true,
                      dense: true,
                      onTap: () => context.push('/create'),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              sliver: SliverList.separated(
                itemCount: trips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, i) => _TripCard(trip: trips[i], index: i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 100,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      opacity: 0.15,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.accentGradient,
            ),
            alignment: Alignment.center,
            child: Text(
              'O',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.bgDeep,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Text('Ola',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.15);
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.index});

  final Trip trip;
  final int index;

  static final _dateFmt = DateFormat('MMM d');

  @override
  Widget build(BuildContext context) {
    final range =
        '${_dateFmt.format(trip.startDate)} – ${_dateFmt.format(trip.endDate)}';

    final gradients = [
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF9F6B), Color(0xFFFF6B8A)],
      ),
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7C5CFF), Color(0xFF4FD1C5)],
      ),
      const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFB86B), Color(0xFF7C5CFF)],
      ),
    ];
    final grad = gradients[trip.coverGradient % gradients.length];

    return GlassContainer(
      radius: 28,
      padding: EdgeInsets.zero,
      onTap: () => context.push('/trip/${trip.id}/map'),
      child: SizedBox(
        height: 168,
        child: Stack(
          children: [
            // Gradient cover strip
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: grad.colors
                        .map((c) => c.withValues(alpha: 0.55))
                        .toList(),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      grad.colors.last.withValues(alpha: 0.6),
                      grad.colors.last.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _Chip(
                        icon: Icons.place_outlined,
                        label: trip.city,
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        icon: trip.mode == TripMode.group
                            ? Icons.groups_2_rounded
                            : Icons.person_rounded,
                        label: trip.mode == TripMode.group
                            ? '${trip.memberCount} together'
                            : 'Solo',
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall!
                            .copyWith(fontSize: 22),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded,
                              size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            '$range · ${trip.days} days',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 18, color: AppColors.textSecondary),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (120 + index * 90).ms, duration: 480.ms)
        .slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      opacity: 0.18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
