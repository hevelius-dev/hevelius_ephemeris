// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Porównuje wyniki Heweliusza z plikiem referencyjnym CSV z innego
// programu (np. ze Swiss Ephemeris; plik przygotowuje osobne narzędzie,
// poza tym pakietem). Sam pakiet nie korzysta z innych silników
// efemeryd – czyta tylko gotowe liczby.
//
//   dart run tool/compare_reference.dart <plik.csv>
import 'dart:io';
import 'dart:math' as math;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';

const _names = {
  10: 'Słońce',
  301: 'Księżyc',
  1: 'Merkury',
  2: 'Wenus',
  4: 'Mars',
  5: 'Jowisz',
  6: 'Saturn',
  7: 'Uran',
  8: 'Neptun',
  9: 'Pluton',
  2002060: 'Chiron',
  2000001: 'Ceres',
  2000002: 'Pallas',
  2000003: 'Juno',
  2000004: 'Westa',
};

/// Najgorszy przypadek i średnia kwadratowa (w sekundach łuku).
class _Stats {
  var max = 0.0, sumSq = 0.0, n = 0;
  double atJd = 0;

  void add(double v, double jd) {
    if (v.abs() > max.abs()) {
      max = v;
      atJd = jd;
    }
    sumSq += v * v;
    n++;
  }

