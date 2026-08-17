import 'package:fl_clash/hgfast/theme/hgfast_design.dart';
import 'package:flutter/material.dart';

// Small additions on top of the shared HGFAST design system
// (`lib/hgfast/theme/hgfast_design.dart`, owned by a teammate) that don't
// have an equivalent there yet. Everything else (colors, gradients, radii,
// the brand scope, the gradient button, text fields) should be imported
// directly from hgfast_design.dart instead of being redefined here.
//
// TODO: consider upstreaming HgSurfaceCard / HgPillBadge into
// hgfast_design.dart once more screens need them, so there's exactly one
// place that owns the HGFAST component kit.

/// Rounded, padded card matching the HGFAST design system's surface style.
/// Reads `Theme.of(context).colorScheme.surface`, so it relies on the
/// caller having wrapped its screen in [HgfastAuthScope] (or any ancestor
/// that maps `colorScheme.surface` onto the brand surface color) rather
/// than hardcoding a color itself.
class HgSurfaceCard extends StatelessWidget {
  const HgSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(HgfastRadii.card),
      ),
      child: child,
    );
    if (onTap == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(HgfastRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(HgfastRadii.card),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Small pill badge/chip using the brand gradient as an accent.
class HgPillBadge extends StatelessWidget {
  const HgPillBadge({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: HgfastGradients.brand,
        borderRadius: BorderRadius.circular(HgfastRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
