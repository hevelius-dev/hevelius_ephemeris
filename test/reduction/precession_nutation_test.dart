// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:math' as math;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:hevelius_ephemeris/src/reduction/nutation_data.dart';
import 'package:test/test.dart';

import 'nutation_sources.dart';

void main() {
  test('wygenerowane dane nutacji i równania równonocy zgadzają się z tabelami IERS', () {
    // Gdy test pada: dart run tool/generate_nutation.dart
    expect(
      nutationInLongitude,
      readNutationTable(File('data/iers/tab5.3a.txt')),
    );
    expect(
      nutationInObliquity,
      readNutationTable(File('data/iers/tab5.3b.txt')),
    );
    expect(nutationInLongitude.length ~/ 17, 1320 + 38);
    expect(nutationInObliquity.length ~/ 17, 1037 + 19);
    expect(
      equationOfEquinoxesTerms,
      readNutationTable(File('data/iers/tab5.2e.txt')),
    );
    expect(equationOfEquinoxesTerms.length ~/ 17, 33 + 1);
  });

  test('wyrazy uzupełniające równania równonocy poniżej 0,003″', () {
    // IERS Conventions (2010), tabela 5.2e: największy wyraz
    // 2640,96 µas · sin Ω, razem kilka mas.
    var largest = 0.0;
    for (var t = -40.0; t <= 20; t += 0.01) {
      final v = equationOfEquinoxesComplementaryTerms(t).abs() / arcsecond;
      expect(v, lessThan(0.003));
      largest = math.max(largest, v);
    }
    expect(largest, greaterThan(0.0026));
  });

  test('średnie nachylenie ekliptyki w J2000 = 84381,406″', () {
    // IAU 2006 – dokładnie; model Vondráka – do zaokrąglenia
    // publikowanych współczynników (0,000001″).
    expect(meanObliquityIau2006(0) / arcsecond, closeTo(84381.406, 1e-9));
    expect(meanObliquity(0) / arcsecond, closeTo(84381.406, 2e-6));
  });

  test('nutacja w granicach znanej amplitudy (ok. 17″ i 9″)', () {
    for (var t = -1.5; t <= 1.5; t += 0.01) {
      final n = nutation(t);
      expect((n.longitude / arcsecond).abs(), lessThan(20));
      expect((n.obliquity / arcsecond).abs(), lessThan(11));
    }
  });

  test('główny okres nutacji: 18,6 roku (obieg węzła Księżyca)', () {
    // Δψ wraca do podobnej wartości po 18,6 roku, a po połowie okresu
    // ma przeciwny znak głównego wyrazu.
    double dpsi(double years) => nutation(years / 100).longitude / arcsecond;
    final period = 18.6;
    var maxDiff = 0.0;
    for (var y = 0.0; y < 20; y += 0.5) {
      maxDiff = math.max(maxDiff, (dpsi(y) - dpsi(y + period)).abs());
    }
    // Pozostałość od krótszych wyrazów (półroczny ok. 1,3″ itd.).
    expect(maxDiff, lessThan(3));
  });

  test('biegun równika w J2000 leży 90° − ε od ekliptyki', () {
    final pole = gcrsToEclipticOfDate(
      const Vector3(0, 0, 1),
      0,
      nutationInLongitude: 0,
    );
    final latitude = math.asin(pole.z) * 180 / math.pi;
    expect(latitude, closeTo(90 - 84381.406 / 3600, 1e-5));
  });

  test('nutacja z interpolacji = szereg IAU 2000A do 1 µas', () {
    // Losowe daty w zakresie DE442 i daleko poza nim; w tym chwile tuż
    // przy pełnych dniach (węzłach siatki).
    const uas = arcsecond / 1e6;
    final rnd = math.Random(2026);
    final ts = [
      for (var i = 0; i < 3000; i++) (rnd.nextDouble() * 11 - 6.5),
      for (var i = 0; i < 300; i++) (rnd.nextDouble() * 300 - 150),
      for (var i = 0; i < 100; i++)
        ((2461000.5 + i) - 2451545.0 + (i.isEven ? 1e-9 : -1e-9)) / 36525,
    ];
    for (final t in ts) {
      final fast = nutation(t), series = nutationIau2000A(t);
      expect(fast.longitude, closeTo(series.longitude, uas), reason: '$t');
      expect(fast.obliquity, closeTo(series.obliquity, uas), reason: '$t');
    }
  });

  test('nutacja w pełnym dniu TT = wartość szeregu', () {
    for (final jd in [2451545.0, 2461356.0, 2287000.0, -1000000.0]) {
      final t = (jd - 2451545.0) / 36525;
      expect(
        nutation(t).longitude,
        closeTo(nutationIau2000A(t).longitude, 1e-15),
      );
    }
  });
}
