// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Positions for a horoscope: Albert Einstein, 14 March 1879, 11:30 local
// mean time in Ulm (10:50 UT), 48°24′ N, 10°00′ E.
//
// Download the JPL file first:
//
//   dart run hevelius_ephemeris:download_jpl
//   dart run example/example.dart
import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:hevelius_ephemeris/spk_io.dart';

void main() {
  final ephemeris = SpkEphemeris([openSpkFile('data/jpl/de440s.bsp')]);

  final jdUt = julianDay(1879, 3, 14, hour: 10, minute: 50);
  final jdTT = julianDayTT(jdUt);

  const bodies = {'Sun': 10, 'Moon': 301, 'Mercury': 1, 'Venus': 2};
  for (final MapEntry(key: name, value: naif) in bodies.entries) {
    final p = geocentricEcliptic(ephemeris, naif, jdTT);
    print('${name.padRight(8)} ${format(p.longitude)}');
  }

  final node = lunarPoint(ephemeris, LunarPoint.trueNode, jdTT);
  print('${'Node'.padRight(8)} ${format(node.longitude)}');

  final a = angles(jdUt, 48.4, 10.0);
  print('${'ASC'.padRight(8)} ${format(a.ascendant)}');
  print('${'MC'.padRight(8)} ${format(a.midheaven)}');
}

/// Ecliptic longitude as degrees, minutes and seconds within a sign.
String format(double longitude) {
  const signs = [
    'Ari', 'Tau', 'Gem', 'Can', 'Leo', 'Vir', //
    'Lib', 'Sco', 'Sgr', 'Cap', 'Aqr', 'Psc',
  ];
  final seconds = (longitude * 3600).round();
  final sign = signs[seconds ~/ (30 * 3600) % 12];
  final d = seconds ~/ 3600 % 30, m = seconds ~/ 60 % 60, s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.toString().padLeft(2)}° $sign ${two(m)}′ ${two(s)}″';
}
