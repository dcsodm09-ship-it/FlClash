// HGFAST shared design tokens + reusable widgets.
//
// Single source of truth for the HGFAST brand visual language (dark-first,
// violet -> pink gradient, pill buttons, rounded surfaces). Currently
// consumed by the auth screens (`lib/pages/auth/*`); other screens built in
// parallel are welcome to import this file instead of hardcoding colors.
//
// Kept dependency-light on purpose: pure Flutter, no new pub packages.

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

/// Keeps the app-wide desktop scrollbar's real behavior (CommonScrollBar,
/// already `interactive: true`) but forces its thumb persistently visible
/// on HGFAST screens instead of only flashing in during an active scroll —
/// on a screen this short, a thumb that's only visible mid-drag reads as a
/// rendering glitch rather than a control the user can reach for. Same
/// widget, same drag behavior, just always shown.
class _HgfastScrollBehavior extends BaseScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (axisDirectionToAxis(details.direction)) {
      case Axis.horizontal:
        return child;
      case Axis.vertical:
        switch (getPlatform(context)) {
          case TargetPlatform.linux:
          case TargetPlatform.macOS:
          case TargetPlatform.windows:
            return CommonScrollBar(
              controller: details.controller,
              thumbVisibility: true,
              child: child,
            );
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.iOS:
            return child;
        }
    }
  }
}

/// Raw color tokens. Prefer [HgfastAuthScope] + `Theme.of(context).colorScheme`
/// in widget code over reaching for these directly — the scope maps them
/// onto a real [ColorScheme] so light/dark switching stays automatic. These
/// are exposed mainly for the handful of brand accents (gradients, the
/// brand mark) that don't have a natural ColorScheme slot.
class HgfastColors {
  const HgfastColors._();

  // Brand gradient endpoints (identical in both themes).
  static const Color violet = Color(0xFF8B5CF6);
  static const Color pink = Color(0xFFEC4899);

  // Dark palette (default / primary theme).
  static const Color backgroundDark = Color(0xFF0B0B0F);
  static const Color surfaceDark = Color(0xFF17171F);
  static const Color textPrimaryDark = Color(0xFFF5F5F7);
  static const Color textSecondaryDark = Color(0xFF9A9AA5);
  static const Color borderDark = Color(0x1FFFFFFF);
  static const Color errorDark = Color(0xFFF87171);

  // Light palette: a simpler, paler variant of the same tokens.
  static const Color backgroundLight = Color(0xFFF2F2F6);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF17171F);
  static const Color textSecondaryLight = Color(0xFF6B6B76);
  static const Color borderLight = Color(0x1F17171F);
  static const Color errorLight = Color(0xFFDC2626);
}

/// Shared corner-radius scale.
class HgfastRadii {
  const HgfastRadii._();

  static const double field = 16;
  static const double card = 16;
  static const double brandMark = 14;
  static const double pill = 999;
}

/// Shared spacing scale (multiples of 4, kept small — screens still lay
/// their own SizedBox rhythm out explicitly for readability).
class HgfastSpacing {
  const HgfastSpacing._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// The brand gradient: violet -> pink, diagonal.
class HgfastGradients {
  const HgfastGradients._();

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [HgfastColors.violet, HgfastColors.pink],
  );
}

/// Wraps a subtree with the HGFAST brand [ColorScheme] + component themes,
/// derived from the ambient [ThemeData]'s brightness so app-wide light/dark
/// switching keeps working. Dark is the fully-designed primary variant;
/// light is a paler variant of the same tokens.
///
/// Usage: wrap a screen's root (typically the `CommonScaffold`) so its
/// AppBar/background/inputs all pick up brand colors without any per-widget
/// hardcoding:
/// ```dart
/// return HgfastAuthScope(
///   child: CommonScaffold(...),
/// );
/// ```
///
/// This scope is reused far more broadly than its name suggests — not just
/// by the 3 real auth screens (login/register/forgot-password) but also by
/// discover/support/plans/invite, none of which are auth-only. That's why
/// [includeWindowChrome] (the macOS drag-strip / traffic-light-clearance
/// fix — see [_HgfastAuthWindowChrome]) defaults to `false` and must be
/// opted into explicitly: those 4 other screens all render inside `HomePage`
/// → `AppSidebarContainer`, which already reserves its own macOS
/// traffic-light clearance via the sidebar's `SizedBox(height: 22)`
/// (`lib/manager/app_manager.dart`). Turning the strip on there too would
/// insert a second, differently-colored horizontal band in the content
/// column only (not shifting the sidebar next to it) — reproducing the
/// exact "横条" artifact this was built to fix, just relocated. Confirmed
/// by an earlier review with a live widget-test probe: it really did
/// render on `DiscoverView`/`PlansView`. Only login/register/forgot-password
/// pass `includeWindowChrome: true`.
class HgfastAuthScope extends StatelessWidget {
  final Widget child;

