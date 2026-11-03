// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';

void main() {
  final eph = SpkEphemeris([de440s]);

  LunarPhase first(MoonPhase phase, int year, int month) {
    final a = julianDayTT(julianDay(year, month, 1));
    return lunarPhases(eph, a, a + 31).firstWhere((p) => p.phase == phase);
  }

  test('nów 18.02.1977: 3h37m40s TD (Meeus, przykład 49.a, ELP-2000/82)', () {
    final p = first(MoonPhase.newMoon, 1977, 2);
    final expected = julianDay(1977, 2, 18, hour: 3, minute: 37, second: 40);
    expect((p.jdTT - expected) * 86400, closeTo(0, 1));
  });

  test('ostatnia kwadra 21.01.2044: 23h48m17s TD (Meeus, przykład 49.b)', () {
    // Meeus liczy tu swoją metodą przybliżoną (szeregi okresowe), nie
    // pełną teorią – stąd szersza tolerancja.
    final p = first(MoonPhase.lastQuarter, 2044, 1);
    final expected = julianDay(2044, 1, 21, hour: 23, minute: 48, second: 17);
    expect((p.jdTT - expected) * 86400, closeTo(0, 10));
  });

  test('2026: fazy po kolei, co ok. 7,4 doby, elongacja dokładna', () {
    final a = julianDayTT(julianDay(2026, 1, 1));
    final phases = lunarPhases(eph, a, a + 365);
    expect(phases.length, inInclusiveRange(48, 50));
    final elongation = lunarElongation(eph);
    for (var k = 0; k < phases.length; k++) {
      final p = phases[k];
      var d = (elongation(p.jdTT) - p.phase.index * 90) % 360;
      if (d > 180) d -= 360;
      expect(d.abs(), lessThan(1e-6));
      if (k > 0) {
        final prev = phases[k - 1];
        expect(p.phase.index, (prev.phase.index + 1) % 4);
        // Kwadry dzielą miesiąc synodyczny nierówno (orbita eliptyczna).
        expect(p.jdTT - prev.jdTT, inInclusiveRange(6.4, 8.4));
      }
    }
  });
}
