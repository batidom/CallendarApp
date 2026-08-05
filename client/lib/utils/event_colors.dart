import 'package:flutter/material.dart';

/// A small fixed palette (similar to Windows Calendar's category colors).
/// Each event gets a deterministic color derived from its id, so the same
/// event always renders the same color without needing a stored category.
const List<Color> _palette = [
  Color(0xFF0078D4), // blue
  Color(0xFFE81123), // red
  Color(0xFF107C10), // green
  Color(0xFFFFB900), // amber
  Color(0xFF881798), // purple
  Color(0xFF00B7C3), // teal
  Color(0xFFEA005E), // pink
  Color(0xFFFF8C00), // orange
];

Color colorForEvent(String eventId) {
  final index = eventId.hashCode.abs() % _palette.length;
  return _palette[index];
}