  /// See the class doc above — leave this `false` everywhere except the 3
  /// real auth screens, which have no sidebar and so get no macOS
  /// traffic-light clearance from anywhere else.
  final bool includeWindowChrome;

  const HgfastAuthScope({
    super.key,
    required this.child,
    this.includeWindowChrome = false,
  });

  static ColorScheme _darkScheme() {
    return const ColorScheme.dark(
      primary: HgfastColors.violet,
      onPrimary: Colors.white,
      secondary: HgfastColors.pink,
      onSecondary: Colors.white,
      surface: HgfastColors.surfaceDark,
      onSurface: HgfastColors.textPrimaryDark,
      error: HgfastColors.errorDark,
      onError: Colors.white,
    ).copyWith(
      onSurfaceVariant: HgfastColors.textSecondaryDark,
      outline: HgfastColors.borderDark,
    );
  }

  static ColorScheme _lightScheme() {
    return const ColorScheme.light(
      primary: HgfastColors.violet,
      onPrimary: Colors.white,
      secondary: HgfastColors.pink,
      onSecondary: Colors.white,
      surface: HgfastColors.surfaceLight,
      onSurface: HgfastColors.textPrimaryLight,
      error: HgfastColors.errorLight,
      onError: Colors.white,
    ).copyWith(
      onSurfaceVariant: HgfastColors.textSecondaryLight,
      outline: HgfastColors.borderLight,
    );
  }

  static Color _backgroundFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? HgfastColors.backgroundDark
        : HgfastColors.backgroundLight;
  }

  static ThemeData _buildTheme(ThemeData base) {
    final isDark = base.brightness == Brightness.dark;
    final colorScheme = isDark ? _darkScheme() : _lightScheme();
    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _backgroundFor(base.brightness),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: colorScheme.surface,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HgfastRadii.field),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HgfastRadii.field),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HgfastRadii.field),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HgfastRadii.field),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
      // The desktop scrollbar on this screen (macOS/Windows/Linux) comes
      // from the app-wide BaseScrollBehavior (application.dart), which
      // wraps every vertical Scrollable in CommonScrollBar
      // (lib/common/scroll.dart) — already `interactive: true`, so
      // drag-to-scroll already worked; it just rendered as the theme's
      // default plain grey, which on this screen's dark background reads
      // as a stray static line rather than an obviously grabbable
      // control. CommonScrollBar sets thickness/radius/interactive/
      // thumbVisibility explicitly (those don't come from ThemeData), but
      // leaves thumbColor unset, so branding it here is what actually
      // takes effect — a plain color swap, not new interaction logic.
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return colorScheme.primary.withValues(alpha: 0.9);
          }
          if (states.contains(WidgetState.hovered)) {
            return colorScheme.primary.withValues(alpha: 0.7);
          }
          return colorScheme.primary.withValues(alpha: 0.45);
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _buildTheme(Theme.of(context)),
      child: ScrollConfiguration(
        behavior: _HgfastScrollBehavior(),
        child: includeWindowChrome
            ? _HgfastAuthWindowChrome(child: child)
            : child,
      ),
    );
  }
}

