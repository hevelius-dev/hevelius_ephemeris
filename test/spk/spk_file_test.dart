// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';

void main() {
  test('de440s: 14 segmentów drzewa ciał', () {
    final pairs = {for (final s in de440s.segments) (s.target, s.center)};
    expect(pairs, {
      for (var b = 1; b <= 10; b++) (b, 0),
      (301, 3),
      (399, 3),
      (199, 1),
      (299, 2),
    });
  });

  test('de440s: wielomiany Czebyszewa w układzie J2000, lata 1850–2150', () {
    final from = julianDay(1850, 1, 1), to = julianDay(2150, 1, 1);
    for (final s in de440s.segments) {
      expect(s.dataType, 2);
      expect(s.frame, 1);
      expect(j2000 + s.startEt / 86400, lessThan(from));
      expect(j2000 + s.endEt / 86400, greaterThan(to));
      expect(s.endWord, greaterThan(s.beginWord));
    }
  });

  test('covers: dane dla całego łańcucha ciał, poza zakresem – nie', () {
    final eph = SpkEphemeris([de440s]);
    double et(int year) => (julianDay(year, 1, 1) - j2000) * 86400;
    expect(eph.covers(Naif.moon, et(2000)), isTrue);
    expect(eph.covers(Naif.moon, et(1800)), isFalse);
    expect(eph.covers(2002060, et(2000)), isFalse); // Chirona nie ma w de440s
    expect(
      () => eph.state(Naif.moon, Naif.earth, et(1800)),
      throwsArgumentError,
    );
  });

  test('odrzuca plik, który nie jest SPK', () {
    expect(
      () => SpkFile.fromBytes(Uint8List(2048)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => SpkFile.fromBytes(Uint8List(10)),
      throwsA(isA<FormatException>()),
    );
  });
}
