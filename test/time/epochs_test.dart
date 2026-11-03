// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

void main() {
  test('J2000 to dzień juliański 2451545,0', () {
    expect(j2000, 2451545.0);
  });

  test('stulecie juliańskie ma 36525 dni', () {
    expect(daysPerJulianCentury, 36525.0);
  });
}
