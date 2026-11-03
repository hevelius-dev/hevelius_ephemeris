// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Horoskop wzorcowy (Albert Einstein, 14.03.1879 10:50 UT) – porównanie
// z NASA/JPL Horizons, https://ssd.jpl.nasa.gov/horizons/ (zapytanie
// 2026-11-03: efemeryda DE441, planetoidy SB441-N16; środek 500@399 –
// środek Ziemi; TLIST = 2407422.951355287, TIME_TYPE = TT – ta sama
// chwila co u nas, bez różnic w ΔT; ANG_FORMAT = DEG, EXTRA_PREC = YES).
//
// 1. Położenie astrometryczne w ICRF (wielkość 1 Horizons: czas światła,
//    bez aberracji, ugięcia, precesji i nutacji) – sprawdza odczyt
//    efemerydy i czas światła bez żadnego modelu obrotu osi Ziemi.
// 2. Położenie pozorne na ekliptyce daty (wielkość 31 Horizons: czas
//    światła, ugięcie, aberracja, nutacja) – Horizons liczy precesję
//    i nutację modelami IAU 1976/1980, my IAU 2006/2000A. Różnica tempa
//    precesji (ok. 0,3″ na stulecie, J2000 − 1,21 stulecia) daje stałe
//    przesunięcie długości, jednakowe dla wszystkich ciał; sprawdzamy
//    jego wielkość i to, że jest wspólne.
import 'dart:math' as math;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';

void main() {
  final eph = SpkEphemeris([de440s, smallBodies]);
  final jd = julianDayTT(julianDay(1879, 3, 14, hour: 10, minute: 50));

  test('chwila zapytania Horizons', () {
    expect(jd, closeTo(2407422.951355287, 1e-8));
  });

  // Kod NAIF → (nazwa, RA, Dec astrometryczne ICRF; długość, szerokość
  // pozorne na ekliptyce daty), stopnie. Planety zewnętrzne – barycentra
  // układów (5–9), jak w efemerydach DE; Mars – Horizons 499 (środek
  // planety; od barycentrum różni się o mniej niż 0,001″).
  const horizons = {
    10: ('Słońce', 355.591152116, -1.909080185, 353.5076631, -0.0001942),
    301: ('Księżyc', 254.579366781, -26.548772600, 254.5258208, -3.8288336),
    199: ('Merkury', 4.589024785, 1.564756508, 3.1437999, -0.3899809),
    299: ('Wenus', 17.489687657, 6.682182107, 16.9849251, -0.6923773),
    4: ('Mars', 300.911958459, -21.295635235, 296.9141379, -0.8598678),
    5: ('Jowisz', 331.574289674, -12.486331318, 327.4840158, -0.7662729),
    6: ('Saturn', 6.249136811, 0.358020799, 4.1897438, -2.1558002),
    7: ('Uran', 155.208359499, 11.166604055, 151.2885153, 0.7987460),
    8: ('Neptun', 37.721238578, 13.034537348, 37.8718797, -1.7400532),
    9: ('Pluton', 57.282377304, 6.027189530, 54.7254767, -13.6940167),
    2002060: ('Chiron', 35.233087041, 12.942440738, 35.5446280, -1.0511446),
    2000001: ('Ceres', 47.291114125, 15.002640510, 47.3320092, -2.5820832),
    2000002: ('Pallas', 15.281527646, -5.962870588, 10.0367831, -11.5174430),
    2000003: ('Juno', 27.817957980, 3.658305521, 25.4618277, -7.2882161),
    2000004: ('Westa', 102.710381597, 25.816765369, 99.7568857, 2.8658820),
  };

  /// Różnica kątów a − b w sekundach łuku, w zakresie (−648000, 648000].
  double arcsec(double a, double b) {
    var d = (a - b) % 360;
    if (d > 180) d -= 360;
    return d * 3600;
  }

  group('astrometrycznie w ICRF', () {
    const astrometric = Corrections(
      deflection: false,
      aberration: false,
      nutation: false,
    );
    for (final MapEntry(key: naif, value: (name, ra, dec, _, _))
        in horizons.entries) {
      // Księżyc: DE440s wobec DE441 w Horizons różni się o ok. 0,005″.
      final tolerance = naif == 301 ? 0.01 : 0.001;
      test('$name zgodny z Horizons do $tolerance″', () {
        final (:direction, distance: _) = geocentricDirection(
          eph,
          naif,
          jd,
          corrections: astrometric,
        );
        final ourRa = math.atan2(direction.y, direction.x) * 180 / math.pi;
        final ourDec =
            math.asin(direction.z / direction.length) * 180 / math.pi;
        final cosDec = math.cos(dec * math.pi / 180);
        expect((arcsec(ourRa, ra) * cosDec).abs(), lessThan(tolerance));
        expect(arcsec(ourDec, dec).abs(), lessThan(tolerance));
      });
    }
  });

  test('pozornie na ekliptyce daty: wspólne przesunięcie modeli '
      'IAU 1976/1980 → IAU 2006/2000A', () {
    final dLon = <double>[];
    for (final MapEntry(key: naif, value: (name, _, _, lon, lat))
        in horizons.entries) {
      final p = geocentricEcliptic(eph, naif, jd);
      dLon.add(arcsec(p.longitude, lon));
      expect(arcsec(p.latitude, lat).abs(), lessThan(0.06), reason: name);
    }
    final mean = dLon.reduce((a, b) => a + b) / dLon.length;
    // Zmierzone 2026-11-03: średnio 0,305″, rozrzut 0,296–0,314″.
    expect(mean, closeTo(0.30, 0.03));
    for (final d in dLon) {
      expect(d, closeTo(mean, 0.02));
    }
  });
}
