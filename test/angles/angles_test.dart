// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

const degree = math.pi / 180;

/// Różnica kątów w sekundach łuku, z uwzględnieniem przejścia 360°.
double arcsec(double a, double b) {
  var d = (a - b) % 360;
  if (d > 180) d -= 360;
  return d * 3600;
}

/// Kierunek punktu ekliptyki o długości [lon] (stopnie) w układzie
/// równika daty przy nachyleniu [eps] (stopnie).
Vector3 eclipticPoint(double lon, double eps) => Vector3(
  math.cos(lon * degree),
  math.sin(lon * degree),
  0,
).rotateX(-eps * degree);

void main() {
  test('horoskop wzorcowy: ASC i MC z czasu gwiazdowego z Horizons', () {
    // Albert Einstein, 14.03.1879 10:50 UT, Ulm, 48°24′ N, 10°00′ E.
    // Lokalny pozorny czas gwiazdowy z NASA/JPL Horizons (zapytanie
    // 2026-11-03: QUANTITIES = 7, CENTER = coord@399, SITE_COORD =
    // 10.0,48.4,0, TIME_TYPE = UT): 22h56m44,1741s. ASC i MC z klasycznych
    // wzorów trygonometrii sferycznej (np. Meeus, Astronomical Algorithms,
    // rozdz. 13), niezależnych od geometrii wektorowej w anglesFromArmc:
    //   MC:  tg λ = tg ARMC / cos ε,
    //   ASC: λ = atan2(−cos ARMC, sin ε·tg φ + cos ε·sin ARMC) + 180°.
    final jdUt = julianDay(1879, 3, 14, hour: 10, minute: 50);
    const armc = (22 + 56 / 60 + 44.1741 / 3600) * 15;
    const phi = 48.4;
    final eps = trueObliquity(centuriesSinceJ2000(julianDayTT(jdUt))) / degree;
    final r = armc * degree, e = eps * degree, f = phi * degree;
    final mc = math.atan2(math.sin(r), math.cos(r) * math.cos(e)) / degree;
    final asc =
        math.atan2(
              -math.cos(r),
              math.sin(e) * math.tan(f) + math.cos(e) * math.sin(r),
            ) /
            degree +
        180;
    final a = angles(jdUt, phi, 10);
    // Horizons liczy czas gwiazdowy wzorami IAU 1982, my IAU 2006 –
    // różnica rzędu milisekund czasu.
    expect(arcsec(a.ascendant, asc).abs(), lessThan(0.1));
    expect(arcsec(a.midheaven, mc).abs(), lessThan(0.1));
  });

  test('ASC na horyzoncie po wschodniej stronie, MC na południku', () {
    const eps = 23.44;
    final random = math.Random(1879);
    // Południowa półkula, równik, Polska, okolice koła podbiegunowego
    // i za nim – tam część ekliptyki nie wschodzi ani nie zachodzi.
    const latitudes = [-33.9, -0.2, 49.8, 64.1, 66.4, 70.0, 78.0, -75.0];
    for (final lat in latitudes) {
      for (var i = 0; i < 100; i++) {
        final armc = random.nextDouble() * 360;
        final a = anglesFromArmc(armc, lat, eps);
        final ra = armc * degree, f = lat * degree;
        final zenith = Vector3(
          math.cos(f) * math.cos(ra),
          math.cos(f) * math.sin(ra),
          math.sin(f),
        );
        final east = Vector3(-math.sin(ra), math.cos(ra), 0);
        final asc = eclipticPoint(a.ascendant, eps);
        expect(asc.dot(zenith).abs(), lessThan(1e-12));
        expect(asc.dot(east), greaterThan(0), reason: 'φ $lat, ARMC $armc');
        final mc = eclipticPoint(a.midheaven, eps);
        expect(mc.dot(east).abs(), lessThan(1e-12));
        // MC po stronie górnego południka (bliżej zenitu niż IC).
        expect(mc.dot(zenith - Vector3(0, 0, zenith.z)), greaterThan(0));
      }
    }
  });
}
