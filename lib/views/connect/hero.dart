// TODO: swap to shared hgfast_design tokens once
// `lib/hgfast/theme/hgfast_design.dart` lands. The constants and helpers
// below intentionally mirror the same color values (near-black background,
// violet -> pink brand gradient) so that swap is a mechanical find/replace
// rather than a redesign.
//
// This file is purely visual: it renders the ProtonVPN-style hero (world-map
// motif + power button + live traffic pills) for the Connect screen. It does
// not own any state — every value it shows and every action it triggers is
// read from the app's existing real providers (see connect.dart), the same
// ones already driving `lib/views/dashboard/widgets/start_button.dart` and
// `lib/views/dashboard/widgets/traffic_usage.dart`.

import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Design tokens
// ---------------------------------------------------------------------------

const hgHeroBackground = Color(0xFF0B0B0F);
const hgHeroSurface = Color(0xFF16161D);
const hgHeroBorder = Color(0x14FFFFFF);
const hgGradientStart = Color(0xFF8B5CF6);
const hgGradientEnd = Color(0xFFEC4899);
const hgTextPrimary = Color(0xFFF5F5F7);
const hgTextSecondary = Color(0xFFA1A1AD);
const hgCardRadius = 18.0;
const hgPillRadius = 999.0;

const hgBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [hgGradientStart, hgGradientEnd],
);

/// A fresh, self-consistent dark [ThemeData] for the Connect screen so it
/// keeps its ProtonVPN-style look even when the user's app-wide theme is set
/// to light. Built the same way `application.dart` builds the app's own
/// `darkTheme:` (useMaterial3 + a colorScheme, no custom textTheme) so every
/// derived text/icon color keeps correct contrast automatically. This only
/// changes how the Connect screen paints itself — it never touches
/// `themeSettingProvider` or any other app setting.
ThemeData buildConnectHeroTheme(BuildContext context) {
  final base = Theme.of(context);
  return ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: base.pageTransitionsTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: hgGradientStart,
      brightness: Brightness.dark,
    ),
  );
}

// ---------------------------------------------------------------------------
// Hero: world-map motif + power button + live traffic
// ---------------------------------------------------------------------------

class ConnectHero extends ConsumerWidget {
  const ConnectHero({super.key});

  static const _mapAreaHeight = 232.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isStartProvider);
    return Container(
      width: double.infinity,
      color: hgHeroBackground,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        children: [
          SizedBox(
            height: _mapAreaHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _NetworkMapPainter(isActive: isConnected),
                    ),
                  ),
                ),
                const _PowerButton(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ConnectStatusLabel(isConnected: isConnected),
          if (isConnected) ...[
            const SizedBox(height: 14),
            const _TrafficStatsBar(),
          ],
        ],
      ),
    );
  }
}

/// Abstract, low-opacity "global network" motif: a deterministic scatter of
/// dots (stable seed, so it never flickers between rebuilds) plus a few
/// concentric orbit rings behind the power button.
class _NetworkMapPainter extends CustomPainter {
  final bool isActive;

  const _NetworkMapPainter({required this.isActive});

  static const _dotSpacing = 16.0;
  static const _dotRadius = 1.1;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final radius = maxRadius * (0.55 + i * 0.16);
      final t = i / 3;
      ringPaint.color = Color.lerp(
        hgGradientStart,
        hgGradientEnd,
        t,
      )!.withValues(alpha: isActive ? 0.14 : 0.07);
      canvas.drawCircle(center, radius, ringPaint);
    }

    final random = math.Random(7);
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final cols = (size.width / _dotSpacing).ceil() + 1;
    final rows = (size.height / _dotSpacing).ceil() + 1;
    final maxDotDistance = maxRadius * 1.35;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final jitterX = (random.nextDouble() - 0.5) * _dotSpacing * 0.5;
        final jitterY = (random.nextDouble() - 0.5) * _dotSpacing * 0.5;
        // Skip most grid slots up front so both the RNG draws and the
        // organic scatter look stay stable regardless of loop order.
        final keep = random.nextDouble() <= 0.55;
        if (!keep) continue;
        final point = Offset(
          col * _dotSpacing + jitterX,
          row * _dotSpacing + jitterY,
        );
        final distance = (point - center).distance;
        final falloff = (1 - (distance / maxDotDistance)).clamp(0.0, 1.0);
        if (falloff <= 0) continue;
        final baseAlpha = isActive ? 0.16 : 0.09;
        dotPaint.color = Color.lerp(
          hgGradientStart,
          hgGradientEnd,
          (point.dx / size.width).clamp(0.0, 1.0),
        )!.withValues(alpha: baseAlpha * falloff);
        canvas.drawCircle(point, _dotRadius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkMapPainter oldDelegate) {
    return oldDelegate.isActive != isActive;
  }
}

class _PowerButton extends ConsumerStatefulWidget {
  const _PowerButton();

  @override
  ConsumerState<_PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends ConsumerState<_PowerButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    // Same guard StartButton uses before wiring the real toggle action —
    // this file never changes what tapping the button does, only how it
    // looks.
    final hasProfile = ref.read(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    if (!hasProfile) return;
    ref.read(commonActionProvider.notifier).toggleRunning();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(isStartProvider);
    const size = 160.0;
    return GestureDetector(
      onTap: _handleTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isConnected ? hgBrandGradient : null,
            color: isConnected ? null : hgHeroSurface,
            border: Border.all(
              color: isConnected
                  ? Colors.white.withValues(alpha: 0.25)
                  : hgGradientStart.withValues(alpha: 0.55),
              width: isConnected ? 1.5 : 2,
            ),
            boxShadow: isConnected
                ? [
                    BoxShadow(
                      color: hgGradientEnd.withValues(alpha: 0.38),
                      blurRadius: 44,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: hgGradientStart.withValues(alpha: 0.28),
                      blurRadius: 20,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.power_settings_new_rounded,
            size: 56,
            color: isConnected ? Colors.white : hgTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _ConnectStatusLabel extends StatelessWidget {
  final bool isConnected;

  const _ConnectStatusLabel({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final label = isConnected
        ? appLocalizations.connected
        : appLocalizations.disconnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected
            ? hgGradientStart.withValues(alpha: 0.16)
            : hgHeroSurface,
        borderRadius: BorderRadius.circular(hgPillRadius),
        border: Border.all(
          color: isConnected
              ? hgGradientStart.withValues(alpha: 0.4)
              : hgHeroBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isConnected ? hgBrandGradient : null,
              color: isConnected ? null : hgTextSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: hgTextPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficStatsBar extends ConsumerWidget {
  const _TrafficStatsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traffics = ref.watch(trafficsProvider).list;
    final last = traffics.isEmpty ? const Traffic() : traffics.last;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TrafficPill(
          icon: Icons.arrow_upward_rounded,
          text: '${last.up.traffic.show}/s',
          color: hgGradientStart,
        ),
        const SizedBox(width: 10),
        _TrafficPill(
          icon: Icons.arrow_downward_rounded,
          text: '${last.down.traffic.show}/s',
          color: hgGradientEnd,
        ),
      ],
    );
  }
}

class _TrafficPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _TrafficPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: hgHeroSurface,
        borderRadius: BorderRadius.circular(hgPillRadius),
        border: Border.all(color: hgHeroBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: hgTextPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
