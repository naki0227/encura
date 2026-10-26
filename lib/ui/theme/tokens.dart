import 'package:flutter/material.dart';

/// EnCura's design tokens: a dark room where the artworks carry the colour.
///
/// The UI is three steps of the same warm black, white and grey text, and one
/// accent (gold). Everything that moves uses one curve and three durations.
class Palette {
  Palette._();

  /// Page background.
  static const Color room = Color(0xFF0E0F0E);

  /// Raised surfaces: app bars, the navigation bar, the chat input.
  static const Color wall = Color(0xFF181A18);

  /// Cards.
  static const Color frame = Color(0xFF222422);

  static const Color text = Colors.white;
  static const Color textSub = Color(0xFF999999);

  /// Hairlines and card edges (white at 12%).
  static const Color line = Color(0x1FFFFFFF);

  /// The one accent.
  static const Color gold = Color(0xFFC5A059);
}

class Motion {
  Motion._();

  /// easeOutCubic: arrives quickly, settles gently. The only curve in the app.
  static const Curve curve = Cubic(0.215, 0.61, 0.355, 1);

  /// Colour and press feedback.
  static const Duration fast = Duration(milliseconds: 240);

  /// Fades, small reveals.
  static const Duration mid = Duration(milliseconds: 360);

  /// Cards and photos arriving.
  static const Duration slow = Duration(milliseconds: 1000);

  /// True when the user asked the system to reduce motion.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
