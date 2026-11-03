// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Pobiera pliki JPL potrzebne do testów pakietu (data/jpl/) – korzysta
// z programu bin/download_jpl.dart.
//
//   dart run tool/download_jpl.dart            # DE440s, DE440, DE442 i pliki kontrolne
//   dart run tool/download_jpl.dart --de441    # dodatkowo DE441 (3,3 GB, −13200…+17191)
import 'dart:io';

import '../bin/download_jpl.dart' as jpl;

Future<void> main(List<String> args) async {
  final unknown = args.where((a) => a != '--de441');
  if (unknown.isNotEmpty) {
    stderr.writeln('Nieznana opcja: ${unknown.join(' ')} (jest tylko --de441)');
    exit(64);
  }
  final ok = await jpl.download([
    'de440s.bsp',
    'de440.bsp',
    'testpo.440',
    'de442.bsp',
    'testpo.442',
    if (args.contains('--de441')) ...['de441.bsp', 'testpo.441'],
  ], 'data/jpl');
  if (!ok) exit(1);
}
