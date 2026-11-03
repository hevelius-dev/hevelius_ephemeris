// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Events: sign ingresses of the Sun, lunar phases, sunrise and sunset.
//
//   dart run hevelius_ephemeris:download_jpl
//   dart run example/events.dart
import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:hevelius_ephemeris/spk_io.dart';

/// A moment in Terrestrial Time shown as a UT date and time (minutes).
String ut(double jdTT) {
  final d = calendarDateTime(julianDayUT(jdTT));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)} UT';
}

void main() {
  final ephemeris = SpkEphemeris([openSpkFile('data/jpl/de440s.bsp')]);
  const signs = [
    'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo', //
    'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces',
  ];

  print('The Sun enters a sign (first half of 2027):');
  final sun = bodyLongitude(ephemeris, Naif.sun);
  for (final i in ingresses(
    sun,
    julianDay(2027, 1, 1),
    julianDay(2027, 7, 1),
  )) {
    print('  ${ut(i.jdTT)}  ${signs[i.sign]}');
  }

  print('Lunar phases (March 2027):');
  for (final p in lunarPhases(
    ephemeris,
    julianDay(2027, 3, 1),
    julianDay(2027, 4, 1),
  )) {
    print('  ${ut(p.jdTT)}  ${p.phase.name}');
  }

  print('Sunrise and sunset in Warsaw (21 June 2027):');
  final day = julianDay(2027, 6, 21);
  for (final e in horizonEvents(
    ephemeris,
    Naif.sun,
    52.2297,
    21.0122,
    day,
    day + 1,
  )) {
    if (e.kind == HorizonEventKind.rise || e.kind == HorizonEventKind.set) {
      print('  ${ut(e.jdTT)}  ${e.kind.name}');
    }
  }
}
