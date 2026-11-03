// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Odczyt tabel nutacji IERS z data/iers/; używany przez generator
// (tool/generate_nutation.dart) i test aktualności wygenerowanego pliku.
import 'dart:io';

/// Wyrazy tabeli 5.3a lub 5.3b jako płaska lista liczb całkowitych,
/// po 17 na wyraz: potęga t (0 lub 1), współczynnik przy sinusie
/// i przy cosinusie (w 0,01 µas), 14 mnożników argumentów.
List<int> readNutationTable(File file) {
  final out = <int>[];
  var power = -1;
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.startsWith('j = ')) {
      power = int.parse(trimmed.split(RegExp(r'\s+'))[2]);
      continue;
    }
    final p = trimmed.split(RegExp(r'\s+'));
    if (p.length != 17 || int.tryParse(p[0]) == null) continue;
    if (power < 0) throw FormatException('Wyraz przed nagłówkiem j: $line');
    // Kolumny 2–3: współczynnik przy sinusie, potem przy cosinusie
    // (w 5.3a: A, A″; w 5.3b: B″, B) – z dwoma miejscami po przecinku.
    int centi(String v) => (double.parse(v) * 100).round();
    out
      ..add(power)
      ..add(centi(p[1]))
      ..add(centi(p[2]))
      ..addAll(p.skip(3).map(int.parse));
  }
  return out;
}
