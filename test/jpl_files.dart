// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Dostęp do plików NASA w testach. Gdy pliku brak, test pada z instrukcją
// – nie pomijamy go po cichu.
import 'dart:io';

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';

File jplFile(String name, {String tool = 'download_jpl.dart'}) {
  final file = File('data/jpl/$name');
  if (!file.existsSync()) {
    throw StateError('Brak ${file.path} – uruchom: dart run tool/$tool');
  }
  return file;
}

final SpkFile de440s = SpkFile.fromBytes(
  jplFile('de440s.bsp').readAsBytesSync(),
);

/// Pełna efemeryda DE440, 1550–2650.
final SpkFile de440 = SpkFile.fromBytes(jplFile('de440.bsp').readAsBytesSync());

/// Planetoidy z JPL Horizons (zob. tool/build_small_bodies.dart).
final SpkFile smallBodies = SpkFile.fromBytes(
  jplFile(
    'small_bodies.bsp',
    tool: 'build_small_bodies.dart',
  ).readAsBytesSync(),
);
