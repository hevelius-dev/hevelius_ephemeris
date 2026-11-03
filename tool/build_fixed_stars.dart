// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Buduje plik gwiazd stałych z danymi z bazy SIMBAD (CDS, Strasburg)
// dla podanej listy gwiazd.
//
//   dart run tool/build_fixed_stars.dart <lista.csv> <wynik.csv>
//
// Lista: CSV z kolumnami nazwa, oznaczenie, simbad (identyfikator
// obiektu w SIMBAD); wiersze bez identyfikatora są pomijane. Dla każdej
// gwiazdy pobieramy z SIMBAD (zapytania TAP) najlepsze wartości, jakie
// baza podaje, razem z publikacją, z której pochodzą: położenie ICRS na
// epokę J2000, ruch własny, paralaksę, prędkość radialną i jasność V.
// Odpowiedzi zapisywane są w katalogu simbad/ obok pliku wyniku i przy
// ponownym uruchomieniu nie są pobierane drugi raz.
//
// Skrypt da się uruchomić także z katalogu innego pakietu:
//
//   dart run ../hevelius_ephemeris/tool/build_fixed_stars.dart \
//       data/stars/lista.csv data/stars/gwiazdy.csv
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

/// Serwery SIMBAD: główny w Strasburgu i kopia w Harvard-Smithsonian
/// Center for Astrophysics (te same dane).
const hosts = ['simbad.cds.unistra.fr', 'simbad.harvard.edu'];

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln(
      'Użycie: dart run tool/build_fixed_stars.dart <lista.csv> <wynik.csv>',
    );
    exit(64);
  }
  final [listPath, outPath] = args;
  final cacheDir = '${File(outPath).parent.path}/simbad';
  Directory(cacheDir).createSync(recursive: true);

  final list = [
    for (final row in _readCsv(File(listPath).readAsStringSync()).skip(1))
      (name: row[0], designation: row[1], id: row[2]),
  ];

  // Zapytania po 100 identyfikatorów.
  final ids = {
    for (final s in list)
      if (s.id.isNotEmpty) s.id,
  }.toList();
  final found = <String, List<String>>{};
  var header = <String>[];
  for (var i = 0; i < ids.length; i += 100) {
    final batch = ids.sublist(i, math.min(i + 100, ids.length));
    final rows = _readCsv(await _query(_adql(batch), cacheDir));
    header = rows.first;
    for (final row in rows.skip(1)) {
      found[row[header.indexOf('id')]] = row;
    }
  }
  // Gwiazdy wielokrotne: SIMBAD pod nazwą gwiazdy podaje czasem cały
  // układ, bez ruchu własnego – wtedy bierzemy składnik A. Gdy układ ma
  // ruch własny (np. α Cen), zostaje układ: ruch środka masy jest lepszy
  // na stulecia niż chwilowy ruch składnika po orbicie.
  final systems = [
    for (final MapEntry(key: id, value: row) in found.entries)
      if (id.startsWith('* ') &&
          !RegExp(r' [AB]$').hasMatch(id) &&
          row[header.indexOf('pmra')].isEmpty)
        id,
  ];
  if (systems.isNotEmpty) {
    final rows = _readCsv(
      await _query(_adql([for (final id in systems) '$id A']), cacheDir),
    );
    for (final row in rows.skip(1)) {
      final id = row[rows.first.indexOf('id')];
      if (row[rows.first.indexOf('pmra')].isEmpty) continue;
      found[id.substring(0, id.length - 2)] = row;
      print('Układ wielokrotny – składnik A: $id');
    }
  }
  const columns = [
    'main_id',
    'otype',
    'ra',
    'dec',
    'pmra',
    'pmdec',
    'plx_value',
    'rvz_radvel',
    'V',
    'coo_bibcode',
    'pm_bibcode',
    'plx_bibcode',
    'rvz_bibcode',
  ];

  final out = StringBuffer()
    ..writeln(
      '# Gwiazdy stałe: dane z bazy SIMBAD (CDS, Strasburg), '
      'https://simbad.cds.unistra.fr/',
    )
    ..writeln(
      '# Pobrane ${DateTime.now().toIso8601String().substring(0, 10)}'
      ' przez tool/build_fixed_stars.dart (hevelius_ephemeris).',
    )
    ..writeln(
      '# "This research has made use of the SIMBAD database, CDS, '
      'Strasbourg Astronomical',
    )
    ..writeln(
      '# Observatory, France" (Wenger i in. 2000, A&AS 143, 9). '
      'Źródło: CDS/SIMBAD.',
    )
    ..writeln(
      '# ra, dec: ICRS, epoka J2000 (stopnie); pmra = μα·cos δ, '
      'pmdec (mas/rok); plx (mas); rv (km/s); v (mag);',
    )
    ..writeln('# bib_*: publikacja (bibcode ADS), z której pochodzi wartość.')
    ..writeln(
      'nazwa,oznaczenie,simbad,typ,ra,dec,pmra,pmdec,plx,rv,v,'
      'bib_coo,bib_pm,bib_plx,bib_rv',
    );
  final missing = <String>[];
  var written = 0, withoutId = 0;
  for (final s in list) {
    if (s.id.isEmpty) {
      withoutId++;
      continue;
    }
    final row = found[s.id];
    if (row == null) {
      missing.add('${s.name} (${s.designation} → ${s.id})');
      continue;
    }
    out.writeln(
      [
        s.name,
        s.designation,
        for (final c in columns) row[header.indexOf(c)],
      ].map(_csvField).join(','),
    );
    written++;
  }
  File(outPath).writeAsStringSync(out.toString());
  print(
    'Zapisano $outPath: $written z ${list.length} pozycji listy '
    '($withoutId bez identyfikatora SIMBAD – pominięte).',
  );
  if (missing.isNotEmpty) {
    print('Nie znaleziono w SIMBAD (${missing.length}):');
    for (final m in missing) {
      print('  $m');
    }
  }
}

