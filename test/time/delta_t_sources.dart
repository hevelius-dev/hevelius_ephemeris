// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Odczyt surowych plików ΔT z data/delta_t/; używany przez generator
// (tool/generate_delta_t.dart) i przez test sprawdzający, że wygenerowany
// plik jest aktualny. Nie jest częścią biblioteki.
import 'dart:io';

/// Wiersze tabeli S15.2020: (K_i, K_i+1, a0, a1, a2, a3).
List<(double, double, double, double, double, double)> readSplineTable(
  File file,
) {
  final rows = <(double, double, double, double, double, double)>[];
  for (final line in file.readAsLinesSync()) {
    final p = line.trim().split(RegExp(r'\s+'));
    // Wiersz danych: numer, dwa lata i cztery współczynniki.
    if (p.length != 7 || int.tryParse(p[0]) == null) continue;
    final v = p.skip(1).map(double.parse).toList();
    rows.add((v[0], v[1], v[2], v[3], v[4], v[5]));
  }
  return rows;
}

/// Wiersze deltat.data z USNO: (rok, miesiąc, ΔT).
List<(int, int, double)> readUsnoMonthly(File file) => [
  for (final line in file.readAsLinesSync())
    if (line.trim().isNotEmpty)
      () {
        final p = line.trim().split(RegExp(r'\s+'));
        if (p[2] != '1') throw FormatException('Oczekiwano 1. dnia: $line');
        return (int.parse(p[0]), int.parse(p[1]), double.parse(p[3]));
      }(),
];
