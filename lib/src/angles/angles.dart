// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import '../math/vector3.dart';
import '../reduction/precession_nutation.dart';
import '../reduction/sidereal_time.dart';
import '../time/delta_t.dart';

/// Ascendant and MC – intersections of the ecliptic with the horizon and
/// the meridian.
class Angles {
  /// Ascendant – the rising point of the ecliptic: ecliptic longitude in
  /// degrees, true ecliptic and equinox of date.
  final double ascendant;

  /// Medium coeli – the point of the ecliptic on the upper meridian
  /// (degrees).
  final double midheaven;

  /// Local sidereal time as an angle: right ascension of the meridian
  /// (degrees).
  final double armc;

  const Angles({
    required this.ascendant,
    required this.midheaven,
    required this.armc,
  });

  @override
  String toString() =>
      'Angles(ASC: $ascendant°, MC: $midheaven°, ARMC: $armc°)';
}

/// Ascendant and MC at [jdUt] (Julian day in UT) for a place at
/// [latitude] and geographic [longitude] (degrees, east positive).
///
/// [deltaTSeconds] overrides the ΔT model with your own value.
Angles angles(
  double jdUt,
  double latitude,
  double longitude, {
  double? deltaTSeconds,
}) {
  final t = centuriesSinceJ2000(
    julianDayTT(jdUt, deltaTSeconds: deltaTSeconds),
  );
  final gast = greenwichApparentSiderealTime(
    jdUt,
    deltaTSeconds: deltaTSeconds,
  );
  return anglesFromArmc(
    gast / _radian + longitude,
    latitude,
    trueObliquity(t) / _radian,
  );
}

/// Ascendant and MC for sidereal time [armc] (right ascension of the
/// meridian), [latitude] and ecliptic [obliquity] – all in degrees.
///
/// Pure spherical geometry, no time or ephemeris. Beyond the polar circle
/// the ascendant is the one of the two intersections of the ecliptic with
/// the horizon that lies east of the meridian.
Angles anglesFromArmc(double armc, double latitude, double obliquity) {
  final a = armc * _radian;
  final f = latitude * _radian;
  final e = obliquity * _radian;

  // Układ równika prawdziwego daty: oś x – punkt Barana, oś z – biegun
  // północny świata.
  final zenith = Vector3(
    math.cos(f) * math.cos(a),
    math.cos(f) * math.sin(a),
    math.sin(f),
  );
  final east = Vector3(-math.sin(a), math.cos(a), 0);
  final eclipticPole = Vector3(0, -math.sin(e), math.cos(e));

  // Przecięcia ekliptyki z horyzontem leżą w kierunkach ±k × z
  // (k – biegun ekliptyki, z – zenit, biegun horyzontu).
  var v = eclipticPole.cross(zenith);
  if (v.dot(east) < 0) v = v * -1;
  final onEcliptic = v.rotateX(e);
  final ascendant = math.atan2(onEcliptic.y, onEcliptic.x) / _radian;

  // MC: λ = atan2(sin ARMC, cos ARMC · cos ε).
  final midheaven =
      math.atan2(math.sin(a), math.cos(a) * math.cos(e)) / _radian;

  return Angles(
    ascendant: _normalize(ascendant),
    midheaven: _normalize(midheaven),
    armc: _normalize(armc),
  );
}

const _radian = math.pi / 180;

/// Kąt w stopniach → 0 ≤ x < 360.
double _normalize(double degrees) {
  final d = degrees % 360;
  return d < 0 ? d + 360 : d;
}
