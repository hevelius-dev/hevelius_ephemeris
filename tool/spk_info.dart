// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Wypisuje zawartość pliku SPK: nazwę i listę segmentów.
//
//   dart run tool/spk_info.dart data/jpl/de440s.bsp
import 'dart:io';

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';

const _names = {
  0: 'barycentrum Układu Słonecznego',
  1: 'barycentrum Merkurego',
  2: 'barycentrum Wenus',
  3: 'barycentrum Ziemia–Księżyc',
  4: 'barycentrum Marsa',
  5: 'barycentrum Jowisza',
  6: 'barycentrum Saturna',
  7: 'barycentrum Urana',
  8: 'barycentrum Neptuna',
  9: 'barycentrum Plutona',
  10: 'Słońce',
  199: 'Merkury',
  299: 'Wenus',
  301: 'Księżyc',
  399: 'Ziemia',
  1000000001: 'TT−TDB',
  1000000000: '(geocentrum czasu)',
};

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Użycie: dart run tool/spk_info.dart <plik.bsp>');
    exit(64);
  }
  final spk = SpkFile.fromBytes(File(args.single).readAsBytesSync());
  print('Plik: ${spk.internalName}');
  print('Segmenty: ${spk.segments.length}');
  for (final s in spk.segments) {
    final from = calendarDateTime(j2000 + s.startEt / 86400);
    final to = calendarDateTime(j2000 + s.endEt / 86400);
    final target = _names[s.target] ?? '${s.target}';
    final center = _names[s.center] ?? '${s.center}';
    print(
      '  ${'${s.target}'.padLeft(4)} → ${'${s.center}'.padLeft(3)}  '
      'typ ${s.dataType}  układ ${s.frame}  '
      '${from.year}-${from.month}-${from.day} … '
      '${to.year}-${to.month}-${to.day}  '
      '$target względem: $center  '
      '(${(s.endWord - s.beginWord + 1) * 8 ~/ 1024} KB)',
    );
  }
}
