import 'package:flutter/material.dart';

/// Shop Afrik brand color tokens.
///
/// Source: Project Plan & Technical Roadmap §8 "Visual Direction".
/// The look is a premium dark mobile interface with teal action states,
/// soft aqua highlights, coral danger states and a warm gold accent.
abstract final class AppColors {
  /// App background, high-trust surfaces.
  static const Color primaryDark = Color(0xFF101418);

  /// Cards, forms, product panels, bottom sheets.
  ///
  /// Lifted from #171D24 so cards separate from the background without
  /// relying only on their border.
  static const Color panelDark = Color(0xFF1C232B);

  /// Material 3 surface tiers, from lowest (closest to the background) to
  /// highest (menus, selected rows, raised sheets).
  static const Color surfaceLow = Color(0xFF181E25);
  static const Color surfaceHigh = Color(0xFF232B34);
  static const Color surfaceHighest = Color(0xFF2A333D);

  /// Brand anchor, headers, dark accents.
  static const Color deepTeal = Color(0xFF063F3B);

  /// Main buttons, active tabs, payment confirmation.
  static const Color primaryTeal = Color(0xFF0BA99D);

  /// Highlights, success states, gradients.
  static const Color brightAqua = Color(0xFF3ED1C2);

  /// Refund warnings, delete actions, failed payment states.
  static const Color dangerCoral = Color(0xFFF56565);

  /// Text and icons placed on [dangerCoral]. Dark rather than white, because
  /// white on coral is only 2.8:1 contrast; this is 6.1:1.
  static const Color onDanger = primaryDark;

  /// Warm brand accent: star ratings, deals, badges.
  static const Color accentGold = Color(0xFFF5B942);

  /// Completed / successful states.
  static const Color success = Color(0xFF22C55E);

  /// Pending or needs-attention states.
  static const Color warning = accentGold;

  /// Neutral informational states.
  static const Color info = Color(0xFF60A5FA);

  /// Secondary labels and helper text.
  static const Color mutedText = Color(0xFF9AA4B2);

  /// Primary on-surface text (high emphasis).
  static const Color primaryText = Color(0xFFF5F7FA);

  /// Hairline borders / dividers on dark surfaces.
  static const Color divider = Color(0xFF2A333D);

  /// Brand gradient used for hero surfaces and payment confirmation.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryTeal, brightAqua],
  );
}
