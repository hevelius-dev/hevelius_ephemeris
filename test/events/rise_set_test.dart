// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';

void main() {
  final eph = SpkEphemeris([de440s]);

  double tt(int y, int m, int d) => julianDayTT(julianDay(y, m, d));
  double ut(HorizonEvent e) => julianDayUT(e.jdTT);

  test('Wenus nad Bostonem 20.03.1988 (Meeus, przykład 15.a)', () {
    // Boston: 42°20′ N, 71°05′ W. Meeus podaje ułamki doby z pięcioma
    // miejscami, czyli z dokładnością ok. 0,4 s.
    final events = horizonEvents(
      eph,
      Naif.venusBarycenter,
      42 + 20 / 60,
      -(71 + 5 / 60),
      tt(1988, 3, 20),
      tt(1988, 3, 21),
    );
    double at(HorizonEventKind kind) =>
        ut(events.firstWhere((e) => e.kind == kind));
    final day = julianDay(1988, 3, 20);
    expect(
      (at(HorizonEventKind.rise) - day) * 86400,
      closeTo(0.51766 * 86400, 2),
    );
    expect(
      (at(HorizonEventKind.upperTransit) - day) * 86400,
      closeTo(0.81980 * 86400, 2),
    );
    expect(
      (at(HorizonEventKind.set) - day) * 86400,
      closeTo(0.12130 * 86400, 2),
    );
  });

  group('za kołem podbiegunowym (Tromsø, 69,65° N)', () {
    const lat = 69.65, lon = 18.96;
    test('dzień polarny w czerwcu: tylko górowania i dołowania', () {
      final events = horizonEvents(
        eph,
        Naif.sun,
        lat,
        lon,
        tt(2026, 6, 20),
        tt(2026, 6, 23),
      );
      expect(events, hasLength(6));
      expect(
        events.every(
          (e) =>
              e.kind == HorizonEventKind.upperTransit ||
              e.kind == HorizonEventKind.lowerTransit,
        ),
        isTrue,
      );
      // Słońce nad horyzontem także o północy.
      final lower = events.firstWhere(
        (e) => e.kind == HorizonEventKind.lowerTransit,
      );
      expect(
        altitude(eph, Naif.sun, lat, lon, lower.jdTT),
        greaterThan(sunHorizonAltitude),
      );
    });

    test('Księżyc: żaden wschód ani zachód nie ginie', () {
      final a = tt(2026, 1, 1), b = a + 30;
      final events = horizonEvents(eph, Naif.moon, lat, lon, a, b);
      final risesSets = events.where(
        (e) =>
            e.kind == HorizonEventKind.rise || e.kind == HorizonEventKind.set,
      );
      // Próbkowanie co 2 minuty wysokości względem progu Księżyca.
      double above(double t) {
        final p = equatorialOfDate(eph, Naif.moon, t);
        final h0 =
            0.7275 *
                math.asin(earthEquatorialRadius / p.distance) *
                180 /
                math.pi +
            starHorizonAltitude;
        return altitude(eph, Naif.moon, lat, lon, t) - h0;
      }

      var n = 0;
      var prev = above(a) > 0;
      for (var t = a + 2 / 1440; t <= b; t += 2 / 1440) {
        final now = above(t) > 0;
        if (now != prev) n++;
        prev = now;
      }
      expect(risesSets, hasLength(n));
      // Wschody i zachody na przemian.
      final kinds = risesSets.map((e) => e.kind).toList();
      for (var k = 1; k < kinds.length; k++) {
        expect(kinds[k], isNot(kinds[k - 1]));
      }
    });
  });

  test('zmierzch cywilny: Słońce na −6°, świt przed wschodem', () {
    // Kraków, 50,06° N, 19,94° E.
    const lat = 50.06, lon = 19.94;
    final a = tt(2026, 3, 20), b = a + 1;
    final dawn = twilights(
      eph,
      Twilight.civil,
      lat,
      lon,
      a,
      b,
    ).firstWhere((e) => e.kind == HorizonEventKind.rise);
    final sunrise = horizonEvents(
      eph,
      Naif.sun,
      lat,
      lon,
      a,
      b,
    ).firstWhere((e) => e.kind == HorizonEventKind.rise);
    expect(altitude(eph, Naif.sun, lat, lon, dawn.jdTT), closeTo(-6, 1e-6));
    expect(
      altitude(eph, Naif.sun, lat, lon, sunrise.jdTT),
      closeTo(sunHorizonAltitude, 1e-6),
    );
    // W marcu na tej szerokości zmierzch cywilny trwa ok. pół godziny.
    expect((sunrise.jdTT - dawn.jdTT) * 1440, inInclusiveRange(25, 40));
  });

  test('współrzędne równikowe zgodne z ekliptycznymi', () {
    final jd = tt(2026, 11, 1);
    for (final naif in [Naif.sun, Naif.moon, 4, 5]) {
      final eq = equatorialOfDate(eph, naif, jd);
      final ecl = geocentricEcliptic(eph, naif, jd);
      final eps = trueObliquity(centuriesSinceJ2000(jd));
      const r = math.pi / 180;
      final v = Vector3(
        math.cos(eq.declination * r) * math.cos(eq.rightAscension * r),
        math.cos(eq.declination * r) * math.sin(eq.rightAscension * r),
        math.sin(eq.declination * r),
      ).rotateX(eps);
      var lon = math.atan2(v.y, v.x) / r % 360;
      expect((lon - ecl.longitude).abs() * 3600, lessThan(1e-6));
      expect((math.asin(v.z) / r - ecl.latitude).abs() * 3600, lessThan(1e-6));
      expect(eq.distance, ecl.distance);
    }
  });
}