String _adql(List<String> ids) {
  final list = ids.map((id) => "'${id.replaceAll("'", "''")}'").join(',');
  return 'SELECT i.id, b.main_id, b.otype, b.ra, b.dec, b.pmra, b.pmdec, '
      'b.plx_value, b.rvz_radvel, f.V, b.coo_bibcode, b.pm_bibcode, '
      'b.plx_bibcode, b.rvz_bibcode '
      'FROM ident AS i JOIN basic AS b ON i.oidref = b.oid '
      'LEFT JOIN allfluxes AS f ON f.oidref = b.oid '
      'WHERE i.id IN ($list)';
}

/// Odpowiedź SIMBAD (CSV) na zapytanie [adql] – z pamięci podręcznej
/// w [cacheDir] albo z sieci (kolejno serwery [hosts]).
Future<String> _query(String adql, String cacheDir) async {
  final cache = File('$cacheDir/${md5.convert(utf8.encode(adql))}.csv');
  if (cache.existsSync()) return cache.readAsStringSync();
  Object? lastError;
  for (final host in hosts) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(
        Uri.https(host, '/simbad/sim-tap/sync'),
      );
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write(
        Uri(
          queryParameters: {
            'request': 'doQuery',
            'lang': 'adql',
            'format': 'csv',
            'query': adql,
          },
        ).query,
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}: $body');
      }
      cache.writeAsStringSync(body);
      return body;
    } on IOException catch (e) {
      stderr.writeln('$host: $e');
      lastError = e;
    } finally {
      client.close(force: true);
    }
  }
  throw StateError('Żaden serwer SIMBAD nie odpowiada: $lastError');
}

String _csvField(String v) =>
    v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;

/// Prosty czytnik CSV (pola w cudzysłowach, "" jako cudzysłów); pomija
/// wiersze komentarzy zaczynające się od #.
List<List<String>> _readCsv(String text) {
  final rows = <List<String>>[];
  for (final line in const LineSplitter().convert(text)) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final fields = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (quoted) {
        if (ch == '"' && i + 1 < line.length && line[i + 1] == '"') {
          field.write('"');
          i++;
        } else if (ch == '"') {
          quoted = false;
        } else {
          field.write(ch);
        }
      } else if (ch == '"') {
        quoted = true;
      } else if (ch == ',') {
        fields.add(field.toString());
        field.clear();
      } else {
        field.write(ch);
      }
    }
    fields.add(field.toString());
    rows.add(fields);
  }
  return rows;
}
