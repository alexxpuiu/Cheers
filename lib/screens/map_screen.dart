import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../data/mock_pois.dart';
import '../main.dart' show kMapboxAccessToken;
import '../models/poi.dart';
import '../providers/trip_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/glass.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  String? _selectedPoiId;
  bool _showFilters = true;

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider(widget.tripId));
    final filters = ref.watch(categoryFilterProvider);
    final pois = MockPois.all
        .where((p) => filters.contains(p.category))
        .toList(growable: false);
    final bucketList =
        ref.watch(tripStoreProvider).byId(widget.tripId).bucketList;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildMap(pois: pois, bucketList: bucketList),
          ),

          // Subtle vignette so the top/bottom UI reads clearly on any map.
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.bgDeep.withValues(alpha: 0.55),
                      Colors.transparent,
                      AppColors.bgDeep.withValues(alpha: 0.75),
                    ],
                    stops: const [0, 0.25, 1],
                  ),
                ),
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _CircleIcon(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.go('/'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassContainer(
                      radius: 100,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.explore_rounded,
                              size: 18, color: AppColors.textPrimary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trip.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                Text('${trip.city} · ${trip.days} days',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CircleIcon(
                    icon: _showFilters
                        ? Icons.tune_rounded
                        : Icons.tune_outlined,
                    onTap: () =>
                        setState(() => _showFilters = !_showFilters),
                  ),
                ],
              ),
            ),
          ),

          // Category filter chips
          if (_showFilters)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 72),
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      for (final c in PoiCategory.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _CategoryChip(
                            category: c,
                            selected: filters.contains(c),
                            onTap: () => ref
                                .read(categoryFilterProvider.notifier)
                                .toggle(c),
                          ),
                        ),
                    ],
                  ),
                ).animate().fadeIn(duration: 260.ms).slideY(begin: -0.4),
              ),
            ),

          // Bucket-list bottom sheet
          _BucketSheet(
            tripId: widget.tripId,
            onOpenPoi: (poi) => setState(() => _selectedPoiId = poi.id),
            onGenerate: () => context.push('/trip/${widget.tripId}/itinerary'),
          ),

          // Selected POI card
          if (_selectedPoiId != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 240,
              child: _PoiDetailCard(
                poi: MockPois.byId(_selectedPoiId!),
                tripId: widget.tripId,
                onClose: () => setState(() => _selectedPoiId = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap({
    required List<Poi> pois,
    required List<String> bucketList,
  }) {
    if (kMapboxAccessToken.isEmpty) {
      return _FallbackMapBackdrop(
        pois: pois,
        selectedId: _selectedPoiId,
        bucketList: bucketList,
        onTapPin: (poi) => setState(() => _selectedPoiId = poi.id),
      );
    }

    final bucket = bucketList.toSet();
    // Mapbox raster tiles — style: dark-v11 @2x for retina.
    // We use the Mapbox Static Tiles API which works over standard HTTP
    // and only requires the public `pk.…` token.
    final tileUrl =
        'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/512/{z}/{x}/{y}@2x'
        '?access_token=$kMapboxAccessToken';

    return FlutterMap(
      options: MapOptions(
        initialCenter: const LatLng(MockPois.demoLat, MockPois.demoLng),
        initialZoom: 12.6,
        minZoom: 3,
        maxZoom: 18,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (_, __) => setState(() => _selectedPoiId = null),
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrl,
          tileSize: 512,
          zoomOffset: -1,
          retinaMode: false,
          userAgentPackageName: 'com.cheers.app',
          // Fade tiles in for a smoother feel.
          tileBuilder: (context, tileWidget, tile) => AnimatedOpacity(
            opacity: tile.loadFinishedAt == null ? 0 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: tileWidget,
          ),
        ),
        MarkerLayer(
          markers: [
            for (final p in pois)
              Marker(
                point: LatLng(p.lat, p.lng),
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: _MapPin(
                  poi: p,
                  selected: p.id == _selectedPoiId,
                  inBucket: bucket.contains(p.id),
                  onTap: () => setState(() => _selectedPoiId = p.id),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.poi,
    required this.selected,
    required this.inBucket,
    required this.onTap,
  });

  final Poi poi;
  final bool selected;
  final bool inBucket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 38.0 : (inBucket ? 34.0 : 28.0);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: poi.category.color.withValues(alpha: inBucket ? 0.95 : 0.85),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 1.0 : 0.85),
            width: selected ? 2.5 : (inBucket ? 2 : 1.4),
          ),
          boxShadow: [
            BoxShadow(
              color: poi.category.color
                  .withValues(alpha: selected ? 0.65 : 0.4),
              blurRadius: selected ? 18 : 10,
              spreadRadius: selected ? 2 : 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          poi.category.icon,
          size: selected ? 18 : 14,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final PoiCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: GlassContainer(
        radius: 100,
        onTap: onTap,
        opacity: selected ? 0.28 : 0.12,
        borderOpacity: selected ? 0.55 : 0.22,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: category.color,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: category.color.withValues(alpha: 0.7),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
              ),
            ),
            const SizedBox(width: 8),
            Text(category.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                )),
          ],
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

class _BucketSheet extends ConsumerWidget {
  const _BucketSheet({
    required this.tripId,
    required this.onOpenPoi,
    required this.onGenerate,
  });

  final String tripId;
  final ValueChanged<Poi> onOpenPoi;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider(tripId));
    final store = ref.read(tripStoreProvider);
    final items = trip.bucketList.map(MockPois.byId).toList();
    final anchor = trip.anchorPoiId;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GlassContainer(
            radius: 30,
            padding: EdgeInsets.zero,
            opacity: 0.16,
            borderOpacity: 0.3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Text('Bucket list',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(width: 8),
                      GlassContainer(
                        radius: 100,
                        opacity: 0.18,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        child: Text('${items.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                      const Spacer(),
                      if (items.length >= 2)
                        GlassButton(
                          label: 'Generate',
                          icon: Icons.auto_awesome_rounded,
                          primary: true,
                          dense: true,
                          onTap: onGenerate,
                        )
                          .animate(
                            onPlay: (c) => c.repeat(reverse: true),
                          )
                          .shimmer(
                            duration: 2200.ms,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 148,
                  child: items.isEmpty
                      ? const _EmptyBucket()
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final p = items[i];
                            final isAnchor = p.id == anchor;
                            return _BucketTile(
                              poi: p,
                              isAnchor: isAnchor,
                              onTap: () => onOpenPoi(p),
                              onAnchor: () => store.setAnchor(trip.id, p.id),
                              onRemove: () =>
                                  store.removeFromBucket(trip.id, p.id),
                            )
                                .animate()
                                .fadeIn(delay: (i * 40).ms, duration: 240.ms)
                                .slideX(begin: 0.1);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyBucket extends StatelessWidget {
  const _EmptyBucket();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Center(
        child: Text(
          'Tap places on the map to add them.\nMark your stay as the anchor.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _BucketTile extends StatelessWidget {
  const _BucketTile({
    required this.poi,
    required this.isAnchor,
    required this.onTap,
    required this.onAnchor,
    required this.onRemove,
  });

  final Poi poi;
  final bool isAnchor;
  final VoidCallback onTap;
  final VoidCallback onAnchor;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: GlassContainer(
        radius: 20,
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        gradient: isAnchor
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accent.withValues(alpha: 0.35),
                  AppColors.catDining.withValues(alpha: 0.20),
                ],
              )
            : null,
        borderOpacity: isAnchor ? 0.6 : 0.28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: poi.category.color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: poi.category.color.withValues(alpha: 0.6),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(poi.category.icon,
                      size: 15, color: poi.category.color),
                ),
                const Spacer(),
                if (isAnchor)
                  const Icon(Icons.push_pin_rounded,
                      size: 16, color: AppColors.accent),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(poi.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 12, color: AppColors.accent),
                    const SizedBox(width: 2),
                    Text(poi.rating.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const Spacer(),
                    if (poi.category == PoiCategory.accommodation)
                      _MicroAction(
                        icon: isAnchor ? Icons.check_rounded : Icons.push_pin_outlined,
                        onTap: onAnchor,
                      ),
                    const SizedBox(width: 6),
                    _MicroAction(
                        icon: Icons.close_rounded, onTap: onRemove),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MicroAction extends StatelessWidget {
  const _MicroAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 13, color: AppColors.textPrimary),
      ),
    );
  }
}

class _PoiDetailCard extends ConsumerWidget {
  const _PoiDetailCard({
    required this.poi,
    required this.tripId,
    required this.onClose,
  });

  final Poi poi;
  final String tripId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider(tripId));
    final store = ref.read(tripStoreProvider);
    final inBucket = trip.bucketList.contains(poi.id);
    final isAnchor = trip.anchorPoiId == poi.id;

    return GlassContainer(
      key: ValueKey('poi-${poi.id}'),
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: poi.category.color.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: poi.category.color.withValues(alpha: 0.55),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(poi.category.icon,
                    size: 18, color: poi.category.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(poi.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(poi.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              _MicroAction(icon: Icons.close_rounded, onTap: onClose),
            ],
          ),
          const SizedBox(height: 10),
          Text(poi.blurb,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: inBucket ? 'In bucket list' : 'Add to bucket',
                  icon: inBucket ? Icons.check_rounded : Icons.add_rounded,
                  primary: !inBucket,
                  expanded: true,
                  onTap: () => store.toggleBucket(trip.id, poi.id),
                ),
              ),
              if (poi.category == PoiCategory.accommodation) ...[
                const SizedBox(width: 8),
                GlassButton(
                  label: isAnchor ? 'Anchor' : 'Set anchor',
                  icon: Icons.push_pin_rounded,
                  onTap: () => store.setAnchor(trip.id, poi.id),
                ),
              ],
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.1);
  }
}

// ---------------------------------------------------------------------------
// Fallback map (shown when Mapbox token is missing) — a stylised grid-and-
// river backdrop with pins positioned by lat/lng so the app still runs.
// ---------------------------------------------------------------------------

class _FallbackMapBackdrop extends StatelessWidget {
  const _FallbackMapBackdrop({
    required this.pois,
    required this.selectedId,
    required this.bucketList,
    required this.onTapPin,
  });

  final List<Poi> pois;
  final String? selectedId;
  final List<String> bucketList;
  final ValueChanged<Poi> onTapPin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        const pad = 80.0;
        final lats = MockPois.all.map((p) => p.lat).toList();
        final lngs = MockPois.all.map((p) => p.lng).toList();
        final minLat = lats.reduce((a, b) => a < b ? a : b);
        final maxLat = lats.reduce((a, b) => a > b ? a : b);
        final minLng = lngs.reduce((a, b) => a < b ? a : b);
        final maxLng = lngs.reduce((a, b) => a > b ? a : b);

        Offset project(double lat, double lng) {
          final x = (lng - minLng) / (maxLng - minLng) *
                  (size.width - pad * 2) +
              pad;
          final y = (1 - (lat - minLat) / (maxLat - minLat)) *
                  (size.height - pad * 2 - 220) +
              pad + 60;
          return Offset(x, y);
        }

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter()),
            ),
            for (final p in pois)
              Positioned(
                left: project(p.lat, p.lng).dx - 22,
                top: project(p.lat, p.lng).dy - 22,
                child: _MapPin(
                  poi: p,
                  selected: p.id == selectedId,
                  inBucket: bucketList.contains(p.id),
                  onTap: () => onTapPin(p),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [Color(0xFF23113D), Color(0xFF0B0B1E)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final river = Paint()
      ..color = const Color(0xFF4FD1C5).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(-20, size.height * 0.75)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.6,
        size.width * 0.6,
        size.height * 0.85,
        size.width + 20,
        size.height * 0.7,
      );
    canvas.drawPath(path, river);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
