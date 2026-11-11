// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import '../math/vector3.dart';
import '../time/epochs.dart';
import 'long_term_precession.dart';
import 'nutation_data.dart';

// Precesja: model długookresowy Vondráka, Capitaine i Wallace'a (2011),
// ważny ±200 000 lat (long_term_precession.dart); w latach 1600–2500
// zgodny z IAU 2006 do 0,01″. Precesja IAU 2006 zostaje w funkcjach
// *Iau2006 – do porównań. Nutacja IAU 2000A (z poprawkami R06) według
// IERS Conventions (2010), rozdz. 5. Wzory są formalnie w TDB, ale IERS
// zaleca TT – różnica jest poniżej mikrosekundy łuku.

/// Julian centuries since J2000 for Julian day [jd] – the time argument
/// `t` of the precession and nutation functions (IAU 2006 precession,
/// IAU 2000A nutation with R06 adjustments, IERS Conventions 2010,
/// chapter 5). Pass a TT Julian day.
double centuriesSinceJ2000(double jd) => (jd - j2000) / daysPerJulianCentury;

/// One arcsecond in radians.
const double arcsecond = math.pi / (180 * 3600);

/// Mean obliquity of the ecliptic of date ε_A (radians), from the
/// long-term precession model (Vondrák, Capitaine and Wallace 2011): the
/// angle between the mean equator and ecliptic poles of date.
double meanObliquity(double t) => longTermMeanObliquity(t);

/// Mean obliquity of the ecliptic of date ε_A (radians) of the IAU 2006
/// precession, IERS Conventions (2010) eq. 5.40 – accurate only within
/// about ±1000 years of J2000.
double meanObliquityIau2006(double t) =>
    _poly(t, [
      84381.406,
      -46.836769,
      -0.0001831,
      0.0020034,
      -0.000000576,
      -0.0000000434,
    ]) *
    arcsecond;

/// Nutation in longitude Δψ and in obliquity Δε (radians): the IAU 2000A
/// series ([nutationIau2000A]) interpolated from values at whole Julian
/// days.
///
/// The series have about 1400 terms, and searches for events ask for
/// nutation at thousands of moments. Lagrange interpolation of degree 11
/// from the 12 nearest whole days TT differs from the series by less
/// than 1 µas (0.000001″) – tested at random dates – and costs a small
/// fraction of the series. Values at whole days are kept in a bounded
/// cache.
({double longitude, double obliquity}) nutation(double t) {
  final x = t * daysPerJulianCentury + (j2000 - _nutationGridOrigin);
  final k0 = x.floor() - _nutationNodes ~/ 2 + 1;
  var longitude = 0.0, obliquity = 0.0;
  for (var i = 0; i < _nutationNodes; i++) {
    var w = _lagrangeDenominators[i];
    for (var j = 0; j < _nutationNodes; j++) {
      if (j != i) w *= x - (k0 + j);
    }
    final node = _nutationNode(k0 + i);
    longitude += w * node.longitude;
    obliquity += w * node.obliquity;
  }
  return (longitude: longitude, obliquity: obliquity);
}

/// Nutation in longitude Δψ and in obliquity Δε (radians) straight from
/// the IAU 2000A series with the R06 adjustments, IERS Conventions
/// (2010), tables 5.3a and 5.3b. [nutation] gives the same to better
/// than 1 µas, much faster.
({double longitude, double obliquity}) nutationIau2000A(double t) {
  final args = _fundamentalArguments(t);
  return (
    longitude: _series(nutationInLongitude, args, t),
    obliquity: _series(nutationInObliquity, args, t),
  );
}

// Siatka węzłów interpolacji: pełne dni juliańskie TT (k = JD − origin),
// 12 węzłów wokół chwili. Pomiar (5000 losowych dat, lata −12 900 …
// +12 000): krok 1 d i 12 węzłów – maks. 0,66 µas; 8 węzłów – 10 µas.
const int _nutationNodes = 12;
const double _nutationGridOrigin = 2451545.0;

/// 1 / ∏(i − j) dla j ≠ i – stałe mianowniki wag Lagrange'a.
final List<double> _lagrangeDenominators = [
  for (var i = 0; i < _nutationNodes; i++)
    1 /
        [
          for (var j = 0; j < _nutationNodes; j++)
            if (j != i) (i - j).toDouble(),
        ].fold(1.0, (a, b) => a * b),
];

final Map<int, ({double longitude, double obliquity})> _nutationCache = {};

/// Ok. 30 lat węzłów (ok. 1 MB); po przekroczeniu pamięć zaczyna od nowa.
const int _nutationCacheLimit = 11000;

({double longitude, double obliquity}) _nutationNode(int k) {
  final cached = _nutationCache[k];
  if (cached != null) return cached;
  if (_nutationCache.length >= _nutationCacheLimit) _nutationCache.clear();
  return _nutationCache[k] = nutationIau2000A(
    (k + _nutationGridOrigin - j2000) / daysPerJulianCentury,
  );
}

