// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Porównanie z NASA JPL Horizons (wartości w horizons_reference.csv).
import 'dart:io';
import 'dart:math' as math;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';

typedef Row = ({
  int naif,
  double jd,
  double ra,
  double dec,
  double lon,
  double lat,
});

List<Row> readReference() => [
  for (final line in File(
    'test/reduction/horizons_reference.csv',
  ).readAsLinesSync())
    if (!line.startsWith('#') && !line.startsWith('naif'))
      () {
        final p = line.split(',');
        return (
          naif: int.parse(p[0]),
          jd: double.parse(p[1]),
          ra: double.parse(p[2]),
          dec: double.parse(p[3]),
          lon: double.parse(p[4]),
          lat: double.parse(p[5]),
        );
      }(),
];

const degree = math.pi / 180;

/// Odległość kątowa w sekundach łuku między kierunkami (ra, dec).
double separation(double ra1, double dec1, double ra2, double dec2) {
  Vector3 v(double ra, double dec) => Vector3(
    math.cos(dec * degree) * math.cos(ra * degree),
    math.cos(dec * degree) * math.sin(ra * degree),
    math.sin(dec * degree),
  );
  final d = (v(ra1, dec1) - v(ra2, dec2)).length;
  return 2 * math.asin(d / 2) / degree * 3600;
}

/// Różnica długości w sekundach łuku, z uwzględnieniem przejścia 360°.
double longitudeDifference(double a, double b) {
  var d = (a - b) % 360;
  if (d > 180) d -= 360;
  return d * 3600;
}

void main() {
  final eph = SpkEphemeris([de440s, smallBodies]);
  final rows = readReference();

  test('astrometryczne RA/Dec (dane + czas światła) zgodne do 0,01″', () {
    for (final r in rows) {
      final (:direction, distance: _) = geocentricDirection(
        eph,
        r.naif,
        r.jd,
        corrections: const Corrections(
          deflection: false,
          aberration: false,
          nutation: false,
        ),
      );
      final ra = math.atan2(direction.y, direction.x) / degree % 360;
      final dec = math.asin(direction.z) / degree;
      // Planety zgadzają się do 0,00001″; Księżyc do ok. 0,006″
      // (Horizons używa DE441, my DE440); planetoidy – zob. wynik testu.
      expect(separation(ra, dec, r.ra, r.dec), lessThan(0.01), reason: '$r');
    }
  });

  test('pozorne λ, β: różnica tylko od modelu precesji Horizons', () {
    // Horizons liczy ekliptykę daty modelem IAU 1976/1980, my IAU 2006;
    // modele rozchodzą się o ok. 0,05″ w 2000 r. i ok. 0,2″ sto lat
    // wcześniej lub później. Różnica jest wspólna dla wszystkich ciał
    // w danej chwili – błąd w czasie światła, ugięciu czy aberracji
    // dawałby różne odchyłki dla różnych ciał.
    // Modele różnią się też ułożeniem samej ekliptyki (ok. 0,04″), co
    // zmienia długość proporcjonalnie do tg β – ważne dla Pallas, który
    // bywa 48° od ekliptyki.
    final byDate = <double, List<(double, double)>>{};
    for (final r in rows) {
      final p = geocentricEcliptic(eph, r.naif, r.jd);
      final dLon = longitudeDifference(p.longitude, r.lon);
      expect(dLon.abs(), lessThan(0.3), reason: '$r');
      expect(((p.latitude - r.lat) * 3600).abs(), lessThan(0.05));
      final tanLat = math.tan(r.lat * degree).abs();
      byDate.putIfAbsent(r.jd, () => []).add((dLon, tanLat));
    }
    for (final MapEntry(key: jd, value: diffs) in byDate.entries) {
      final sorted = [for (final (d, _) in diffs) d]..sort();
      final median = sorted[sorted.length ~/ 2];
      for (final (d, tanLat) in diffs) {
        expect(
          (d - median).abs(),
          lessThan(0.02 + 0.04 * tanLat),
          reason: 'JD $jd: $diffs',
        );
      }
    }
  });

  test('ciało za tarczą Słońca: bez ugięcia światła, jak w Horizons', () {
    // Horizons (pobrane 2026-10-30, QUANTITIES=31): Uran 30.05.2028
    // i Wenus 10.12.1862, obie schowane za Słońcem. Z ugięciem λ różniłaby
    // się o 4″ i 0,6″; zostaje tylko różnica modeli precesji.
    const cases = [
      (7, 2461922.49480049, 70.0350565, -0.0526461, 0.05),
      (2, 2401485.3270083643, 258.5506654, -0.0776169, 0.4),
    ];
    for (final (naif, jd, lon, lat, modelDifference) in cases) {
      final p = geocentricEcliptic(eph, naif, jd);
      expect(
        longitudeDifference(p.longitude, lon).abs(),
        lessThan(modelDifference),
      );
      expect(((p.latitude - lat) * 3600).abs(), lessThan(0.05));
    }
  });
}
