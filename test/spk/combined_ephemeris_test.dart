// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';

void main() {
  test('planety z jednego źródła, planetoida z drugiego – jak razem', () {
    final both = SpkEphemeris([de440s, smallBodies]);
    final combined = CombinedEphemeris([
      SpkEphemeris([de440s]),
      SpkEphemeris([smallBodies]),
    ]);
    final et = (julianDay(2026, 5, 1) - j2000) * 86400;
    for (final (t, c) in [
      (Naif.marsBarycenter, Naif.earth),
      (2002060, Naif.earth), // Chiron względem Ziemi – dwa źródła
      (2000001, Naif.sun),
    ]) {
      final a = combined.state(t, c, et), b = both.state(t, c, et);
      expect(
        (a - b).x.abs() + (a - b).y.abs() + (a - b).z.abs(),
        lessThan(1e-6),
      );
    }
    expect(combined.covers(2002060, et), isTrue);
    expect(
      combined.covers(2002060, (julianDay(1500, 1, 1) - j2000) * 86400),
      isFalse,
    );
  });
}