/// Fukushima–Williams angles (radians), eq. 5.40: γ̄, φ̄, ψ̄.
///
/// They relate the ecliptic of date directly to the GCRS (including the
/// ICRS–J2000 frame bias), so no separate bias matrix is needed.
({double gamma, double phi, double psi}) fukushimaWilliams(double t) => (
  gamma:
      _poly(t, [
        -0.052928,
        10.556378,
        0.4932044,
        -0.00031238,
        -0.000002788,
        0.000000026,
      ]) *
      arcsecond,
  phi:
      _poly(t, [
        84381.412819,
        -46.811016,
        0.0511268,
        0.00053289,
        -0.00000044,
        -0.0000000176,
      ]) *
      arcsecond,
  psi:
      _poly(t, [
        -0.041775,
        5038.481484,
        1.5584175,
        -0.00018522,
        -0.000026452,
        -0.0000000148,
      ]) *
      arcsecond,
);

/// Transforms vector [r] from the GCRS (ICRF) to the ecliptic and equinox
/// of date.
///
/// With [nutationInLongitude] equal to Δψ the result refers to the true
/// equinox of date (as in a horoscope); with zero – to the mean equinox.
///
/// Precession from the long-term model (Vondrák, Capitaine and Wallace
/// 2011), valid for ±200 000 years; nutation in longitude is a rotation
/// about the pole of the ecliptic of date.
Vector3 gcrsToEclipticOfDate(
  Vector3 r,
  double t, {
  required double nutationInLongitude,
}) => longTermGcrsToMeanEclipticOfDate(r, t).rotateZ(-nutationInLongitude);

/// As [gcrsToEclipticOfDate], with the IAU 2006 precession: the matrix
/// R₁(−ε)·R₃(−ψ)·R₁(φ̄)·R₃(γ̄) of the IERS Conventions, section 5.4.5,
/// without the final rotation R₁(−ε) (to the equator). Accurate only
/// within about ±1000 years of J2000.
Vector3 gcrsToEclipticOfDateIau2006(
  Vector3 r,
  double t, {
  required double nutationInLongitude,
}) {
  final fw = fukushimaWilliams(t);
  return r
      .rotateZ(fw.gamma)
      .rotateX(fw.phi)
      .rotateZ(-(fw.psi + nutationInLongitude));
}

/// Delaunay arguments (radians, not reduced to 0–2π), eq. 5.43:
/// l – mean anomaly of the Moon, l′ – mean anomaly of the Sun,
/// F = L − Ω, D – mean elongation of the Moon from the Sun, Ω – mean
/// longitude of the Moon's ascending node (mean equinox of date).
({double l, double lPrime, double f, double d, double omega}) delaunayArguments(
  double t,
) {
  final a = _fundamentalArguments(t);
  return (l: a[0], lPrime: a[1], f: a[2], d: a[3], omega: a[4]);
}

/// Complementary terms of the equation of the equinoxes (radians): the
/// non-polynomial part of Greenwich sidereal time beyond Δψ·cos ε_A,
/// IERS Conventions (2010), table 5.2e. Together below 0.003″.
double equationOfEquinoxesComplementaryTerms(double t) =>
    _series(equationOfEquinoxesTerms, _fundamentalArguments(t), t);

/// Argumenty podstawowe nutacji F1–F14 (radiany), równ. 5.43 i 5.44.
List<double> _fundamentalArguments(double t) {
  double delaunay(double degrees, List<double> arcseconds) =>
      (degrees * 3600 + _poly(t, [0, ...arcseconds])) * arcsecond;
  return [
    // l – anomalia średnia Księżyca
    delaunay(134.96340251, [1717915923.2178, 31.8792, 0.051635, -0.0002447]),
    // l′ – anomalia średnia Słońca
    delaunay(357.52910918, [129596581.0481, -0.5532, 0.000136, -0.00001149]),
    // F = L − Ω
    delaunay(93.27209062, [1739527262.8478, -12.7512, -0.001037, 0.00000417]),
    // D – średnia elongacja Księżyca od Słońca
    delaunay(297.85019547, [1602961601.209, -6.3706, 0.006593, -0.00003169]),
    // Ω – długość średnia węzła wstępującego Księżyca
    delaunay(125.04455501, [-6962890.5431, 7.4722, 0.007702, -0.00005939]),
    // Długości średnie planet (Merkury … Neptun) i precesja ogólna p_A.
    4.402608842 + 2608.7903141574 * t,
    3.176146697 + 1021.3285546211 * t,
    1.753470314 + 628.3075849991 * t,
    6.203480913 + 334.06124267 * t,
    0.599546497 + 52.9690962641 * t,
    0.874016757 + 21.329910496 * t,
    5.481293872 + 7.4781598567 * t,
    5.311886287 + 3.8133035638 * t,
    0.02438175 * t + 0.00000538691 * t * t,
  ];
}

/// Suma szeregu nutacji (radiany); [table] jak w nutation_data.dart.
double _series(List<int> table, List<double> args, double t) {
  var sum = 0.0;
  for (var i = 0; i < table.length; i += 17) {
    var arg = 0.0;
    for (var k = 0; k < 14; k++) {
      final n = table[i + 3 + k];
      if (n != 0) arg += n * args[k];
    }
    final term = table[i + 1] * math.sin(arg) + table[i + 2] * math.cos(arg);
    sum += table[i] == 0 ? term : term * t;
  }
  // Współczynniki są w 0,01 µas = 1e-8″.
  return sum * 1e-8 * arcsecond;
}

/// Wielomian c₀ + c₁·t + c₂·t² + … (schemat Hornera).
double _poly(double t, List<double> c) {
  var sum = 0.0;
  for (var i = c.length - 1; i >= 0; i--) {
    sum = sum * t + c[i];
  }
  return sum;
}
