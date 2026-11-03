// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';

void main() {
  final eph = SpkEphemeris([de440s]);
  // Horoskop wzorcowy: Albert Einstein, 14.03.1879 10:50 UT.
  final jd = julianDayTT(julianDay(1879, 3, 14, hour: 10, minute: 50));

  double arcsec(double a, double b) {
    var d = (a - b) % 360;
    if (d > 180) d -= 360;
    return d * 3600;
  }

  double nutationDeg(double jd) =>
      nutation(centuriesSinceJ2000(jd)).longitude * 180 / math.pi;

  // Elementy oskulacyjne orbity Księżyca względem środka Ziemi z NASA/JPL
  // Horizons (zapytanie 2026-11-03: EPHEM_TYPE = ELEMENTS, CENTER =
  // 500@399, TLIST = 2407422.951355287 TDB, REF_PLANE = ECLIPTIC,
  // REF_SYSTEM = ICRF; Keplerian GM = 403503.2356 km³/s² – jak nasze
  // earthMoonGM). Płaszczyzna odniesienia Horizons: ekliptyka J2000
  // w starej definicji – nachylenie 84381,448″ (IAU 1976) do równika ICRF.
  // Orbitę przenosimy do ICRF, a potem do ekliptyki daty tą samą funkcją,
  // co inne kierunki – porównanie nie zależy od definicji ekliptyki.
  const hzInclination = 5.139583785438333,
      hzNode = 304.5499019538840,
      hzPerigeeArgument = 238.8586601934720,
      hzApogeeDistance = 401048.1982089556;
  const degree = math.pi / 180;
  const eps1976 = 84381.448 / 3600 * degree;
  final t = centuriesSinceJ2000(jd);
  final dpsi = nutation(t).longitude;
  Vector3 toOurs(Vector3 horizonsEcliptic) => gcrsToEclipticOfDate(
    horizonsEcliptic.rotateX(-eps1976),
    t,
    nutationInLongitude: dpsi,
  );
  const i = hzInclination * degree, om = hzNode * degree;

  test('węzeł prawdziwy zgodny z orbitą z Horizons, wstecz', () {
    // Normalna do płaszczyzny orbity (kierunek momentu pędu).
    final n = toOurs(
      Vector3(
        math.sin(i) * math.sin(om),
        -math.sin(i) * math.cos(om),
        math.cos(i),
      ),
    );
    final expected = math.atan2(n.x, -n.y) * 180 / math.pi;
    final p = lunarPoint(eph, LunarPoint.trueNode, jd);
    expect(arcsec(p.longitude, expected).abs(), lessThan(0.05));
    final v = longitudeSpeed(
      (j) => lunarPoint(eph, LunarPoint.trueNode, j).longitude,
      jd,
    );
    expect(v, lessThan(0));
  });

  test('Lilith oskulacyjna zgodna z orbitą z Horizons', () {
    final u = (hzPerigeeArgument + 180) * degree;
    final a = toOurs(
      Vector3(
        math.cos(om) * math.cos(u) - math.sin(om) * math.sin(u) * math.cos(i),
        math.sin(om) * math.cos(u) + math.cos(om) * math.sin(u) * math.cos(i),
        math.sin(u) * math.sin(i),
      ),
    );
    final p = lunarPoint(eph, LunarPoint.osculatingApogee, jd);
    expect(
      arcsec(p.longitude, math.atan2(a.y, a.x) * 180 / math.pi).abs(),
      lessThan(0.1),
    );
    expect(
      arcsec(p.latitude, math.asin(a.z) * 180 / math.pi).abs(),
      lessThan(0.1),
    );
    expect((p.distance - hzApogeeDistance).abs(), lessThan(0.1)); // km
  });

  test('węzeł średni: przykład 22.a J. Meeusa (Ω = 11,2531°)', () {
    // J. Meeus, Astronomical Algorithms, 2nd ed. (1998), przykład 22.a:
    // 10.04.1987 0h TD, JDE 2446895.5; średnia równonoc daty, a wynik
    // lunarPoint – prawdziwa (z nutacją).
    const jde = 2446895.5;
    final p = lunarPoint(eph, LunarPoint.meanNode, jde);
    expect(
      arcsec(p.longitude - nutationDeg(jde), 11.2531).abs(),
      lessThan(0.2),
    );
  });

  test('Lilith średnia: przykład 47.a J. Meeusa, poza ekliptyką', () {
    // J. Meeus, Astronomical Algorithms, 2nd ed., przykład 47.a:
    // JDE 2448724.5, L′ = 134,290182°, M′ = 5,150833°, F = 219,889721°.
    // Węzeł Ω = L′ − F, perygeum Π = L′ − M′ (długość „łamana”: po
    // ekliptyce do węzła, dalej po orbicie), apogeum naprzeciw – rzut
    // z orbity nachylonej o meanLunarInclination na ekliptykę.
    const jde = 2448724.5;
    const node = 134.290182 - 219.889721;
    const apogee = 134.290182 - 5.150833 + 180;
    const inc = meanLunarInclination * degree;
    const u = (apogee - node) * degree;
    final lon =
        node + math.atan2(math.sin(u) * math.cos(inc), math.cos(u)) / degree;
    final p = lunarPoint(eph, LunarPoint.meanApogee, jde);
    // Stałe 0,703″: L′ z wzoru (47.1) Meeusa różni się o 0,000195° od
    // stałych we wzorach na Ω (47.7) i Π, z których liczymy – węzeł
    // liczony jako L′ − F ma tę samą różnicę.
    expect(arcsec(p.longitude - nutationDeg(jde), lon), closeTo(0.703, 0.01));
    expect(
      arcsec(
        lunarPoint(eph, LunarPoint.meanNode, jde).longitude - nutationDeg(jde),
        node,
      ),
      closeTo(0.703, 0.01),
    );
    // Apogeum leży na orbicie Księżyca, nachylonej o ok. 5,1°.
    expect(
      p.latitude,
      closeTo(math.asin(math.sin(u) * math.sin(inc)) / degree, 1e-6),
    );
  });

  test('węzeł średni cofa się o ok. 19,3° na rok', () {
    final v = longitudeSpeed(
      (j) => lunarPoint(eph, LunarPoint.meanNode, j).longitude,
      jd,
    );
    expect(v * 365.25, closeTo(-19.34, 0.01));
  });

  test('Lilith średnia: obieg ok. 8,85 roku', () {
    // Średnia prędkość z 60 lat: chwilowa waha się, bo apogeum jest
    // rzutowane z orbity Księżyca na ekliptykę.
    var sum = 0.0, n = 0;
    for (var d = 0.0; d < 60 * 365.25; d += 10) {
      sum += longitudeSpeed(
        (j) => lunarPoint(eph, LunarPoint.meanApogee, j).longitude,
        jd + d,
      );
      n++;
    }
    expect(360 / (sum / n * 365.25), closeTo(8.85, 0.02));
  });

  test('Lilith oskulacyjna: apogeum ok. 400–410 tys. km', () {
    for (var d = 0; d < 60; d += 3) {
      final p = lunarPoint(eph, LunarPoint.osculatingApogee, jd + d);
      expect(p.distance, inInclusiveRange(395000, 415000));
      expect(p.latitude.abs(), lessThan(5.4));
    }
  });

  test('węzeł prawdziwy waha się wokół średniego (do ok. 1,8°)', () {
    for (var d = 0.0; d < 365; d += 5) {
      final t = lunarPoint(eph, LunarPoint.trueNode, jd + d).longitude;
      final m = lunarPoint(eph, LunarPoint.meanNode, jd + d).longitude;
      expect((arcsec(t, m) / 3600).abs(), lessThan(2));
    }
  });

  group('prędkości', () {
    test('14.03.1879: kierunek i prędkość ruchu jak w Horizons', () {
      // Długości pozorne z NASA/JPL Horizons (wielkość 31) pół doby przed
      // i pół doby po chwili horoskopu (TT): Uran jako jedyny wstecz.
      const horizons = {
        10: (353.0096276, 354.0055835),
        301: (247.5185759, 261.4377167),
        199: (2.1663122, 4.1179679),
        299: (16.3689336, 17.6007603),
        4: (296.5498590, 297.2785088),
        5: (327.3702438, 327.5976113),
        6: (4.1279866, 4.2515625),
        7: (151.3083439, 151.2687862),
        8: (37.8575312, 37.8863226),
        9: (54.7194502, 54.7315811),
      };
      for (final MapEntry(key: naif, value: (before, after))
          in horizons.entries) {
        final ours = longitudeSpeed(
          (j) => geocentricEcliptic(eph, naif, j).longitude,
          jd,
        );
        final theirs = arcsec(after, before) / 3600; // °/dobę
        expect(ours.sign, theirs.sign, reason: '$naif');
        // Prędkość chwilowa wobec średniej z doby: Księżyc przyspiesza.
        expect(
          ours,
          closeTo(theirs, naif == 301 ? 0.01 : 0.0005),
          reason: '$naif',
        );
      }
    });

    test('przejście przez 0°/360° nie zaburza prędkości', () {
      // Funkcja rosnąca 1°/dobę, która w jd = 0 przechodzi przez 360°.
      double lon(double j) => (359.999 + j) % 360;
      expect(longitudeSpeed(lon, 0.0005), closeTo(1, 1e-9));
    });
  });
}
