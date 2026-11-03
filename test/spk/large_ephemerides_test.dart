// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// DE441 (−13200…+17191, 3,3 GB) i DE442 (1550–2650) wobec plików
// kontrolnych JPL. Domyślnie pomijane (dart_test.yaml); uruchomienie:
//   dart run tool/download_jpl.dart --de441
//   dart test -P duze-pliki
@Tags(['duze-pliki'])
library;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:hevelius_ephemeris/spk_io.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';
import 'testpo_check.dart';

void main() {
  // Pliki czytane z dysku na żądanie (openSpkFile), nie w całości do pamięci.
  SpkEphemeris open(String name) => SpkEphemeris([
    openSpkFile(jplFile(name, tool: 'download_jpl.dart --de441').path),
  ]);

  test('DE441 zgodne z testpo.441 w całym zakresie', () {
    final checked = checkTestpo('de441', open('de441.bsp'), 'testpo.441');
    expect(checked, greaterThan(300000));
  });

  test('DE442 zgodne z testpo.442', () {
    final checked = checkTestpo('de442', open('de442.bsp'), 'testpo.442');
    expect(checked, greaterThan(10000));
  });

  test('DE441 = DE440 dla planet, Księżyc różni się o ułamek sekundy', () {
    final e440 = SpkEphemeris([de440]);
    final e441 = open('de441.bsp');
    double diff(int body, double jd) =>
        ((geocentricEcliptic(e441, body, jd).longitude -
                        geocentricEcliptic(e440, body, jd).longitude +
                        540) %
                    360 -
                180)
            .abs() *
        3600;
    for (
      var jd = julianDay(1600, 1, 1);
      jd < julianDay(2600, 1, 1);
      jd += 3653
    ) {
      expect(diff(Naif.marsBarycenter, jd), lessThan(1e-4));
      expect(diff(Naif.moon, jd), lessThan(0.3));
    }
  });
}
