import 'package:flutter/material.dart';

/// Shop Afrik brand color tokens.
///
/// Source: Project Plan & Technical Roadmap §8 "Visual Direction".
/// The look is a premium dark mobile interface with teal action states,
/// soft aqua highlights, and coral danger states.
abstract final class AppColors {
  /// App background, high-trust surfaces.
  static const Color primaryDark = Color(0xFF101418);

  /// Cards, forms, product panels, bottom sheets.
  static const Color panelDark = Color(0xFF171D24);

  /// Brand anchor, headers, dark accents.
  static const Color deepTeal = Color(0xFF063F3B);

  /// Main buttons, active tabs, payment confirmation.
  static const Color primaryTeal = Color(0xFF0BA99D);

  /// Highlights, success states, gradients.
  static const Color brightAqua = Color(0xFF3ED1C2);

  /// Refund warnings, delete actions, failed payment states.
  static const Color dangerCoral = Color(0xFFF56565);

  /// Secondary labels and helper text.
  static const Color mutedText = Color(0xFF9AA4B2);

  /// Primary on-surface text (high emphasis).
  static const Color primaryText = Color(0xFFF5F7FA);

  /// Hairline borders / dividers on dark surfaces.
  static const Color divider = Color(0xFF252C35);

  /// Brand gradient used for hero surfaces and payment confirmation.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryTeal, brightAqua],
  );
}
