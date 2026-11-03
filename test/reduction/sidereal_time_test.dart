// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

void main() {
  // J. Meeus, Astronomical Algorithms, 2nd ed., przykłady 12.a i 12.b
  // (wzory IAU 1982; IAU 2006 różni się o milisekundy).
  double seconds(double radians) => radians / (2 * math.pi) * 86400;
  double hms(int h, int m, double s) => h * 3600 + m * 60 + s;

  test('10.04.1987 0h UT: średni 13h10m46,3668s', () {
    final jd = julianDay(1987, 4, 10);
    final gmst = greenwichMeanSiderealTime(jd, julianDayTT(jd));
    expect(seconds(gmst), closeTo(hms(13, 10, 46.3668), 0.005));
  });

  test('10.04.1987 0h UT: prawdziwy 13h10m46,1351s', () {
    final jd = julianDay(1987, 4, 10);
    expect(
      seconds(greenwichApparentSiderealTime(jd)),
      closeTo(hms(13, 10, 46.1351), 0.005),
    );
  });

  test('10.04.1987 19h21m UT: średni 8h34m57,0896s', () {
    final jd = julianDay(1987, 4, 10, hour: 19, minute: 21);
    final gmst = greenwichMeanSiderealTime(jd, julianDayTT(jd));
    expect(seconds(gmst), closeTo(hms(8, 34, 57.0896), 0.005));
  });
}
