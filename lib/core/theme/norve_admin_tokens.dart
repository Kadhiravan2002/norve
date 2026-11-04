import 'package:flutter/material.dart';

import 'norve_theme.dart';

/// Centralized design tokens for the NORVÉ Admin Web application.
///
/// Combines luxury editorial typography with high-usability modern SaaS
/// administrative controls.
abstract final class AdminColors {
  // Brand identity palette
  static const charcoal = NorveColors.charcoal; // #24211E
  static const ivory = NorveColors.ivory; // #F5F1EA
  static const white = NorveColors.white; // #FFFFFF
  static const neutralGrey = Color(0xFFB9B1A5); // Muted neutral grey
  static const muted = NorveColors.muted; // #77716A
  static const line = NorveColors.line; // #E8E2D9
  static const lineSubtle = Color(0xFFF0EBE1);
  static const surfaceSubtle = Color(0xFFFAF7F2);

  // Status tokens — restrained and meaningful
  static const success = Color(0xFF1B4332);
  static const successBg = Color(0xFFEAF5EE);
  static const successBorder = Color(0xFFC3E6CB);

  static const warning = Color(0xFF8A580C);
  static const warningBg = Color(0xFFFEF6E8);
  static const warningBorder = Color(0xFFF7DEB0);

  static const error = Color(0xFF8F1D1D);
  static const errorBg = Color(0xFFFDF1F1);
  static const errorBorder = Color(0xFFF8D0D0);

  static const info = NorveColors.charcoal;
  static const infoBg = NorveColors.ivory;
  static const infoBorder = NorveColors.line;

  static const draft = Color(0xFF77716A);
  static const draftBg = Color(0xFFF0ECE5);
  static const draftBorder = Color(0xFFDDD6CB);
}

/// Spacing scale for admin layout and components.
abstract final class AdminSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

/// Corner radius scale for admin components.
///
/// Prefers architectural, restrained radii (0–6px) over excessive pills.
abstract final class AdminRadii {
  static const double none = 0;
  static const double xs = 2;
  static const double sm = 4;
  static const double md = 6;
  static const double pill = 999;

  static const sharp = BorderRadius.zero;
  static const radiusXs = BorderRadius.all(Radius.circular(xs));
  static const radiusSm = BorderRadius.all(Radius.circular(sm));
  static const radiusMd = BorderRadius.all(Radius.circular(md));
  static const radiusPill = BorderRadius.all(Radius.circular(pill));
}

/// Typography scale combining luxury editorial serif headings with
/// clear, highly readable sans-serif controls and data displays.
abstract final class AdminTypography {
  // Editorial Display / Headings (PlayfairDisplay)
  static const brandTitle = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 3.6,
    color: AdminColors.charcoal,
  );

  static const pageTitle = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 26,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
    color: AdminColors.charcoal,
    height: 1.25,
  );

  static const sectionTitle = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 20,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: AdminColors.charcoal,
    height: 1.3,
  );

  static const modalTitle = TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 20,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: AdminColors.charcoal,
  );

  // SaaS UI Typography (Inter)
  static const brandBadge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
    color: AdminColors.muted,
  );

  static const navGroup = TextStyle(
    fontFamily: 'Inter',
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    color: AdminColors.neutralGrey,
  );

  static const navItem = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: AdminColors.charcoal,
  );

  static const pageSubtitle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AdminColors.muted,
    height: 1.45,
  );

  static const cardTitle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AdminColors.charcoal,
  );

  static const tableHeader = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: AdminColors.muted,
  );

  static const body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AdminColors.charcoal,
    height: 1.5,
  );

  static const bodyMedium = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AdminColors.charcoal,
    height: 1.5,
  );

  static const bodyBold = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AdminColors.charcoal,
  );

  static const label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AdminColors.charcoal,
  );

  static const caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AdminColors.muted,
  );

  static const button = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  static const badge = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );
}

/// Subtle borders and shadows adhering to restrained luxury aesthetics.
abstract final class AdminBorders {
  static const sideSubtle = BorderSide(color: AdminColors.line, width: 1);
  static const sideActive = BorderSide(color: AdminColors.charcoal, width: 1.5);
  static const sideError = BorderSide(color: AdminColors.error, width: 1);

  static const subtle = Border.fromBorderSide(sideSubtle);
  static const active = Border.fromBorderSide(sideActive);
  static const error = Border.fromBorderSide(sideError);
}

/// Centralized motion tokens, easing curves, and accessibility helpers for NORVÉ Admin.
///
/// Embodies a restrained, luxury editorial motion language with purposeful,
/// lightweight transitions and strict support for reduced-motion accessibility.
abstract final class AdminMotion {
  // Durations adhering to design specifications
  static const micro = Duration(milliseconds: 120);     // Toggle switches, checkmarks, icon transforms
  static const hover = Duration(milliseconds: 160);     // Button/card hover background & borders
  static const component = Duration(milliseconds: 200); // Tab switches, rotation chevrons, fades
  static const modal = Duration(milliseconds: 220);     // Dialog & sheet fade-scale entrance
  static const expand = Duration(milliseconds: 240);    // Accordion expansion & height interpolation

  // Easing curves
  static const curveFast = Curves.easeOutCubic;         // Crisp deceleration for hover/press
  static const curveStandard = Curves.easeInOutCubic;   // Balanced interpolation for height/size
  static const curveDecelerate = Curves.easeOutQuart;   // Smooth entrance for dialogs/panels

  /// Resolves the effective duration respecting reduced-motion accessibility preferences.
  static Duration duration(BuildContext context, Duration duration) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return Duration.zero;
    }
    return duration;
  }

  /// Whether the user has requested reduced motion.
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }
}

