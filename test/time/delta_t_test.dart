// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:hevelius_ephemeris/src/time/delta_t_data.dart';
import 'package:test/test.dart';

import 'delta_t_sources.dart';

/// Dzień juliański dla roku z ułamkiem (jak w implementacji).
double jdOfYear(double year) => j2000 + (year - 2000) * 365.25;

void main() {
  group('dane', () {
    test('wygenerowany plik zgadza się z plikami źródłowymi', () {
      // Gdy test pada: dart run tool/generate_delta_t.dart
      expect(
        deltaTSpline,
        readSplineTable(File('data/delta_t/Table-S15.2020.txt')),
      );
      expect(deltaTMonthly, readUsnoMonthly(File('data/delta_t/deltat.data')));
    });

    test('kolejne przedziały spline łączą się bez skoku', () {
      for (var i = 0; i + 1 < deltaTSpline.length; i++) {
        final (_, to, a0, a1, a2, a3) = deltaTSpline[i];
        final next = deltaTSpline[i + 1];
        expect(next.$1, to);
        // Współczynniki są zaokrąglone do 0,001 s.
        expect(a0 + a1 + a2 + a3, closeTo(next.$3, 0.002), reason: '$to');
      }
    });

    test('pomiary USNO to kolejne miesiące bez przerw', () {
      for (var i = 0; i + 1 < deltaTMonthly.length; i++) {
        final (y, m, _) = deltaTMonthly[i];
        final (ny, nm, _) = deltaTMonthly[i + 1];
        expect(ny * 12 + nm, y * 12 + m + 1, reason: '$y-$m');
      }
    });
  });

  group('deltaT', () {
    test('w pomiarach: dokładnie wartość USNO', () {
      expect(deltaT(julianDay(2000, 1, 1)), 63.8285);
      expect(deltaT(julianDay(1978, 6, 1)), closeTo(48.9, 0.5));
    });

    test('między pomiarami: interpolacja liniowa', () {
      final a = deltaT(julianDay(2000, 1, 1));
      final b = deltaT(julianDay(2000, 2, 1));
      final mid = (julianDay(2000, 1, 1) + julianDay(2000, 2, 1)) / 2;
      expect(deltaT(mid), closeTo((a + b) / 2, 1e-12));
    });

    test('w spline: wartości z tabeli na granicach przedziałów', () {
      expect(deltaT(jdOfYear(-720)), closeTo(20371.848, 1e-6));
      expect(deltaT(jdOfYear(1000)), closeTo(1650.393, 1e-6));
      expect(deltaT(jdOfYear(1900)), closeTo(-1.977, 1e-6));
    });

    /// Tempo zmian ΔT (s/rok) wokół dnia juliańskiego [jd].
    double rate(double jd, {double h = 1}) =>
        (deltaT(jd + h) - deltaT(jd - h)) / (2 * h) * 365.25;

    test('przed rokiem −720: ciągła wartość i tempo zmian', () {
      final edge = jdOfYear(-720);
      expect(deltaT(edge - 1e-3), closeTo(deltaT(edge), 0.01));
      final before = (deltaT(edge) - deltaT(edge - 365.25)) / 1;
      final after = (deltaT(edge + 365.25) - deltaT(edge)) / 1;
      expect(before, closeTo(after, 0.1));
      // Daleko w przeszłości dominuje parabola 32,5·u².
      final y = -13000.0, u = (y - 1825) / 100;
      expect(deltaT(jdOfYear(y)) / (32.5 * u * u), closeTo(1, 0.01));
    });

    test('po ostatnim pomiarze: ciągła wartość i tempo zmian', () {
      final last = deltaTMonthly.last;
      final edge = julianDay(last.$1, last.$2, 1);
      expect(deltaT(edge), last.$3);
      expect(deltaT(edge + 1e-3), closeTo(last.$3, 0.01));
      // Tempo tuż po ostatnim pomiarze = średnie z ostatnich 2 lat.
      final measured =
          (last.$3 - deltaTMonthly[deltaTMonthly.length - 25].$3) / 2;
      expect(rate(edge + 2), closeTo(measured, 0.02));
    });

    test('przyszłość: łagodny wzrost, bez skoków', () {
      // Prognoza, nie pomiar – tylko rozsądne granice.
      expect(deltaT(jdOfYear(2050)), inInclusiveRange(69, 85));
      expect(deltaT(jdOfYear(2100)), inInclusiveRange(75, 120));
      for (var y = 2027.0; y < 2150; y += 1) {
        expect(rate(jdOfYear(y), h: 30), inInclusiveRange(0, 2));
      }
    });

    test('na styku spline i pomiarów (1973) skok poniżej 0,3 s', () {
      final edge = julianDay(1973, 2, 1);
      expect((deltaT(edge) - deltaT(edge - 1e-6)).abs(), lessThan(0.3));
    });

    test('spline zgadza się z pomiarami USNO 1973–2019 do 0,3 s', () {
      for (final (y, m, dt) in deltaTMonthly) {
        if (y >= 2019) break;
        final year = y + (m - 1) / 12;
        double spline(double year) {
          for (final (from, to, a0, a1, a2, a3) in deltaTSpline) {
            if (year < to) {
              final t = (year - from) / (to - from);
              return a0 + t * (a1 + t * (a2 + t * a3));
            }
          }
          throw StateError('$year');
        }

        expect(spline(year), closeTo(dt, 0.3), reason: '$y-$m');
      }
    });
  });

  group('UT ↔ TT', () {
    test('TT = UT + ΔT', () {
      final ut = julianDay(2000, 1, 1);
      expect(julianDayTT(ut), ut + 63.8285 / 86400);
    });

    test('własna wartość ΔT', () {
      final ut = julianDay(1000, 1, 1);
      expect(julianDayTT(ut, deltaTSeconds: 1500), ut + 1500 / 86400);
      expect(julianDayUT(ut + 1500 / 86400, deltaTSeconds: 1500), ut);
    });

    test('tam i z powrotem od −13000 do +17000', () {
      for (var y = -13000.0; y <= 17000; y += 250) {
        final ut = jdOfYear(y);
        expect(julianDayUT(julianDayTT(ut)), closeTo(ut, 1e-9), reason: '$y');
      }
    });
  });
}
