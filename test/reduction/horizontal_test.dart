// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Współrzędne horyzontalne: refrakcja wg Meeusa (przykład 16.a) i wartości
// topocentryczne z NASA JPL Horizons (horizons_topocentric.csv: Warszawa,
// 5 ciał, z refrakcją i bez). Zgodność do ok. 0,7″ – reszta to pominięta
// aberracja dobowa (≤ 0,3″) i drobna różnica ΔT/UT1 względem Horizons.
import 'dart:io';
import 'dart:math' as math;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';

void main() {
  test('refrakcja: Meeus, przykład 16.a – h = 0,5541° → R = 24,618′', () {
    // Przykład liczy wzorem 16.4 bez poprawki zerującej refrakcję
    // w zenicie (+0,0019279′), którą stosujemy.
    expect(refraction(0.5541) * 60, closeTo(24.618 + 0.0019279, 0.0005));
  });

  test('refrakcja: zero w zenicie, ok. 34′ przy horyzoncie, ciśnienie', () {
    expect(refraction(90) * 3600, closeTo(0, 0.01));
    expect(refraction(-0.57) * 60, inInclusiveRange(33, 36));
    // Wyższe ciśnienie i niższa temperatura – większa refrakcja.
    expect(
      refraction(10, pressure: 1030, temperature: -10),
      greaterThan(refraction(10)),
    );
    // Poniżej −1° wartość stała (obiekt i tak niewidoczny).
    expect(refraction(-5), refraction(-1));
  });

  test('NASA JPL Horizons: azymut i wysokość topocentryczne do 1″', () {
    final ephemeris = SpkEphemeris([de440]);
    final warsaw = Observer(latitude: 52.2297, longitude: 21.0122, height: 100);
    var checked = 0;
    for (final line in File(
      'test/reduction/horizons_topocentric.csv',
    ).readAsLinesSync()) {
      if (line.startsWith('#') || line.startsWith('body')) continue;
      final f = line.split(',');
      final body = switch (int.parse(f[0])) {
        499 => Naif.marsBarycenter,
        599 => Naif.jupiterBarycenter,
        final id => id,
      };
      final refracted = f[1] == 'refracted';
      final expectedAltitude = double.parse(f[7]);
      // Refrakcję porównujemy tylko nad horyzontem.
      if (refracted && expectedAltitude < 0) continue;
      final jd = julianDay(
        int.parse(f[2]),
        int.parse(f[3]),
        int.parse(f[4]),
        hour: int.parse(f[5]),
      );
      final h = horizontalPosition(
        ephemeris,
        body,
        warsaw,
        jd,
        withRefraction: refracted,
      );
      final dAz =
          ((h.azimuth - double.parse(f[6]) + 540) % 360 - 180) *
          math.cos(expectedAltitude * math.pi / 180);
      expect(dAz * 3600, closeTo(0, 1), reason: line);
      expect(
        (h.altitude - expectedAltitude) * 3600,
        closeTo(0, 1),
        reason: line,
      );
      checked++;
    }
    expect(checked, greaterThan(60));
  });

  test('Księżyc: paralaksa obniża go o prawie 1° przy horyzoncie', () {
    final ephemeris = SpkEphemeris([de440s]);
    final o = Observer(latitude: 52.2297, longitude: 21.0122);
    for (
      var jd = julianDay(2026, 3, 1);
      jd < julianDay(2026, 3, 3);
      jd += 0.25
    ) {
      final topo = horizontalPosition(ephemeris, Naif.moon, o, jd);
      final geo = altitude(ephemeris, Naif.moon, 52.2297, 21.0122, jd);
      // Paralaksa ≤ 1,02° (perygeum) i ≥ 0 – zawsze obniża.
      expect(geo - topo.altitude, inInclusiveRange(0, 1.02));
    }
  });

  test('gwiazdy i dowolne współrzędne: zgodne ze sobą', () {
    final ephemeris = SpkEphemeris([de440s]);
    final o = Observer(latitude: 52.2297, longitude: 21.0122);
    // Syriusz z pliku jasnych gwiazd.
    final sirius = FixedStar.parseCsv(
      File('data/stars/jasne_gwiazdy.csv').readAsStringSync(),
    ).firstWhere((s) => s.designation == 'alf CMa');
    final jd = julianDay(2026, 1, 15, hour: 22);
    final star = fixedStarHorizontal(ephemeris, sirius, o, jd);
    // Te same RA/Dec daty podane wprost – ten sam wynik.
    final direct = equatorialToHorizontal(
      star.rightAscension,
      star.declination,
      o,
      jd,
    );
    expect(direct.altitude, closeTo(star.altitude, 1e-9));
    expect(direct.azimuth, closeTo(star.azimuth, 1e-9));
    // Zimowy wieczór w Warszawie: Syriusz nisko na południu.
    expect(star.altitude, inInclusiveRange(5, 25));
    expect(star.azimuth, inInclusiveRange(150, 210));
  });
}
