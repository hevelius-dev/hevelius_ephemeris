// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Generuje lib/src/time/delta_t_data.dart z surowych plików w data/delta_t/.
//
// Uruchom z katalogu pakietu po podmianie któregoś pliku źródłowego:
//   dart run tool/generate_delta_t.dart
import 'dart:io';

import '../test/time/delta_t_sources.dart';

void main() {
  final spline = readSplineTable(File('data/delta_t/Table-S15.2020.txt'));
  final monthly = readUsnoMonthly(File('data/delta_t/deltat.data'));

  final out = StringBuffer()
    ..writeln('// WYGENEROWANE przez tool/generate_delta_t.dart – nie edytuj.')
    ..writeln('// Źródła: data/delta_t/ (zob. SOURCES.md).')
    ..writeln()
    ..writeln(
      '/// Przedziały spline ΔT (Morrison i in. 2021, tabela S15.2020):',
    )
    ..writeln('/// (od roku, do roku, a0, a1, a2, a3), ΔT w sekundach.')
    ..writeln(
      'const deltaTSpline = <(double, double, double, double, '
      'double, double)>[',
    );
  for (final r in spline) {
    out.writeln('  (${r.$1}, ${r.$2}, ${r.$3}, ${r.$4}, ${r.$5}, ${r.$6}),');
  }
  out
    ..writeln('];')
    ..writeln()
    ..writeln('/// Zmierzone ΔT (USNO), 1. dzień miesiąca, 0:00 UT:')
    ..writeln('/// (rok, miesiąc, ΔT w sekundach).')
    ..writeln('const deltaTMonthly = <(int, int, double)>[');
  for (final r in monthly) {
    out.writeln('  (${r.$1}, ${r.$2}, ${r.$3}),');
  }
  out.writeln('];');

  const path = 'lib/src/time/delta_t_data.dart';
  File(path).writeAsStringSync(out.toString());
  Process.runSync('dart', ['format', path]);
  print(
    'Zapisano $path: ${spline.length} przedziałów, '
    '${monthly.length} miesięcy '
    '(${monthly.first.$1}-${monthly.first.$2} … '
    '${monthly.last.$1}-${monthly.last.$2}).',
  );
}
