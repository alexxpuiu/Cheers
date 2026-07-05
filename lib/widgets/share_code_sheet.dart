import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/trip.dart';
import '../theme/app_colors.dart';
import 'glass.dart';

/// Modal bottom sheet that shows a trip's [Trip.joinCode] and lets the user
/// copy it. Also useful as a "friends can join with this code" reveal after
/// creating a group trip.
Future<void> showShareCodeSheet(BuildContext context, Trip trip) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _ShareCodeSheet(trip: trip),
  );
}

class _ShareCodeSheet extends StatelessWidget {
  const _ShareCodeSheet({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final code = trip.joinCode ?? '—';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: GlassContainer(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          opacity: 0.18,
          borderOpacity: 0.35,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.groups_2_rounded,
                        color: AppColors.onAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('${trip.city} · ${trip.days} days',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Share this code with friends so they can join.',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 14),
              _CodeDisplay(code: code)
                  .animate()
                  .fadeIn(duration: 240.ms)
                  .scaleXY(begin: 0.95, curve: Curves.easeOutCubic),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'Copy code',
                      icon: Icons.content_copy_rounded,
                      expanded: true,
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied $code'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassButton(
                      label: 'Done',
                      icon: Icons.check_rounded,
                      primary: true,
                      expanded: true,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeDisplay extends StatelessWidget {
  const _CodeDisplay({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    // Space out characters for legibility (e.g. `H 7 K 2 Q 9`).
    final spaced = code.split('').join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.28),
            AppColors.catDining.withValues(alpha: 0.24),
          ],
        ),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        spaced,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: 2,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
