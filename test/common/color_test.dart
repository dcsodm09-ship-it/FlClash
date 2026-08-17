import 'package:fl_clash/common/color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opacity extensions use their named alpha values', () {
    const color = Colors.blue;
    const tolerance = 0.0001;

    expect(color.opacity80.a, closeTo(0.8, tolerance));
    expect(color.opacity50.a, closeTo(0.5, tolerance));
    expect(color.opacity10.a, closeTo(0.1, tolerance));
    expect(color.opacity3.a, closeTo(0.03, tolerance));
    expect(color.opacity0.a, 0);
  });

  test(
    'toPureBlack darkens every surface container tier and lightens onSurface',
    () {
      const scheme = ColorScheme.dark();
      final pureBlack = scheme.toPureBlack(true);

      expect(pureBlack.surface, Colors.black);
      expect(pureBlack.surfaceContainerLowest, Colors.black);
      expect(
        pureBlack.surfaceContainerLow,
        scheme.surfaceContainerLow.darken(5),
      );
      expect(pureBlack.surfaceContainer, scheme.surfaceContainer.darken(5));
      expect(
        pureBlack.surfaceContainerHigh,
        scheme.surfaceContainerHigh.darken(5),
      );
      expect(
        pureBlack.surfaceContainerHighest,
        scheme.surfaceContainerHighest.darken(5),
      );
      expect(pureBlack.onSurface, scheme.onSurface.lighten(5));

      expect(scheme.toPureBlack(false), scheme);
    },
  );
}
