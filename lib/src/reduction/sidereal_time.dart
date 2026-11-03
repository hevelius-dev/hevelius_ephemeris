// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import '../time/delta_t.dart';
import '../time/epochs.dart';
import 'long_term_precession.dart';
import 'precession_nutation.dart';

/// Earth rotation angle θ (radians, 0 ≤ θ < 2π) for [jdUt] – a Julian
/// day in UT1, IERS Conventions (2010), chapter 5 (table 5.2e):
/// θ = 2π·(0.7790572732640 + 1.00273781191135448·Tu), Tu = JD(UT1) − 2451545.0.
double earthRotationAngle(double jdUt) {
  final tu = jdUt - j2000;
  // Część całkowitą obrotów (1·Tu) odrzucamy przed mnożeniem przez 2π,
  // żeby nie tracić cyfr przy dużym Tu.
  final turns = tu % 1 + 0.7790572732640 + 0.00273781191135448 * tu;
  return turns % 1 * 2 * math.pi;
}

/// Greenwich mean sidereal time (radians, 0 ≤ GMST < 2π): the Earth
/// rotation angle θ for [jdUt] plus the angle from the CIO to the mean
/// equinox of date at [jdTT], from the long-term precession model
/// (Vondrák, Capitaine and Wallace 2011; see [longTermGmstMinusEra]).
double greenwichMeanSiderealTime(double jdUt, double jdTT) =>
    (earthRotationAngle(jdUt) +
        longTermGmstMinusEra(centuriesSinceJ2000(jdTT))) %
    (2 * math.pi);

/// Greenwich mean sidereal time (radians, 0 ≤ GMST < 2π), IERS
/// Conventions (2010), table 5.2e: θ plus the IAU 2006 precession
/// polynomial in time [jdTT]. Accurate only within about ±1000 years of
/// J2000.
double greenwichMeanSiderealTimeIau2006(double jdUt, double jdTT) {
  final t = centuriesSinceJ2000(jdTT);
  final polynomial =
      (0.014506 +
          t *
              (4612.156534 +
                  t *
                      (1.3915817 +
                          t *
                              (-0.00000044 +
                                  t * (-0.000029956 + t * -0.0000000368))))) *
      arcsecond;
  return (earthRotationAngle(jdUt) + polynomial) % (2 * math.pi);
}

/// Greenwich apparent sidereal time (radians, 0 ≤ GAST < 2π) for
/// [jdUt]: GMST plus the equation of the equinoxes Δψ·cos ε_A and its
/// complementary terms (IERS Conventions 2010, table 5.2e).
/// [deltaTSeconds] overrides the ΔT model.
double greenwichApparentSiderealTime(double jdUt, {double? deltaTSeconds}) {
  final jdTT = julianDayTT(jdUt, deltaTSeconds: deltaTSeconds);
  final t = centuriesSinceJ2000(jdTT);
  final equationOfEquinoxes =
      nutation(t).longitude * math.cos(meanObliquity(t)) +
      equationOfEquinoxesComplementaryTerms(t);
  return (greenwichMeanSiderealTime(jdUt, jdTT) + equationOfEquinoxes) %
      (2 * math.pi);
}

/// True obliquity of the ecliptic of date ε = ε_A + Δε (radians).
double trueObliquity(double t) => meanObliquity(t) + nutation(t).obliquity;
