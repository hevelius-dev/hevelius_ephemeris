// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Długookresowa precesja Vondráka, Capitaine i Wallace'a (2011, z poprawką
// 2012) wobec IAU 2006: w J2000 zgodność z definicji (sprawdza
// współczynniki przy cosinusach), w latach 1900–2100 do 0,001″
// (sprawdza współczynniki przy sinusach – błąd dałby wyraz liniowy).
import 'dart:math' as math;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

void main() {
  test('w J2000: P_A = Q_A = X_A = Y_A = s_A = 0 (do 0,000002″)', () {
    final (p, q) = longTermEclipticPoleAngles(0);
    final (x, y) = longTermEquatorPoleAngles(0);
    for (final v in [p, q, x, y, longTermCioLocator(0)]) {
      expect(v / arcsecond, closeTo(0, 2e-6));
    }
  });

  test('w J2000 bieguny jak w IAU 2006: nachylenie ε₀ = 84 381,406″', () {
    final n = longTermEquatorPole(0), k = longTermEclipticPole(0);
    expect(math.acos(n.dot(k)) / arcsecond, closeTo(84381.406, 2e-6));
  });

  // Ekliptyka daty: oś x – punkt równonocy (n × k), z – biegun ekliptyki.
  List<Vector3> frame(double t) {
    final n = longTermEquatorPole(t), k = longTermEclipticPole(t);
    final x = n.cross(k).unit;
    return [x, k.cross(x), k];
  }

  final e0 = frame(0);
  // Kierunek GCRS → średni równik J2000: przesunięcie układu (bias)
  // wzięte z IAU 2006 w J2000.
  Vector3 toMean(Vector3 r) {
    final u = gcrsToEclipticOfDateIau2006(r, 0, nutationInLongitude: 0);
    return e0[0] * u.x + e0[1] * u.y + e0[2] * u.z;
  }

  double longitudeDifference(Vector3 r, double t) {
    final iau = gcrsToEclipticOfDateIau2006(r, t, nutationInLongitude: 0);
    final m = toMean(r);
    final f = frame(t);
    final ours = math.atan2(f[1].dot(m), f[0].dot(m));
    final d =
        (ours - math.atan2(iau.y, iau.x) + 3 * math.pi) % (2 * math.pi) -
        math.pi;
    return d / arcsecond;
  }

  test('1900–2100: nachylenie i długości jak w IAU 2006 (do 0,001″)', () {
    final directions = [
      Vector3(1, 0, 0),
      Vector3(0, 1, 0),
      Vector3(0.3, 0.4, 0.866).unit,
      Vector3(-0.5, 0.2, -0.84).unit,
    ];
    for (var year = 1900; year <= 2100; year += 10) {
      final t = (year - 2000) / 100;
      final n = longTermEquatorPole(t), k = longTermEclipticPole(t);
      final epsilon = math.acos(n.dot(k));
      expect(
        (epsilon - meanObliquityIau2006(t)) / arcsecond,
        closeTo(0, 0.001),
      );
      for (final r in directions) {
        expect(longitudeDifference(r, t), closeTo(0, 0.001), reason: '$year');
      }
    }
  });

  test('daleko od J2000 IAU 2006 się rozjeżdża (−3000: kilkanaście ″)', () {
    // Artykuł: IAU 2006 dobre w ok. ±1000 lat, dalej szybko się rozchodzi.
    final d = longitudeDifference(Vector3(1, 0, 0), -50).abs();
    expect(d, inInclusiveRange(5, 30));
  });

  test('czas gwiazdowy: 1600–2500 jak IAU 2006 (do 0,03″)', () {
    for (var year = 1600; year <= 2500; year += 25) {
      final jd = julianDay(year, 1, 1);
      final jdTT = julianDayTT(jd);
      final d =
          greenwichMeanSiderealTime(jd, jdTT) -
          greenwichMeanSiderealTimeIau2006(jd, jdTT);
      final wrapped = (d + 3 * math.pi) % (2 * math.pi) - math.pi;
      expect(wrapped / arcsecond, closeTo(0, 0.03), reason: '$year');
    }
  });

  test('w J2000: GMST − ERA = 0,0146″ (bias 0,014506″ + s₀ ≈ 0,0001″)', () {
    expect(longTermGmstMinusEra(0) / arcsecond, closeTo(0.0146, 0.0001));
  });

  test('dalekie epoki działają, poza ±200 000 lat – błąd', () {
    final r = Vector3(0.3, 0.4, 0.866).unit;
    for (final t in [-150.0, -50.0, 150.0]) {
      expect(
        gcrsToEclipticOfDate(r, t, nutationInLongitude: 0).length,
        closeTo(1, 1e-12),
      );
      expect(meanObliquity(t) / arcsecond, inInclusiveRange(78000, 88000));
    }
    expect(() => meanObliquity(2500), throwsArgumentError);
  });

  test('ekliptyka daty → GCRS odwraca GCRS → ekliptyka daty', () {
    final r = Vector3(0.3, -0.4, 0.866) * 1.5e8;
    for (final t in [-150.0, -3.0, 0.0, 0.26, 150.0]) {
      final back = longTermMeanEclipticOfDateToGcrs(
        longTermGcrsToMeanEclipticOfDate(r, t),
        t,
      );
      expect((back - r).length, lessThan(1e-6)); // km
    }
  });
}
