// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import '../math/vector3.dart';
import '../reduction/apparent.dart';
import '../reduction/precession_nutation.dart';
import '../reduction/tdb.dart';
import '../spk/spk_ephemeris.dart';
import '../time/epochs.dart';
import '../spk/ephemeris.dart';

/// Points of the lunar orbit used in astrology.
enum LunarPoint {
  /// Mean ascending node (uniform motion, about 19.3°/year retrograde).
  meanNode,

  /// True ascending node – osculating, from the instantaneous orbit.
  trueNode,

  /// Mean Lilith – the mean apogee of the lunar orbit.
  meanApogee,

  /// Osculating Lilith – the apogee of the instantaneous lunar orbit.
  osculatingApogee,
}

/// Mean inclination of the lunar orbit to the ecliptic, in degrees.
///
/// A working value (about 5°08′43″); the primary source is still to be
/// found – see SOURCES.md. Its effect on mean Lilith (projection of the
/// apogee onto the ecliptic) is tested against J. Meeus, Astronomical
/// Algorithms, example 47.a.
const double meanLunarInclination = 5.1453964;

/// Gravitational parameter of the Earth–Moon system G(M⊕ + M☾) in km³/s².
///
/// GM⊕ = 3.986004415·10¹⁴ m³/s² (TT-compatible value) and the Moon/Earth
/// mass ratio 0.0123000371 – IERS Conventions (2010), table 1.1.
const double earthMoonGM = 398600.4415 * (1 + 0.0123000371);

/// Position of [point] on the true ecliptic and equinox of date at
/// [jdTT].
///
/// Mean points come from formulas (they do not use [ephemeris]);
/// osculating ones from the Moon's position and velocity. The distance
/// in the result is 0 for mean points and for the node; for the
/// osculating apogee it is the apogee distance of the instantaneous
/// orbit.
EclipticPosition lunarPoint(
  Ephemeris ephemeris,
  LunarPoint point,
  double jdTT,
) {
  final t = centuriesSinceJ2000(jdTT);
  final dpsi = nutation(t).longitude;
  switch (point) {
    case LunarPoint.meanNode:
      return EclipticPosition(_degrees(_meanNode(t) + dpsi), 0, 0);
    case LunarPoint.meanApogee:
      // Długość perygeum Π to kąt „łamany”: po ekliptyce do węzła, dalej
      // po orbicie. Apogeum leży naprzeciw, na orbicie nachylonej
      // o [meanLunarInclination], więc jego długość ekliptyczna to rzut
      // na ekliptykę.
      final node = _meanNode(t);
      final fromNode = _meanPerigee(t) + math.pi - node;
      const i = meanLunarInclination * math.pi / 180;
      final lon =
          node +
          math.atan2(math.sin(fromNode) * math.cos(i), math.cos(fromNode));
      return EclipticPosition(
        _degrees(lon + dpsi),
        math.asin(math.sin(fromNode) * math.sin(i)) * 180 / math.pi,
        0,
      );
    case LunarPoint.trueNode:
    case LunarPoint.osculatingApogee:
      return _osculating(ephemeris, point, jdTT, t, dpsi);
  }
}

EclipticPosition _osculating(
  Ephemeris ephemeris,
  LunarPoint point,
  double jdTT,
  double t,
  double dpsi,
) {
  // Geometryczne położenie i prędkość Księżyca względem Ziemi, obrócone
  // do ekliptyki prawdziwej daty.
  final et = (jdTT + tdbMinusTT(jdTT) / 86400 - j2000) * 86400;
  final moon = ephemeris.state(Naif.moon, Naif.earth, et);
  Vector3 toEcliptic(Vector3 v) =>
      gcrsToEclipticOfDate(v, t, nutationInLongitude: dpsi);
  final r = toEcliptic(moon.position);
  final v = toEcliptic(moon.velocity);
  // Moment pędu h = r × v jest prostopadły do płaszczyzny orbity.
  final h = r.cross(v);

  if (point == LunarPoint.trueNode) {
    // Węzeł wstępujący leży w kierunku osi z × h = (−h_y, h_x, 0).
    return EclipticPosition(_degrees(math.atan2(h.x, -h.y)), 0, 0);
  }
  // Wektor mimośrodu wskazuje perygeum: e = (v × h)/μ − r/|r|.
  final e = v.cross(h) * (1 / earthMoonGM) - r.unit;
  final apogee = e * -1;
  final semiMajorAxis =
      1 / (2 / r.length - v.dot(v) / earthMoonGM); // równanie vis-viva
  return EclipticPosition(
    _degrees(math.atan2(apogee.y, apogee.x)),
    math.asin(apogee.unit.z) * 180 / math.pi,
    semiMajorAxis * (1 + e.length),
  );
}

/// Długość średniego węzła wstępującego Ω (radiany, średnia równonoc
/// daty) – J. Chapront, M. Chapront-Touzé, G. Francou (1998), za:
/// J. Meeus, Astronomical Algorithms, 2nd ed., równ. (47.7).
double _meanNode(double t) =>
    (125.0445479 +
        t *
            (-1934.1362891 +
                t * (0.0020754 + t * (1 / 467441 - t / 60616000)))) *
    math.pi /
    180;

/// Długość średniego perygeum Π (radiany, średnia równonoc daty) – źródło
/// jak w [_meanNode].
double _meanPerigee(double t) =>
    (83.3532465 +
        t * (4069.0137287 + t * (-0.01032 + t * (-1 / 80053 + t / 18999000)))) *
    math.pi /
    180;

/// Kąt w radianach → stopnie w zakresie 0 ≤ x < 360.
double _degrees(double radians) {
  final d = radians * 180 / math.pi % 360;
  return d < 0 ? d + 360 : d;
}
