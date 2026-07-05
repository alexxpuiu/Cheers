import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lightweight map overlay — semi-transparent, no [BackdropFilter].
/// Backdrop blur on map screens causes a full-screen frost bug on iOS/web.
class MapPanel extends StatelessWidget {
  const MapPanel({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderOpacity = 0.12,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final panel = Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: color ?? AppColors.bgSurface.withValues(alpha: 0.94),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: borderOpacity),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.glassShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return panel;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: panel,
    );
  }
}
