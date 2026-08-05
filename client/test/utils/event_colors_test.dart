import 'package:calendar_client/utils/event_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('colorForEvent', () {
    test('is deterministic for the same id', () {
      expect(colorForEvent('abc-123'), colorForEvent('abc-123'));
    });

    test('different ids can map to different colors', () {
      // Not a strict requirement for every pair (hash collisions are fine),
      // but the palette should not collapse to a single color for a small
      // varied sample.
      final colors = {for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) colorForEvent(id)};
      expect(colors.length, greaterThan(1));
    });
  });
}