  String get text =>
      'maks ${max.toStringAsFixed(4).padLeft(8)}″  '
      'średnio ${math.sqrt(sumSq / n).toStringAsFixed(4)}″';
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Użycie: dart run tool/compare_reference.dart <plik.csv>');
    exit(64);
  }
  final eph = SpkEphemeris([
    for (final name in ['de440s.bsp', 'small_bodies.bsp'])
      if (File('data/jpl/$name').existsSync())
        SpkFile.fromBytes(File('data/jpl/$name').readAsBytesSync()),
  ]);
  final lon = <int, _Stats>{}, lat = <int, _Stats>{};
  final app = <int, _Stats>{}, ast = <int, _Stats>{};
  final speed = <int, _Stats>{};
  final pointLon = <String, _Stats>{}, pointLat = <String, _Stats>{};
  final pointSpeed = <String, _Stats>{};
  final deltaTStats = _Stats();
  final armcStats = _Stats(), obliquityStats = _Stats();
  final ascAll = _Stats(), ascGeometry = _Stats();
  final mcAll = _Stats(), mcGeometry = _Stats();
  var dates = 0;

  for (final line in File(args.single).readAsLinesSync()) {
    if (line.startsWith('#') || line.startsWith('kind')) continue;
    final p = line.split(',');
    final jd = double.parse(p[1]);
    if (p[0] == 'deltat') {
      deltaTStats.add(deltaT(jd) - double.parse(p[3]), jd);
      dates++;
      continue;
    }
    if (p[0] == 'houses') {
      // Wiersz domów: tu tylko osie (wierzchołki domów nie należą do
      // tego pakietu). Za kołem podbiegunowym Swiss Ephemeris w systemach
      // Regiomontanusa i Campanusa podaje jako MC wierzchołek domu 10,
      // który bywa wtedy IC, więc MC bierzemy tylko z innych systemów.
      final [lat, lon, armc, obliquity, asc, mc, ...] = p
          .skip(3)
          .map(double.parse)
          .toList();
      // Całość (czas gwiazdowy + geometria) i sama geometria – z ARMC
      // i nachyleniem ze Swiss Ephemeris.
      final ours = angles(jd, lat, lon);
      final geometry = anglesFromArmc(armc, lat, obliquity);
      armcStats.add(_dLon(ours.armc, armc), jd);
      final t = centuriesSinceJ2000(julianDayTT(jd));
      obliquityStats.add(
        (trueObliquity(t) * 180 / math.pi - obliquity) * 3600,
        jd,
      );
      ascAll.add(_dLon(ours.ascendant, asc), jd);
      ascGeometry.add(_dLon(geometry.ascendant, asc), jd);
      if (p[2] != 'regiomontanus' && p[2] != 'campanus') {
        mcAll.add(_dLon(ours.midheaven, mc), jd);
        mcGeometry.add(_dLon(geometry.midheaven, mc), jd);
      }
      continue;
    }
    if (p[0] == 'point') {
      final point = LunarPoint.values.byName(p[2]);
      final ours = lunarPoint(eph, point, jd);
      pointLon
          .putIfAbsent(p[2], _Stats.new)
          .add(_dLon(ours.longitude, double.parse(p[3])), jd);
      pointLat
          .putIfAbsent(p[2], _Stats.new)
          .add((ours.latitude - double.parse(p[4])) * 3600, jd);
      final v = longitudeSpeed((j) => lunarPoint(eph, point, j).longitude, jd);
      pointSpeed
          .putIfAbsent(p[2], _Stats.new)
          .add((v - double.parse(p[9])) * 3600, jd);
      continue;
    }
    final naif = int.parse(p[2]);
    final v = p.skip(3).map(double.parse).toList();

    final ecl = geocentricEcliptic(eph, naif, jd);
    lon.putIfAbsent(naif, _Stats.new).add(_dLon(ecl.longitude, v[0]), jd);
    lat.putIfAbsent(naif, _Stats.new).add((ecl.latitude - v[1]) * 3600, jd);

    final apparent = geocentricDirection(eph, naif, jd).direction;
    app.putIfAbsent(naif, _Stats.new).add(_sep(apparent, v[2], v[3]), jd);

    final astrometric = geocentricDirection(
      eph,
      naif,
      jd,
      corrections: const Corrections(
        deflection: false,
        aberration: false,
        nutation: false,
      ),
    ).direction;
    ast.putIfAbsent(naif, _Stats.new).add(_sep(astrometric, v[4], v[5]), jd);

    if (v.length > 6) {
      final ours = longitudeSpeed(
        (j) => geocentricEcliptic(eph, naif, j).longitude,
        jd,
      );
      speed.putIfAbsent(naif, _Stats.new).add((ours - v[6]) * 3600, jd);
    }
  }

  print('Porównanie z ${args.single}: $dates dat\n');
  void table(String title, Map<Object, _Stats> stats) {
    if (stats.isEmpty) return;
    print(title);
    for (final MapEntry(key: key, value: s) in stats.entries) {
      print('  ${(_names[key] ?? '$key').padRight(16)} ${s.text}');
    }
    print('');
  }

  table('Astrometryczne ICRS (dane + czas światła), odległość kątowa:', ast);
  table('Pozorne ICRS (+ ugięcie, aberracja), odległość kątowa:', app);
  table('Pozorne na ekliptyce daty – długość λ (Hevelius − wzorzec):', lon);
  table('Pozorne na ekliptyce daty – szerokość β:', lat);
  table('Prędkość w długości (″/dobę):', speed);
  table('Węzły i Lilith – długość λ:', pointLon);
  table('Węzły i Lilith – szerokość β:', pointLat);
  table('Węzły i Lilith – prędkość (″/dobę):', pointSpeed);
  table('ASC i MC – całość / sama geometria (ARMC i ε ze wzorca):', {
    'ASC': ascAll,
    'ASC, geometria': ascGeometry,
    'MC': mcAll,
    'MC, geometria': mcGeometry,
  });
  if (armcStats.n > 0) {
    print('ARMC: ${armcStats.text}');
    print('Prawdziwe nachylenie ekliptyki: ${obliquityStats.text}\n');
  }
  print(
    'ΔT (Hevelius − wzorzec): maks ${deltaTStats.max.toStringAsFixed(3)} s '
    '(${calendarDateTime(deltaTStats.atJd).year} r.), średnio '
    '${math.sqrt(deltaTStats.sumSq / deltaTStats.n).toStringAsFixed(3)} s',
  );
}

double _dLon(double a, double b) {
  var d = (a - b) % 360;
  if (d > 180) d -= 360;
  return d * 3600;
}

/// Odległość kątowa (″) między wektorem [u] a kierunkiem (ra, dec) w °.
double _sep(Vector3 u, double ra, double dec) {
  const deg = math.pi / 180;
  final v = Vector3(
    math.cos(dec * deg) * math.cos(ra * deg),
    math.cos(dec * deg) * math.sin(ra * deg),
    math.sin(dec * deg),
  );
  return 2 * math.asin((u.unit - v).length / 2) / deg * 3600;
}
