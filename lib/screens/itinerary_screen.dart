import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/itinerary.dart';
import '../models/poi.dart';
import '../models/trip.dart';
import '../providers/poi_providers.dart';
import '../providers/trip_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/glass.dart';

class ItineraryScreen extends ConsumerStatefulWidget {
  const ItineraryScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends ConsumerState<ItineraryScreen> {
  int _dayIndex = 0;

  bool _kickedOff = false;

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider(widget.tripId));
    final itinerary = ref.watch(itineraryProvider(widget.tripId));
    final catalogAsync = ref.watch(poiCatalogProvider);
    final catalog =
        catalogAsync.asData?.value ?? const PoiCatalog.empty();

    // Kick off generation once the catalog is loaded — generating before
    // that lands would produce stubs for every POI id in the bucket.
    if (!_kickedOff && catalog.isNotEmpty && itinerary == null) {
      _kickedOff = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(itineraryProvider(widget.tripId).notifier)
            .regenerate(trip, catalog);
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CircleIcon(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your itinerary',
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text(
                          '${trip.city} · ${trip.days} days',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _CircleIcon(
                    icon: Icons.refresh_rounded,
                    onTap: () => ref
                        .read(itineraryProvider(widget.tripId).notifier)
                        .regenerate(trip, catalog),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (itinerary == null)
                const Expanded(child: _GeneratingCard())
              else if (itinerary.stops.isEmpty)
                const Expanded(child: _EmptyItinerary())
              else ...[
                _DayTabs(
                  days: itinerary.dayNumbers.toList(),
                  selected: _dayIndex,
                  onSelect: (i) => setState(() => _dayIndex = i),
                  trip: trip,
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: _DayList(
                    key: ValueKey('day-$_dayIndex'),
                    stops: itinerary.forDay(
                        itinerary.dayNumbers.elementAt(_dayIndex)),
                    catalog: catalog,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 100,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Icon(icon, size: 20, color: AppColors.textPrimary),
    );
  }
}

class _DayTabs extends StatelessWidget {
  const _DayTabs({
    required this.days,
    required this.selected,
    required this.onSelect,
    required this.trip,
  });

  final List<int> days;
  final int selected;
  final ValueChanged<int> onSelect;
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final date = trip.startDate.add(Duration(days: i));
          final selectedNow = i == selected;
          return _DayChip(
            date: date,
            dayNumber: days[i],
            selected: selectedNow,
            onTap: () => onSelect(i),
          )
              .animate()
              .fadeIn(delay: (i * 60).ms, duration: 300.ms)
              .slideY(begin: -0.2, curve: Curves.easeOutCubic);
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.dayNumber,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final int dayNumber;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('E').format(date).toUpperCase();
    final dayNum = DateFormat('d').format(date);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: 66,
      child: GlassContainer(
        onTap: onTap,
        radius: 20,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        opacity: selected ? 0.30 : 0.10,
        borderOpacity: selected ? 0.65 : 0.25,
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x66FFB86B), Color(0x33FF6B8A)],
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(dayName,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: selected
                        ? AppColors.accent
                        : AppColors.textMuted)),
            const SizedBox(height: 6),
            Text(dayNum,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('Day $dayNumber',
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({
    super.key,
    required this.stops,
    required this.catalog,
  });
  final List<ItineraryStop> stops;
  final PoiCatalog catalog;

  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24, top: 4),
      itemCount: stops.length,
      itemBuilder: (context, i) {
        final stop = stops[i];
        final poi = catalog.require(stop.poiId);
        final isFirst = i == 0;
        final isLast = i == stops.length - 1;
        final isAnchorStop = isFirst || isLast;

        return _StopRow(
          poi: poi,
          time: _timeFmt.format(stop.arrival),
          isFirst: isFirst,
          isLast: isLast,
          isAnchorStop: isAnchorStop,
        )
            .animate()
            .fadeIn(delay: (i * 70).ms, duration: 340.ms)
            .slideX(begin: 0.08, curve: Curves.easeOutCubic);
      },
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.poi,
    required this.time,
    required this.isFirst,
    required this.isLast,
    required this.isAnchorStop,
  });

  final Poi poi;
  final String time;
  final bool isFirst;
  final bool isLast;
  final bool isAnchorStop;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 8,
                  color: isFirst ? Colors.transparent : Colors.white.withValues(alpha: 0.2),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: poi.category.color.withValues(alpha: 0.25),
                    border: Border.all(
                      color: poi.category.color,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isAnchorStop
                        ? Icons.home_rounded
                        : poi.category.icon,
                    size: 16,
                    color: poi.category.color,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassContainer(
                padding: const EdgeInsets.all(16),
                gradient: isAnchorStop
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.accent.withValues(alpha: 0.28),
                          AppColors.catDining.withValues(alpha: 0.15),
                        ],
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            time,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAnchorStop
                              ? (isFirst ? 'Start' : 'Return')
                              : poi.category.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: poi.category.color,
                          ),
                        ),
                        const Spacer(),
                        Text('${poi.avgVisitMinutes} min',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      poi.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      poi.address,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                    if (poi.blurb.isNotEmpty && !isAnchorStop) ...[
                      const SizedBox(height: 8),
                      Text(
                        poi.blurb,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratingCard extends StatelessWidget {
  const _GeneratingCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(28),
        radius: 30,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 26, color: AppColors.bgDeep),
            )
                .animate(onPlay: (c) => c.repeat())
                .rotate(duration: 3.seconds)
                .then()
                .shimmer(color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('Planning your days…',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Balancing categories, walking distance, opening hours.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.92, 0.92)),
    );
  }
}

class _EmptyItinerary extends StatelessWidget {
  const _EmptyItinerary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bookmark_outline_rounded,
                size: 36, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text('Nothing to plan yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Add a few places to your bucket list first.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
