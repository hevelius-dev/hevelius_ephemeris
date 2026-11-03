// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Generuje lib/src/reduction/nutation_data.dart z tabel IERS w data/iers/.
//
//   dart run tool/generate_nutation.dart
import 'dart:io';

import '../test/reduction/nutation_sources.dart';

void main() {
  final longitude = readNutationTable(File('data/iers/tab5.3a.txt'));
  final obliquity = readNutationTable(File('data/iers/tab5.3b.txt'));
  final equinoxes = readNutationTable(File('data/iers/tab5.2e.txt'));

  final out = StringBuffer()
    ..writeln('// WYGENEROWANE przez tool/generate_nutation.dart – nie edytuj.')
    ..writeln('// Źródło: IERS Conventions (2010), tabele 5.3a, 5.3b i 5.2e')
    ..writeln('// (zob. SOURCES.md).')
    ..writeln()
    ..writeln('// Po 17 liczb na wyraz: potęga t, współczynnik przy sinusie')
    ..writeln('// i przy cosinusie (0,01 µas), 14 mnożników argumentów.')
    ..writeln();
  void table(String name, String doc, List<int> data) {
    out
      ..writeln('/// $doc')
      ..writeln('const $name = <int>[');
    for (var i = 0; i < data.length; i += 17) {
      out.writeln('  ${data.sublist(i, i + 17).join(', ')},');
    }
    out.writeln('];');
  }

  table(
    'nutationInLongitude',
    'Nutacja w długości Δψ (tabela 5.3a).',
    longitude,
  );
  out.writeln();
  table(
    'nutationInObliquity',
    'Nutacja w nachyleniu Δε (tabela 5.3b).',
    obliquity,
  );
  out.writeln();
  table(
    'equationOfEquinoxesTerms',
    'Wyrazy uzupełniające równania równonocy (tabela 5.2e).',
    equinoxes,
  );

  const path = 'lib/src/reduction/nutation_data.dart';
  File(path).writeAsStringSync(out.toString());
  print(
    'Zapisano $path: ${longitude.length ~/ 17} wyrazów Δψ, '
    '${obliquity.length ~/ 17} wyrazów Δε, '
    '${equinoxes.length ~/ 17} wyrazów równania równonocy.',
  );
}