/// Reserves a native-title-bar-equivalent drag / traffic-light-clearance
/// strip above the auth screens' AppBar on a macOS desktop-width window —
/// the concrete "横条" (horizontal bar) this was built to fix.
///
/// macOS windows here run with `TitleBarStyle.hidden` (see
/// `common/window.dart`), so there is no native title bar left to grab to
/// move the window, and nothing reserving space for the traffic-light
/// buttons either. Every *other* screen gets this for free because it's
/// wrapped in `AppSidebarContainer`, whose left rail adds
/// `if (system.isMacOS) const SizedBox(height: 22)` above its nav icons
/// specifically so the traffic lights have blank space to sit in
/// (`lib/manager/app_manager.dart`). The auth flow (login/register/
/// forgot-password) has no sidebar — `HgfastAuthScope` goes straight into
/// `CommonScaffold`'s `AppBar`, which starts flush at the window's actual
/// top-left pixel, so at this app's default window size (680x580 — already
/// wider than the 600px mobile breakpoint, i.e. `isMobileView == false`)
/// the "登录"/"注册"/"忘记密码" title and the "遇到问题？" action rendered
/// right where the traffic lights are, and none of that top strip was
/// draggable — the window could only be moved by dragging its edges.
///
/// This only needs to add its own strip when the app-level
/// `WindowHeaderContainer` (`lib/manager/window_manager.dart`) is *not*
/// already adding its own `WindowHeader` above us — i.e. the exact same
/// condition it uses to decide to render its child bare. In the other
/// branch (the window resized down to mobile width) `WindowHeader` already
/// reserves and drags that space itself (centered "HGFAST" text, clear of
/// the traffic lights because it's centered, not left-aligned) — adding a
/// second strip here would just stack two bars.
class _HgfastAuthWindowChrome extends StatelessWidget {
  final Widget child;

