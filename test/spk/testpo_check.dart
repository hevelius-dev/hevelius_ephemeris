// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Porównanie efemerydy z oficjalnym plikiem kontrolnym JPL testpo.4xx:
// tysiące położeń i prędkości policzonych przez JPL dla losowych dat.
import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';

/// Jednostka astronomiczna w km (stała AU efemeryd DE440–DE442).
const au = 149597870.7;

/// Kody ciał z testpo → kody NAIF (14–17: nutacja, libracje, TT−TDB –
/// nie ma ich w plikach .bsp).
const testpoToNaif = {
  1: Naif.mercuryBarycenter,
  2: Naif.venusBarycenter,
  3: Naif.earth,
  4: Naif.marsBarycenter,
  5: Naif.jupiterBarycenter,
  6: Naif.saturnBarycenter,
  7: Naif.uranusBarycenter,
  8: Naif.neptuneBarycenter,
  9: Naif.plutoBarycenter,
  10: Naif.moon,
  11: Naif.sun,
  12: Naif.solarSystemBarycenter,
  13: Naif.earthMoonBarycenter,
};

/// Wiersz: numer efemerydy, data, JD, ciało, środek, współrzędna, wartość.
/// Przy latach ujemnych pola się sklejają („441-13200.09.01-3099998.5”),
/// więc dzielimy wyrażeniem regularnym, nie po spacjach.
final _line = RegExp(
  r'^\s*(\d{3})\s*(-?\d+\.\d\d\.\d\d)\s*(-?\d+\.\d+)'
  r'\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s*$',
);

/// Sprawdza [ephemeris] z plikiem kontrolnym [testpo] (w data/jpl/) dla
/// dat, które efemeryda obejmuje; zwraca liczbę sprawdzonych wartości.
int checkTestpo(String label, SpkEphemeris ephemeris, String testpo) {
  bool covers(int body, double et) =>
      body == Naif.solarSystemBarycenter || ephemeris.covers(body, et);
  var checked = 0;
  var maxPosition = 0.0, maxVelocity = 0.0;
  var pastHeader = false;
  for (final line in jplFile(testpo).readAsLinesSync()) {
    if (!pastHeader) {
      pastHeader = line.trim() == 'EOT';
      continue;
    }
    final m = _line.firstMatch(line);
    if (m == null) throw FormatException('Zły wiersz $testpo', line);
    final jed = double.parse(m.group(3)!);
    final target = testpoToNaif[int.parse(m.group(4)!)];
    final center = testpoToNaif[int.parse(m.group(5)!)];
    final coordinate = int.parse(m.group(6)!);
    final expected = double.parse(m.group(7)!);
    final et = (jed - j2000) * 86400;
    if (target == null || center == null) continue;
    if (!covers(target, et) || !covers(center, et)) continue;

    final s = ephemeris.state(target, center, et);
    // Położenie w j.a., prędkość w j.a./dobę.
    final actual = switch (coordinate) {
      1 => s.x / au,
      2 => s.y / au,
      3 => s.z / au,
      4 => s.vx * 86400 / au,
      5 => s.vy * 86400 / au,
      _ => s.vz * 86400 / au,
    };
    final error = (actual - expected).abs();
    if (coordinate <= 3) {
      if (error > maxPosition) maxPosition = error;
    } else {
      if (error > maxVelocity) maxVelocity = error;
    }
    // JPL uznaje odczyt za poprawny przy różnicy do 1e-13 j.a.
    expect(error, lessThan(1e-13), reason: line);
    checked++;
  }
  print(
    '$label, $testpo: $checked wartości; największa różnica: położenie '
    '${(maxPosition * au * 1000).toStringAsFixed(4)} m, prędkość '
    '${(maxVelocity * au * 1e6 / 86400).toStringAsFixed(6)} mm/s',
  );
  return checked;
}
