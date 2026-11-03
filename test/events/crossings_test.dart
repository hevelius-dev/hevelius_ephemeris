// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';

void main() {
  final eph = SpkEphemeris([de440s]);
  final year2026 = (
    julianDayTT(julianDay(2026, 1, 1)),
    julianDayTT(julianDay(2027, 1, 1)),
  );

  /// Liczba przejść przez granice co [period]° przy próbkowaniu co
  /// [dt] dób – niezależne sprawdzenie, że algorytm niczego nie gubi.
  int bruteForce(
    LongitudeFunction f,
    double a,
    double b, {
    double period = 30,
    double dt = 0.01,
  }) {
    var n = 0;
    var prev = f(a) ~/ period;
    for (var t = a + dt; t <= b; t += dt) {
      final k = f(t) ~/ period;
      if (k != prev) n++;
      prev = k;
    }
    return n;
  }

  group('równonoce i przesilenia', () {
    test('przesilenie czerwcowe 1962: 21h24m42s TD (Meeus, przykład 27.a)', () {
      // Meeus podaje wynik pełnej teorii VSOP87 z poprawką do układu FK5;
      // DE440 w układzie ICRS różni się o ok. 0,1″ w długości Słońca,
      // czyli o ok. 3 s (1″ ≈ 24 s).
      final jd = seasons(eph, 1962)[Season.juneSolstice]!;
      final expected = julianDay(1962, 6, 21, hour: 21, minute: 24, second: 42);
      expect((jd - expected) * 86400, closeTo(0, 5));
    });

    test('cztery pory roku, Słońce dokładnie w 0°, 90°, 180°, 270°', () {
      final s = seasons(eph, 2026);
      expect(s.keys, Season.values);
      final sun = bodyLongitude(eph, Naif.sun);
      for (final MapEntry(key: season, value: jd) in s.entries) {
        final target = season.index * 90.0;
        var d = (sun(jd) - target) % 360;
        if (d > 180) d -= 360;
        expect(d.abs(), lessThan(1e-6), reason: '$season');
      }
      // Wiosna w marcu, zima w grudniu.
      expect(calendarDateTime(s[Season.marchEquinox]!).month, 3);
      expect(calendarDateTime(s[Season.decemberSolstice]!).month, 12);
    });
  });

  group('ingresy', () {
    test('Merkury 2026: tyle samo co przy próbkowaniu, także wstecz', () {
      final merc = bodyLongitude(eph, 1);
      final (a, b) = year2026;
      final found = ingresses(merc, a, b);
      expect(found, hasLength(bruteForce(merc, a, b)));
      for (final i in found) {
        // W chwili ingresu długość jest na granicy znaku…
        final boundary = (i.sign + (i.retrograde ? 1 : 0)) * 30.0;
        var d = (merc(i.jdTT) - boundary) % 360;
        if (d > 180) d -= 360;
        expect(d.abs(), lessThan(1e-6));
        // …a chwilę później ciało jest już w znaku [sign].
        expect(merc(i.jdTT + 0.01) ~/ 30, i.sign);
      }
      // Kolejność czasowa.
      for (var k = 1; k < found.length; k++) {
        expect(found[k].jdTT, greaterThan(found[k - 1].jdTT));
      }
    });

    test('Księżyc 2026: ok. 13 ingresów na miesiąc, żaden nie zgubiony', () {
      final moon = bodyLongitude(eph, Naif.moon);
      final (a, b) = year2026;
      final found = ingresses(moon, a, b);
      expect(found, hasLength(bruteForce(moon, a, b)));
      expect(found.where((i) => i.retrograde), isEmpty);
      expect(found.length, inInclusiveRange(160, 165));
    });

    test('węzeł prawdziwy: wejście do Wodnika w lipcu 2026', () {
      // Węzeł prawdziwy waha się wokół średniego i bywa chwilami prosty,
      // więc przy granicy znaku może ją przekroczyć więcej niż raz –
      // próbkowanie co 0,01 doby sprawdza, że nic nie zginęło.
      double node(double t) =>
          lunarPoint(eph, LunarPoint.trueNode, t).longitude;
      final a = julianDayTT(julianDay(2026, 5, 1));
      final b = julianDayTT(julianDay(2026, 10, 1));
      final found = ingresses(node, a, b, step: 0.25);
      expect(found, isNotEmpty);
      expect(found.first.sign, 10);
      expect(found, hasLength(bruteForce(node, a, b)));
    });

    test('dowolna długość: Słońce w 123,4° raz w roku', () {
      final (a, b) = year2026;
      final found = longitudeCrossings(
        bodyLongitude(eph, Naif.sun),
        a,
        b,
        period: 360,
        offset: 123.4,
        step: 5,
      );
      expect(found, hasLength(1));
      expect(found.single.longitude, closeTo(123.4, 1e-9));
      expect(found.single.retrograde, isFalse);
    });
  });

  test('stacje Merkurego 2026: na przemian, prędkość ok. 0', () {
    final merc = bodyLongitude(eph, 1);
    final (a, b) = year2026;
    final found = stations(merc, a, b);
    expect(found, hasLength(6));
    for (var k = 0; k < found.length; k++) {
      expect(found[k].turnsRetrograde, k.isEven);
      expect(longitudeSpeed(merc, found[k].jdTT).abs(), lessThan(1e-4));
    }
  });
}
