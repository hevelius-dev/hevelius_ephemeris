// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// The sky over Warsaw: altitude and azimuth of the Moon, planets and Sirius
// – the data behind a sky map.
//
//   dart run hevelius_ephemeris:download_jpl
//   dart run example/sky.dart
import 'dart:io';

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:hevelius_ephemeris/spk_io.dart';

void main() {
  final ephemeris = SpkEphemeris([openSpkFile('data/jpl/de440s.bsp')]);
  final warsaw = Observer(latitude: 52.2297, longitude: 21.0122, height: 100);
  // 15 January 2027, 21:00 UT.
  final jd = julianDayTT(julianDay(2027, 1, 15, hour: 21));

  print('Warsaw, 15 January 2027 21:00 UT (altitude with refraction):');
  const bodies = {
    'Moon': Naif.moon,
    'Venus': Naif.venus,
    'Mars': Naif.marsBarycenter,
    'Jupiter': Naif.jupiterBarycenter,
    'Saturn': Naif.saturnBarycenter,
  };
  for (final MapEntry(key: name, value: naif) in bodies.entries) {
    final h = horizontalPosition(
      ephemeris,
      naif,
      warsaw,
      jd,
      withRefraction: true,
    );
    print(
      '  ${name.padRight(8)} altitude ${h.altitude.toStringAsFixed(1).padLeft(5)}°'
      '  azimuth ${h.azimuth.toStringAsFixed(1).padLeft(5)}°',
    );
  }

  final sirius = FixedStar.parseCsv(
    File('data/stars/jasne_gwiazdy.csv').readAsStringSync(),
  ).firstWhere((s) => s.designation == 'alf CMa');
  final h = fixedStarHorizontal(
    ephemeris,
    sirius,
    warsaw,
    jd,
    withRefraction: true,
  );
  print(
    '  ${'Sirius'.padRight(8)} altitude ${h.altitude.toStringAsFixed(1).padLeft(5)}°'
    '  azimuth ${h.azimuth.toStringAsFixed(1).padLeft(5)}°',
  );
}
