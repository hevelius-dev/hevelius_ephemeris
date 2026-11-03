// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Buduje plik data/jpl/small_bodies.bsp z położeniami planetoid i centaurów
// pobranymi z NASA JPL Horizons.
//
//   dart run tool/build_small_bodies.dart
//
// Horizons podaje położenia i prędkości względem barycentrum Układu
// Słonecznego (ICRF, TDB) co dobę; dopasowujemy do nich wielomiany
// Czebyszewa w przedziałach 32-dobowych i zapisujemy jako segmenty SPK
// typu 2. Odpowiedzi Horizons zapisywane są w data/horizons/ i przy
// ponownym uruchomieniu nie są pobierane drugi raz.
import 'dart:io';
import 'dart:math' as math;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';

/// Planetoidy (numer, nazwa). Kod NAIF to 2 000 000 + numer.
const bodies = [
  (2060, 'Chiron'),
  (1, 'Ceres'),
  (2, 'Pallas'),
  (3, 'Juno'),
  (4, 'Vesta'),
];

/// Zakres: 1.01.1600 – 18.01.2500 (TDB). Horizons podaje planetoidy
/// tylko od 11.12.1599 do 1.01.2501 (sprawdzone 2026-10-30).
const startJd = 2305447.5;
const intervalDays = 32;
const intervals = 10273; // 10273 × 32 dni ≈ 900 lat
const degree = 12;
const chunkDays = 16384; // dni na jedno zapytanie do Horizons

Future<void> main() async {
  Directory('data/horizons').createSync(recursive: true);
  final segments = <SpkType2Segment>[];
  for (final (number, name) in bodies) {
    final samples = await _samples(number);
    final (records, check) = _fit(samples);
    print(
      '$name: ${records.length} przedziałów; kontrola (dopasowanie do dni '
      'parzystych, błąd w nieparzystych): maks ${check.toStringAsFixed(3)} '
      'km',
    );
    segments.add(
      SpkType2Segment(
        name: '$name (JPL Horizons)',
        target: 2000000 + number,
        center: Naif.solarSystemBarycenter,
        startEt: (startJd - j2000) * 86400,
        intervalLength: intervalDays * 86400.0,
        records: records,
      ),
    );
  }
  final out = File('data/jpl/small_bodies.bsp')
    ..writeAsBytesSync(
      writeSpk('Hevelius: planetoidy z JPL Horizons', segments),
    );
  print('Zapisano ${out.path} (${out.lengthSync() ~/ 1024} KB)');
}

/// Położenia (km) co dobę od [startJd]: lista (x, y, z).
Future<List<(double, double, double)>> _samples(int number) async {
  final all = <(double, double, double)>[];
  final totalDays = intervals * intervalDays;
  for (var from = 0; from <= totalDays; from += chunkDays) {
    final to = math.min(from + chunkDays - 1, totalDays);
    final cache = File(
      'data/horizons/${number}_${(startJd + from).toStringAsFixed(1)}'
      '_${(startJd + to).toStringAsFixed(1)}.txt',
    );
    if (!cache.existsSync()) {
      stdout.write('  Horizons: $number, dni $from–$to … ');
      cache.writeAsStringSync(
        await _fetch(number, startJd + from, startJd + to),
      );
      print('OK');
    }
    final text = cache.readAsStringSync();
    final start = text.indexOf(r'$$SOE'), end = text.indexOf(r'$$EOE');
    if (start < 0 || end < 0) {
      cache.deleteSync();
      throw StateError('Nieoczekiwana odpowiedź Horizons dla $number:\n$text');
    }
    final lines = text
        .substring(start + 5, end)
        .trim()
        .split('\n')
        .map((l) => l.split(',').map((v) => v.trim()).toList());
    var expected = startJd + from;
    for (final p in lines) {
      if (double.parse(p[0]) != expected) {
        throw StateError('Brak doby $expected w danych dla $number');
      }
      all.add((double.parse(p[2]), double.parse(p[3]), double.parse(p[4])));
      expected++;
    }
  }
  return all;
}

Future<String> _fetch(int number, double fromJd, double toJd) async {
  final uri = Uri.https('ssd.jpl.nasa.gov', '/api/horizons.api', {
    'format': 'text',
    'COMMAND': "'$number;'",
    'OBJ_DATA': "'NO'",
    'EPHEM_TYPE': "'VECTORS'",
    'CENTER': "'500@0'",
    'REF_PLANE': "'FRAME'",
    'REF_SYSTEM': "'ICRF'",
    'VEC_TABLE': "'2'",
    'OUT_UNITS': "'KM-S'",
    'CSV_FORMAT': "'YES'",
    'VEC_LABELS': "'NO'",
    'TIME_TYPE': "'TDB'",
    'START_TIME': "'JD $fromJd'",
    'STOP_TIME': "'JD $toJd'",
    'STEP_SIZE': "'1 d'",
  });
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(uri)).close();
    final body = await response
        .transform(const SystemEncoding().decoder)
        .join();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}: $body', uri: uri);
    }
    return body;
  } finally {
    client.close();
  }
}

/// Współczynniki dla każdego przedziału oraz największy błąd kontroli (km).
(List<(List<double>, List<double>, List<double>)>, double) _fit(
  List<(double, double, double)> samples,
) {
  final records = <(List<double>, List<double>, List<double>)>[];
  var worst = 0.0;
  for (var i = 0; i < intervals; i++) {
    final base = i * intervalDays;
    List<double> coordinate(int axis, {required bool evenOnly}) {
      final points = <double>[], values = <double>[];
      for (var d = 0; d <= intervalDays; d += evenOnly ? 2 : 1) {
        final (x, y, z) = samples[base + d];
        points.add(-1 + 2 * d / intervalDays);
        values.add([x, y, z][axis]);
      }
      return fitChebyshev(points, values, degree);
    }

    // Kontrola: dopasowanie tylko do dób parzystych, błąd w nieparzystych.
    final check = [for (var a = 0; a < 3; a++) coordinate(a, evenOnly: true)];
    for (var d = 1; d < intervalDays; d += 2) {
      final (x, y, z) = samples[base + d];
      final s = -1 + 2 * d / intervalDays;
      final dx = evaluateChebyshev(check[0], s) - x;
      final dy = evaluateChebyshev(check[1], s) - y;
      final dz = evaluateChebyshev(check[2], s) - z;
      worst = math.max(worst, math.sqrt(dx * dx + dy * dy + dz * dz));
    }
    records.add((
      coordinate(0, evenOnly: false),
      coordinate(1, evenOnly: false),
      coordinate(2, evenOnly: false),
    ));
  }
  return (records, worst);
}
