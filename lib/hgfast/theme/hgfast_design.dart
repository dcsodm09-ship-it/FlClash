// HGFAST shared design tokens + reusable widgets.
//
// Single source of truth for the HGFAST brand visual language (dark-first,
// violet -> pink gradient, pill buttons, rounded surfaces). Currently
// consumed by the auth screens (`lib/pages/auth/*`); other screens built in
// parallel are welcome to import this file instead of hardcoding colors.
//
// Kept dependency-light on purpose: pure Flutter, no new pub packages.

import 'package:flutter/material.dart';

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
class HgfastAuthScope extends StatelessWidget {
  final Widget child;

  const HgfastAuthScope({super.key, required this.child});

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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: _buildTheme(Theme.of(context)), child: child);
  }
}

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
