import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../config/mapbox_config.dart';
import '../models/poi.dart';
import '../providers/poi_providers.dart';
import '../providers/trip_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/attribution.dart';
import '../widgets/glass.dart';
import '../widgets/map_panel.dart';

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
    final catalogAsync = ref.watch(poiCatalogProvider);
    final catalog = catalogAsync.asData?.value ?? const PoiCatalog.empty();
    final pois = catalog.list
        .where((p) => filters.contains(p.category))
        .toList(growable: false);
    final bucketList =
        ref.watch(tripStoreProvider).byId(widget.tripId).bucketList;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // Opaque fill behind tiles so aurora never bleeds through gaps.
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.bgDeep,
              child: _buildMap(pois: pois, bucketList: bucketList),
            ),
          ),

          // Top chrome — single min-height column so overlays never span full screen.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SafeArea(
                  bottom: false,
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
                          child: MapPanel(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                if (_showFilters)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
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
              ],
            ),
          ),

          // Bucket-list bottom sheet
          _BucketSheet(
            tripId: widget.tripId,
            onOpenPoi: (poi) => setState(() => _selectedPoiId = poi.id),
            onGenerate: () => context.push('/trip/${widget.tripId}/itinerary'),
          ),

          // Selected POI card
          if (_selectedPoiId != null && catalog.byId(_selectedPoiId!) != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 240,
              child: _PoiDetailCard(
                poi: catalog.require(_selectedPoiId!),
                tripId: widget.tripId,
                onClose: () => setState(() => _selectedPoiId = null),
              ),
            ),

          // Foursquare attribution — required by their TOS on any screen
          // showing Foursquare data. Anchored above the bucket sheet peek.
          const Positioned(
            left: 20,
            bottom: 232,
            child: FoursquareAttribution(),
          ),

          // Catalog loading / error hint (subtle, doesn't block the map).
          if (catalogAsync.isLoading && catalog.isEmpty)
            const Positioned(
              top: 130,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
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
    if (!hasMapboxToken) {
      return _FallbackMapBackdrop(
        pois: pois,
        selectedId: _selectedPoiId,
        bucketList: bucketList,
        onTapPin: (poi) => setState(() => _selectedPoiId = poi.id),
      );
    }

    final bucket = bucketList.toSet();
    final tileUrl = mapboxTileUrl('streets-v12');

    return FlutterMap(
      options: MapOptions(
        initialCenter: const LatLng(BarcelonaCenter.lat, BarcelonaCenter.lng),
        initialZoom: 12.6,
        minZoom: 3,
        maxZoom: 22,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (_, __) => setState(() => _selectedPoiId = null),
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrl,
          maxNativeZoom: 22,
          userAgentPackageName: 'com.cheers.om',
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
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: poi.category.color.withValues(alpha: 0.55),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
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
      child: MapPanel(
        radius: 100,
        onTap: onTap,
        borderOpacity: selected ? 0.35 : 0.15,
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
    return MapPanel(
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
    final catalog =
        ref.watch(poiCatalogProvider).asData?.value ?? const PoiCatalog.empty();
    final items = trip.bucketList
        .map(catalog.byId)
        .whereType<Poi>()
        .toList();
    final anchor = trip.anchorPoiId;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: MapPanel(
            radius: 30,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
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
                      MapPanel(
                        radius: 100,
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
                            color: AppColors.textPrimary.withValues(alpha: 0.2),
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
      child: MapPanel(
        radius: 20,
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        borderOpacity: isAnchor ? 0.6 : 0.28,
        color: isAnchor
            ? Color.lerp(
                AppColors.bgSurface,
                AppColors.accent,
                0.18,
              )!
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _BucketThumb(poi: poi),
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

/// Small square thumbnail on the bucket-list tiles. Uses the first
/// Foursquare photo when available, otherwise renders the category icon in
/// its accent color (the original design).
class _BucketThumb extends StatelessWidget {
  const _BucketThumb({required this.poi});

  final Poi poi;

  @override
  Widget build(BuildContext context) {
    final photo = poi.photos.isNotEmpty ? poi.photos.first : null;
    final radius = BorderRadius.circular(10);
    if (photo != null) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Image.network(
            photo.url(size: '100x100'),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _iconFallback(),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _iconFallback(),
          ),
        ),
      );
    }
    return _iconFallback();
  }

  Widget _iconFallback() {
    return Container(
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
          color: AppColors.textPrimary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.15),
          ),
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

    return MapPanel(
      key: ValueKey('poi-${poi.id}'),
      radius: 24,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PoiHero(poi: poi, onClose: onClose),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
              _RatingChip(rating: poi.rating, count: poi.ratingCount),
            ],
          ),
          if (poi.blurb.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(poi.blurb,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
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
          ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.1);
  }
}

/// 16:9 hero at the top of the detail card. Uses the first Foursquare
/// photo when available and falls back to a category-color gradient so the
/// card looks intentional even for un-enriched POIs.
class _PoiHero extends StatelessWidget {
  const _PoiHero({required this.poi, required this.onClose});

  final Poi poi;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final photo = poi.photos.isNotEmpty ? poi.photos.first : null;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null)
              Image.network(
                photo.url(size: '600x400'),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _CategoryGradient(poi: poi),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _CategoryGradient(poi: poi);
                },
              )
            else
              _CategoryGradient(poi: poi),
            // Bottom scrim so name/chip stay readable if we ever overlay text.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black26],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _MicroAction(icon: Icons.close_rounded, onTap: onClose),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGradient extends StatelessWidget {
  const _CategoryGradient({required this.poi});

  final Poi poi;

  @override
  Widget build(BuildContext context) {
    final color = poi.category.color;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Center(
        child: Icon(poi.category.icon,
            size: 42, color: Colors.white.withValues(alpha: 0.55)),
      ),
    );
  }
}

/// `★ 4.3 · 287` pill next to the POI name. Hides the review count when we
/// have no data (Foursquare miss / un-enriched row).
class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating, required this.count});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: AppColors.accent),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          if (count > 0) ...[
            Text('  ·  ',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
            Text(
              _formatCount(count),
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
    }
    return n.toString();
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
        // Frame the fallback grid around whatever POIs are actually being
        // shown (post-filter). Fall back to a sensible Barcelona-wide bbox
        // when the catalog hasn't loaded yet.
        final source = pois.isNotEmpty ? pois : const <Poi>[];
        final lats = source.isEmpty
            ? const [41.3620, 41.4200]
            : source.map((p) => p.lat).toList();
        final lngs = source.isEmpty
            ? const [2.1300, 2.2050]
            : source.map((p) => p.lng).toList();
        final minLat = lats.reduce((a, b) => a < b ? a : b);
        final maxLat = lats.reduce((a, b) => a > b ? a : b);
        final minLng = lngs.reduce((a, b) => a < b ? a : b);
        final maxLng = lngs.reduce((a, b) => a > b ? a : b);
        // Avoid div-by-zero when the (filtered) catalog collapses to a
        // single POI or the fallback bbox is degenerate.
        final latSpan = (maxLat - minLat).abs() < 1e-6 ? 0.01 : maxLat - minLat;
        final lngSpan = (maxLng - minLng).abs() < 1e-6 ? 0.01 : maxLng - minLng;

        Offset project(double lat, double lng) {
          final x = (lng - minLng) / lngSpan *
                  (size.width - pad * 2) +
              pad;
          final y = (1 - (lat - minLat) / latSpan) *
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
        colors: [Color(0xFFFFEFE4), AppColors.bgDeep],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final grid = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.06)
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
