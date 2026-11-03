// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Gwiazdy stałe: odczyt danych i poszczególne poprawki sprawdzane
// z wielkościami znanymi z teorii (ruch własny, paralaksa, aberracja,
// ugięcie światła). Porównanie z innym programem – poza tym pakietem.
import 'dart:io';
import 'dart:math' as math;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';

/// Kąt między kierunkami w sekundach łuku.
double arcsecBetween(Vector3 a, Vector3 b) =>
    math.atan2(_cross(a.unit, b.unit), a.unit.dot(b.unit)) *
    180 /
    math.pi *
    3600;

double _cross(Vector3 a, Vector3 b) => Vector3(
  a.y * b.z - a.z * b.y,
  a.z * b.x - a.x * b.z,
  a.x * b.y - a.y * b.x,
).length;

/// Gwiazda w kierunku [v] (ICRS), bez ruchu i paralaksy.
FixedStar starAt(Vector3 v) {
  final u = v.unit;
  return FixedStar(
    name: 'test',
    designation: 'test',
    rightAscension: math.atan2(u.y, u.x) * 180 / math.pi,
    declination: math.asin(u.z) * 180 / math.pi,
  );
}

void main() {
  final stars = FixedStar.parseCsv(
    File('data/stars/jasne_gwiazdy.csv').readAsStringSync(),
  );
  FixedStar star(String designation) =>
      stars.firstWhere((s) => s.designation == designation);
  final eph = SpkEphemeris([de440s]);

  test('odczyt data/stars/jasne_gwiazdy.csv', () {
    expect(stars, hasLength(22));
    final aldebaran = stars.firstWhere((s) => s.name == 'Aldebaran');
    expect(aldebaran.designation, 'alf Tau');
    expect(aldebaran.rightAscension, closeTo(68.98016279, 1e-8));
    expect(aldebaran.declination, closeTo(16.50930235, 1e-8));
    expect(aldebaran.properMotionRa, 63.45);
    expect(aldebaran.properMotionDec, -188.94);
    expect(aldebaran.parallax, 48.94);
    expect(aldebaran.radialVelocity, closeTo(54.398, 1e-9));
    expect(aldebaran.magnitude, 0.86);
    // Galaktyka bez ruchu własnego i paralaksy.
    final [m31] = FixedStar.parseCsv(
      'nazwa,oznaczenie,simbad,typ,ra,dec,pmra,pmdec,plx,rv,v\n'
      'Andromeda Galaxy,M31,M  31,AGN,10.6847,41.2688,,,,-300.0,3.44\n',
    );
    expect(m31.properMotionRa, 0);
    expect(m31.parallax, 0);
  });

  test('ruch własny: przesunięcie po 100 latach = atan(μ·100 lat)', () {
    // Gwiazda testowa o ruchu jak gwiazda Barnarda (wartości zaokrąglone,
    // największy znany ruch własny); bez prędkości radialnej ruch na niebie
    // jest dokładnie po prostej w płaszczyźnie stycznej.
    const b = FixedStar(
      name: 'jak gwiazda Barnarda',
      designation: 'test',
      rightAscension: 269.45,
      declination: 4.69,
      properMotionRa: -800,
      properMotionDec: 10360,
      parallax: 547,
      radialVelocity: -110,
    );
    final barnard = FixedStar(
      name: b.name,
      designation: b.designation,
      rightAscension: b.rightAscension,
      declination: b.declination,
      properMotionRa: b.properMotionRa,
      properMotionDec: b.properMotionDec,
      parallax: b.parallax,
    );
    final mu = math.sqrt(
      math.pow(b.properMotionRa, 2) + math.pow(b.properMotionDec, 2),
    ); // mas/rok
    final shift = arcsecBetween(
      barnard.barycentricScaled(j2000),
      barnard.barycentricScaled(j2000 + 100 * 365.25),
    );
    final expected =
        math.atan(mu * 100 / 1000 / 206264.80624709636) * 206264.80624709636;
    expect(shift, closeTo(expected, 1e-9));
    expect(shift, closeTo(1038, 2)); // ok. 10,4″ na rok

    // Z prędkością radialną (gwiazda się zbliża) ruch na niebie
    // przyspiesza – „przyspieszenie perspektywiczne”.
    final withRv = arcsecBetween(
      b.barycentricScaled(j2000),
      b.barycentricScaled(j2000 + 100 * 365.25),
    );
    expect(b.radialVelocity, lessThan(0));
    expect(withRv, greaterThan(shift));
  });

  test('ujemna paralaksa (błąd pomiaru) liczona jak zerowa', () {
    FixedStar withParallax(double plx) => FixedStar(
      name: 'Rasalgethi',
      designation: 'alf1 Her',
      rightAscension: 258.66,
      declination: 14.39,
      properMotionRa: -17,
      properMotionDec: 47,
      radialVelocity: -33.1,
      parallax: plx,
    );
    final negative = fixedStarEcliptic(eph, withParallax(-7), 2460000.5);
    final zero = fixedStarEcliptic(eph, withParallax(0), 2460000.5);
    expect(negative.longitude, zero.longitude);
    expect(negative.latitude, zero.latitude);
    expect(negative.distance, double.infinity);
  });

  test('paralaksa roczna: α Cen zatacza elipsę o półosi ϖ', () {
    final alphaCen = star('alf Cen');
    var largest = 0.0;
    for (var day = 0; day < 366; day += 2) {
      final jd = 2460000.5 + day;
      final geocentric = fixedStarDirection(
        eph,
        alphaCen,
        jd,
        corrections: Corrections.none,
      ).direction;
      final barycentric = alphaCen.barycentricScaled(
        jd + tdbMinusTT(jd) / 86400,
      );
      largest = math.max(largest, arcsecBetween(geocentric, barycentric));
    }
    // Ziemia: 0,983–1,017 AU od Słońca (Słońce ~0,01 AU od barycentrum).
    final plx = alphaCen.parallax / 1000;
    expect(largest, inInclusiveRange(plx * 0.97, plx * 1.03));
  });

  test('aberracja roczna: gwiazda przy ekliptyce – do ok. 20,5″', () {
    final regulus = star('alf Leo');
    var largest = 0.0, smallest = double.infinity;
    for (var day = 0; day < 366; day += 2) {
      final jd = 2460000.5 + day;
      final off = fixedStarDirection(
        eph,
        regulus,
        jd,
        corrections: Corrections.none,
      ).direction;
      final on = fixedStarDirection(
        eph,
        regulus,
        jd,
        corrections: const Corrections(deflection: false, nutation: false),
      ).direction;
      final a = arcsecBetween(off, on);
      largest = math.max(largest, a);
      smallest = math.min(smallest, a);
    }
    // Stała aberracji κ = 20,49552″ (IAU 1976); orbita eliptyczna i ruch
    // Ziemi wokół barycentrum Ziemia–Księżyc zmieniają ją o ok. ±0,4″.
    expect(largest, inInclusiveRange(20.3, 21.0));
    expect(smallest, lessThan(1));
  });

  test('ugięcie światła: 1° od Słońca ok. 0,47″, za tarczą – brak', () {
    const jd = 2460000.5;
    final et = (jd - j2000) * 86400;
    final earth = eph.state(Naif.earth, Naif.solarSystemBarycenter, et);
    final sun = eph.state(Naif.sun, Naif.solarSystemBarycenter, et);
    final toSun = (sun.position - earth.position).unit;
    // Kierunek odchylony o θ od Słońca (prostopadle, w stronę bieguna).
    Vector3 tilted(double degrees) {
      final perpendicular = (Vector3(0, 0, 1) - toSun * toSun.z).unit;
      final t = degrees * math.pi / 180;
      return toSun * math.cos(t) + perpendicular * math.sin(t);
    }

    double deflection(double degrees) {
      final s = starAt(tilted(degrees));
      return arcsecBetween(
        fixedStarDirection(eph, s, jd, corrections: Corrections.none).direction,
        fixedStarDirection(
          eph,
          s,
          jd,
          corrections: const Corrections(aberration: false, nutation: false),
        ).direction,
      );
    }

    // Δθ = (2GM/(c²d))·cot(θ/2) ≈ 0,00407″·cot(θ/2) przy d = 1 AU.
    final distanceAu = (sun.position - earth.position).length / 149597870.7;
    for (final theta in [1.0, 10.0, 90.0]) {
      final expected =
          0.0040704 / distanceAu / math.tan(theta / 2 * math.pi / 180);
      expect(deflection(theta), closeTo(expected, expected * 0.01));
    }
    expect(deflection(0.1), 0); // za tarczą Słońca (promień ok. 0,27°)
  });

  test(
    'ekliptyka daty: Regulus 1.01.2000 ok. 149°50′, 2100 r. o 1,4° dalej',
    () {
      final regulus = star('alf Leo');
      final y2000 = fixedStarEcliptic(eph, regulus, j2000);
      final y2100 = fixedStarEcliptic(eph, regulus, j2000 + 36525);
      expect(y2000.longitude, closeTo(149.83, 0.02));
      expect(y2000.latitude, closeTo(0.46, 0.01));
      // Precesja ogólna ok. 5029″ na stulecie.
      expect((y2100.longitude - y2000.longitude) * 3600, closeTo(5029, 15));
    },
  );
}
