// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math';

import 'package:hevelius_ephemeris/spk_io.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';

void main() {
  for (final (name, inMemory, tool) in [
    ('de440.bsp', () => de440, 'download_jpl.dart'),
    ('small_bodies.bsp', () => smallBodies, 'build_small_bodies.dart'),
  ]) {
    test('$name z dysku: ten sam spis i te same liczby co z pamięci', () {
      final memory = inMemory();
      final disk = openSpkFile(jplFile(name, tool: tool).path);
      expect(disk.internalName, memory.internalName);
      expect(
        [for (final s in disk.segments) s.toString()],
        [for (final s in memory.segments) s.toString()],
      );

      final random = Random(1661);
      for (var i = 0; i < disk.segments.length; i++) {
        final a = memory.segments[i], b = disk.segments[i];
        for (var k = 0; k < 50; k++) {
          final et = a.startEt + random.nextDouble() * (a.endEt - a.startEt);
          final x = a.state(et), y = b.state(et);
          expect(
            [y.x, y.y, y.z, y.vx, y.vy, y.vz],
            [x.x, x.y, x.z, x.vx, x.vy, x.vz],
            reason: '$a, et $et',
          );
        }
      }
    });
  }

  test('ostatnio użyty rekord nie psuje wyników przy skokach w czasie', () {
    final disk = openSpkFile(jplFile('de440.bsp').path);
    final moon = disk.segments.firstWhere((s) => s.target == 301);
    final reference = de440.segments.firstWhere((s) => s.target == 301);
    // Na przemian dwie odległe chwile i ta sama chwila dwa razy.
    for (final et in [0.0, 1e9, 1e9, 0.0, -1e10, 0.0]) {
      expect(moon.state(et).x, reference.state(et).x);
    }
  });
}