  const _HgfastAuthWindowChrome({required this.child});

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!system.isMacOS) {
      return child;
    }
    return Consumer(
      builder: (_, ref, _) {
        final isMobileView = ref.watch(isMobileViewProvider);
        final version = ref.watch(versionProvider);
        // Mirrors WindowHeaderContainer's own gate exactly: when this is
        // true, WindowHeaderContainer is already rendering a WindowHeader
        // above the whole app (including this screen) — stay out of its way.
        final windowHeaderContainerAlreadyHandlesThis =
            version > 10 && isMobileView;
        if (windowHeaderContainerAlreadyHandlesThis) {
          return child;
        }
        final colorScheme = Theme.of(context).colorScheme;
        return Column(
          children: [
            GestureDetector(
              key: const ValueKey('hgfastAuthWindowDragStrip'),
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: _toggleMaximize,
              child: Container(
                width: double.infinity,
                height: _macTrafficLightStripHeight,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(
                  left: _macTrafficLightClearance,
                ),
                decoration: BoxDecoration(
                  // A tinted strip with a bottom border, not a transparent
                  // one — this is the exact desktop-titlebar treatment
                  // from the original UI-kit mockup
                  // (claude.ai/code/artifact/dbe54ac4-...): background
                  // distinct from the page body, border-bottom separator,
                  // a small monospace label after where the traffic
                  // lights sit. colorScheme.surface/outline are the same
                  // tokens CommonScrollBar/inputs already use for that
                  // "one step up from the background" surface, so this
                  // stays consistent with the rest of the auth theme
                  // instead of inventing a third shade.
                  color: colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outline),
                  ),
                ),
                child: Text(
                  'HGFAST — 桌面客户端',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colorScheme.onSurfaceVariant,
                  ).toJetBrainsMono,
                ),
              ),
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// Left padding for the desktop-titlebar label, wide enough to clear
/// macOS's native traffic-light buttons (drawn by the OS, not by this
/// widget — TitleBarStyle.hidden keeps them, see common/window.dart).
/// Matches the mockup's own dot-cluster geometry (16px padding + 3×11px
/// dots + 2×7px gaps + 10px flex-gap + 6px label margin ≈ 68px), rounded
/// up for real-world macOS traffic-light spacing, which varies slightly
/// by OS version.
const double _macTrafficLightClearance = 78;

/// Height of the macOS drag strip. NOT kHeaderHeight (28) — the app
/// already has a real, separately-tuned reference for how much vertical
/// room the native traffic-light cluster actually needs on macOS:
/// AppSidebarContainer's own `if (system.isMacOS) SizedBox(height: 22)` +
/// `SizedBox(height: 10)` (lib/manager/app_manager.dart) reserves 32px
/// above its nav rail for exactly this same purpose. A user report that
/// this strip looked wrong specifically in the traffic-light/drag area
/// (not the label text) matches kHeaderHeight's 28px being 4px short of
/// that established 32px precedent — matched here instead of guessing at
/// a new number.
const double _macTrafficLightStripHeight = 32;

/// Small rounded-square gradient brand/icon mark shown above auth headlines.
class HgfastBrandMark extends StatelessWidget {
  final double size;
  final IconData icon;

  const HgfastBrandMark({
    super.key,
    this.size = 56,
    this.icon = Icons.lock_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: HgfastGradients.brand,
        borderRadius: BorderRadius.circular(HgfastRadii.brandMark),
        boxShadow: [
          BoxShadow(
            color: HgfastColors.violet.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// Full-width pill button painted with the brand gradient. Deliberately
/// built on top of a real [FilledButton] (rather than a bare GestureDetector)
/// so it keeps standard Material semantics/hit-testing/disabled-state
/// handling — sibling code and widget tests that look for a `FilledButton`
/// keep working, only the paint changes.
class HgfastGradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double height;

  const HgfastGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = onPressed == null;
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HgfastRadii.pill),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: disabled ? null : HgfastGradients.brand,
            color: disabled ? colorScheme.outline : null,
            borderRadius: BorderRadius.circular(HgfastRadii.pill),
          ),
          child: Container(
            alignment: Alignment.center,
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              child: IconTheme.merge(
                data: const IconThemeData(color: Colors.white, size: 20),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Brand-styled text input: dark/light surface fill, leading icon, large
/// rounded corners, optional trailing widget (e.g. a password eye-toggle).
/// Wraps a real [TextField] so `find.byType(TextField)` still locates it.
class HgfastTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData leadingIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final TextInputType? keyboardType;

  const HgfastTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.leadingIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
      keyboardType: keyboardType,
      style: TextStyle(color: colorScheme.onSurface, fontSize: 15),
      cursorColor: colorScheme.primary,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(
          leadingIcon,
          color: colorScheme.onSurfaceVariant,
          size: 20,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// Larger [HgfastBrandMark] + a bold "HGFAST" wordmark, for the primary
/// login entry point — the one place that carries the app's logo mark and
/// name together as a real product identity, matching how a real app's
/// login/splash screen introduces itself before asking for credentials.
/// [HgfastBrandMark] itself stays in use at its smaller default size on
/// secondary auth screens (register/forgot-password) that don't need full
/// brand treatment. See the doc comment inside build() for why this
/// deliberately does NOT use assets/images/icon.png.
class HgfastAppBrandHeader extends StatelessWidget {
  final double logoSize;

  const HgfastAppBrandHeader({super.key, this.logoSize = 64});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Deliberately NOT assets/images/icon.png: that file is the
        // upstream FlClash app icon (unrelated third-party project this
        // was forked from, last touched by an upstream commit, never
        // re-themed for HGFAST) — there is no actual HGFAST logo asset
        // anywhere in this repo yet. Using it here would put a different
        // product's brand mark front-and-center on HGFAST's own login
        // screen, directly under a "HGFAST" wordmark. HgfastBrandMark's
        // abstract gradient-square-with-icon treatment IS genuinely
        // HGFAST's own design language (already used consistently across
        // every auth screen this whole redesign), so it's reused here at
        // a larger size instead, as the real logo mark, until an actual
        // commissioned/approved HGFAST logo image exists to swap in.
        HgfastBrandMark(size: logoSize, icon: Icons.bolt_rounded),
        const SizedBox(height: HgfastSpacing.sm),
        ShaderMask(
          shaderCallback: (bounds) =>
              HgfastGradients.brand.createShader(bounds),
          child: const Text(
            'HGFAST',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small muted footer caption used at the bottom of auth screens
/// (e.g. "HGFAST v1.0.0 · 登录即表示同意...").
class HgfastAuthFooterCaption extends StatelessWidget {
  final String text;

  const HgfastAuthFooterCaption({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
    );
  }
}

/// Designated mount point for the production web-registration antibot /
/// challenge widget (e.g. Turnstile/hCaptcha).
///
/// TODO(hgfast-register): registration is currently disabled server-side
/// (`HgfastError.registerDisabled`) — there is no live registration form to
/// attach a real challenge to yet, so this slot intentionally renders
/// nothing. When a functional email/password/confirm-password register form
/// is wired up to a real backend action, mount the actual challenge widget
/// here via [child] and gate the submit button on it completing — the
/// production register endpoint fails with `ANTIBOT_MISSING` if this step is
/// skipped. Do not fabricate a working challenge / fake success state here.
class HgfastAntibotSlot extends StatelessWidget {
  final Widget? child;

  const HgfastAntibotSlot({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}
