// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Eclipses: all eclipses of 2026, the total solar eclipse of 12 August 2026
// seen from Valencia, and the contacts of the lunar eclipse of 3 March 2026.
//
//   dart run hevelius_ephemeris:download_jpl
//   dart run example/eclipses.dart
import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:hevelius_ephemeris/spk_io.dart';

String ut(double jdTT) {
  final d = calendarDateTime(julianDayUT(jdTT));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)}:${two(d.second.floor())} UT';
}

void main() {
  final ephemeris = SpkEphemeris([openSpkFile('data/jpl/de440s.bsp')]);
  final start = julianDay(2026, 1, 1), end = julianDay(2027, 1, 1);

  print('Solar eclipses in 2026:');
  for (final e in solarEclipses(ephemeris, start, end)) {
    print(
      '  ${ut(e.jdTT)}  ${e.type.name}, magnitude '
      '${e.magnitude.toStringAsFixed(3)}',
    );
  }
  print('Lunar eclipses in 2026:');
  for (final e in lunarEclipses(ephemeris, start, end)) {
    print(
      '  ${ut(e.jdTT)}  ${e.type.name}, umbral magnitude '
      '${e.umbralMagnitude.toStringAsFixed(3)}',
    );
  }

  final august = solarEclipses(
    ephemeris,
    julianDay(2026, 8, 1),
    julianDay(2026, 9, 1),
  ).single;
  final valencia = localSolarEclipse(
    ephemeris,
    august,
    latitude: 39.4699,
    longitude: -0.3763,
    height: 15,
  )!;
  print(
    '12 August 2026 from Valencia: ${valencia.type.name}, magnitude '
    '${valencia.magnitude.toStringAsFixed(3)}, totality '
    '${valencia.centralDuration!.toStringAsFixed(0)} s',
  );
  for (final (name, c) in [
    ('partial phase begins', valencia.firstContact),
    ('totality begins', valencia.secondContact!),
    ('totality ends', valencia.thirdContact!),
    ('partial phase ends', valencia.fourthContact),
  ]) {
    print(
      '  ${name.padRight(21)} ${ut(c.jdTT)}  Sun at '
      '${c.altitude.toStringAsFixed(1)}°'
      '${c.visible ? '' : ' (below the horizon)'}',
    );
  }

  final march = lunarEclipses(
    ephemeris,
    julianDay(2026, 3, 1),
    julianDay(2026, 3, 10),
  ).single;
  print('Lunar eclipse of 3 March 2026 – contacts:');
  print(
    '  partial phase  ${ut(march.partialBegin!)} – ${ut(march.partialEnd!)}',
  );
  if (march.totalBegin != null) {
    print('  total phase    ${ut(march.totalBegin!)} – ${ut(march.totalEnd!)}');
  }
}
