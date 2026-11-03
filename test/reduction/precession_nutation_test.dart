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

  test('zapamiętane wyniki nutacji zgadzają się z policzonymi', () {
    // Każde t liczone pierwszy raz jest liczone od nowa; potem pytamy
    // na przemian o świeże i dawne chwile (więcej niż mieści pamięć).
    final ts = [for (var i = 0; i < 20; i++) 0.2371 + i * 1e-4];
    final fresh = [for (final t in ts) nutation(t)];
    for (var round = 0; round < 3; round++) {
      for (var i = 0; i < ts.length; i++) {
        final j = (i * 7 + round) % ts.length;
        expect(nutation(ts[j]), fresh[j]);
        expect(nutation(ts[j]), fresh[j]);
      }
    }
  });
}
