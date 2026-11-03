// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

void main() {
  test('dopasowanie Czebyszewa odtwarza wielomian dokładnie', () {
    // f(s) = 3 − 2s + 0,5·T₃(s): stopień 3 musi wyjść bezbłędnie.
    double f(double s) => 3 - 2 * s + 0.5 * (4 * s * s * s - 3 * s);
    final points = [for (var k = 0; k <= 10; k++) -1 + k / 5];
    final c = fitChebyshev(points, [for (final s in points) f(s)], 3);
    expect(c[0], closeTo(3, 1e-12));
    expect(c[1], closeTo(-2, 1e-12));
    expect(c[2], closeTo(0, 1e-12));
    expect(c[3], closeTo(0.5, 1e-12));
  });

  test('zapisany plik SPK czyta się z powrotem (ruch po okręgu)', () {
    // Ciało krąży po okręgu o promieniu 1e8 km z okresem 365,25 doby.
    const r = 1e8, period = 365.25 * 86400, interval = 16 * 86400.0;
    const start = -10 * 86400.0;
    Vector3 at(double et) {
      final a = 2 * math.pi * et / period;
      return Vector3(r * math.cos(a), r * math.sin(a), 0.1 * r * math.sin(a));
    }

    final records = <(List<double>, List<double>, List<double>)>[];
    for (var i = 0; i < 40; i++) {
      final points = <double>[], xs = <double>[], ys = <double>[];
      final zs = <double>[];
      for (var k = 0; k <= 32; k++) {
        final s = -1 + k / 16;
        final p = at(start + i * interval + (s + 1) / 2 * interval);
        points.add(s);
        xs.add(p.x);
        ys.add(p.y);
        zs.add(p.z);
      }
      records.add((
        fitChebyshev(points, xs, 12),
        fitChebyshev(points, ys, 12),
        fitChebyshev(points, zs, 12),
      ));
    }
    final bytes = writeSpk('test hevelius', [
      SpkType2Segment(
        name: 'okrag',
        target: 2000001,
        center: 0,
        startEt: start,
        intervalLength: interval,
        records: records,
      ),
    ]);

    final spk = SpkFile.fromBytes(bytes);
    expect(spk.internalName, 'test hevelius');
    expect(spk.segments.single.target, 2000001);
    expect(spk.segments.single.name, 'okrag');
    final eph = SpkEphemeris([spk]);
    for (var et = start; et < start + 40 * interval; et += 7777) {
      final s = eph.state(2000001, 0, et);
      expect((s.position - at(et)).length, lessThan(1e-3)); // < 1 m
      // Prędkość z pochodnej: v = 2πr/T.
      expect(s.velocity.length, closeTo(2 * math.pi * r / period, 0.1));
    }
  });
}
