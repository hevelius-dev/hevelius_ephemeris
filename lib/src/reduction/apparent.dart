// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import '../math/vector3.dart';
import '../spk/spk_ephemeris.dart';
import '../time/epochs.dart';
import 'precession_nutation.dart';
import 'tdb.dart';
import '../spk/ephemeris.dart';

/// Speed of light in km/s (SI definition).
const double speedOfLight = 299792.458;

/// Solar gravitational parameter GM in km³/s² (IAU 2015 Resolution B3).
const double solarGM = 1.3271244e11;

/// Nominal solar radius in km (IAU 2015 Resolution B3).
const double solarRadius = 695700;

/// A position on the ecliptic of date as seen from the Earth's centre.
class EclipticPosition {
  /// Ecliptic longitude in degrees, 0 ≤ λ < 360.
  final double longitude;

  /// Ecliptic latitude in degrees.
  final double latitude;

  /// Distance in km (light-time corrected – where the body was when it
  /// emitted the light).
  final double distance;

  const EclipticPosition(this.longitude, this.latitude, this.distance);

  @override
  String toString() =>
      'EclipticPosition(λ: $longitude°, β: $latitude°, $distance km)';
}

/// Which corrections to apply when computing a position.
///
/// All by default – the apparent position, as used in a horoscope.
/// Switching individual corrections off is meant for comparisons and
/// research.
class Corrections {
  /// Light travel time from the body to the Earth.
  final bool lightTime;

  /// Gravitational deflection of light by the Sun.
  final bool deflection;

  /// Aberration of light due to the Earth's motion.
  final bool aberration;

  /// Nutation (true equinox of date instead of mean).
  final bool nutation;

  const Corrections({
    this.lightTime = true,
    this.deflection = true,
    this.aberration = true,
    this.nutation = true,
  });

  /// Geometric position: no corrections, mean equinox.
  static const none = Corrections(
    lightTime: false,
    deflection: false,
    aberration: false,
    nutation: false,
  );
}

/// Geocentric position of body [target] (NAIF code) on the ecliptic of
/// date at [jdTT] (Julian day in Terrestrial Time).
EclipticPosition geocentricEcliptic(
  Ephemeris ephemeris,
  int target,
  double jdTT, {
  Corrections corrections = const Corrections(),
}) {
  final (:direction, :distance) = geocentricDirection(
    ephemeris,
    target,
    jdTT,
    corrections: corrections,
  );
  return eclipticOfDate(direction, distance, jdTT, corrections: corrections);
}

/// Direction [direction] in the GCRS/ICRF frame as a position on the
/// ecliptic of date [jdTT] (with nutation unless [corrections] turns it
/// off).
EclipticPosition eclipticOfDate(
  Vector3 direction,
  double distance,
  double jdTT, {
  Corrections corrections = const Corrections(),
}) {
  final t = centuriesSinceJ2000(jdTT);
  final ecliptic = gcrsToEclipticOfDate(
    direction,
    t,
    nutationInLongitude: corrections.nutation ? nutation(t).longitude : 0,
  );
  final longitude = math.atan2(ecliptic.y, ecliptic.x) * 180 / math.pi;
  return EclipticPosition(
    longitude < 0 ? longitude + 360 : longitude,
    math.asin(ecliptic.z.clamp(-1.0, 1.0)) * 180 / math.pi,
    distance,
  );
}

/// Direction (unit vector in the GCRS/ICRF frame) and distance (km) from
/// the Earth's centre to body [target] at [jdTT], with [corrections]
/// applied (except nutation, which only affects the rotation to the
/// frame of date).
({Vector3 direction, double distance}) geocentricDirection(
  Ephemeris ephemeris,
  int target,
  double jdTT, {
  Corrections corrections = const Corrections(),
}) {
  final et = (jdTT + tdbMinusTT(jdTT) / 86400 - j2000) * 86400;
  final earth = ephemeris.state(Naif.earth, Naif.solarSystemBarycenter, et);

  // Czas światła: ciało oglądamy tam, gdzie było τ sekund temu,
  // τ = odległość / c; kilka przybliżeń wystarcza do nanosekund.
  var tau = 0.0;
  var body = ephemeris.state(target, Naif.solarSystemBarycenter, et).position;
  if (corrections.lightTime) {
    for (var i = 0; i < 10; i++) {
      final next = (body - earth.position).length / speedOfLight;
      body = ephemeris
          .state(target, Naif.solarSystemBarycenter, et - next)
          .position;
      final done = (next - tau).abs() < 1e-9;
      tau = next;
      if (done) break;
    }
  }
  final geocentric = body - earth.position;
  final distance = geocentric.length;
  var direction = geocentric.unit;

  if (corrections.deflection && target != Naif.sun) {
    final sun = ephemeris
        .state(Naif.sun, Naif.solarSystemBarycenter, et - tau)
        .position;
    // Ciało schowane za tarczą Słońca: jego światło do nas nie dociera,
    // więc ugięcia nie liczymy (tak samo robi NASA JPL Horizons).
    if (!_behindSun(geocentric, sun - earth.position)) {
      direction = deflectLight(direction, body - sun, earth.position - sun);
    }
  }
  if (corrections.aberration) {
    direction = aberrate(direction, earth.velocity * (1 / speedOfLight));
  }
  return (direction: direction, distance: distance);
}

/// Czy ciało w kierunku [geocentric] leży za tarczą Słońca widzianego
/// w kierunku [sunFromEarth] (oba wektory od środka Ziemi).
bool _behindSun(Vector3 geocentric, Vector3 sunFromEarth) =>
    geocentric.length > sunFromEarth.length &&
    onSolarDisk(geocentric, sunFromEarth);

/// Whether [direction] (from the Earth's centre) falls on the disk of the
/// Sun seen in direction [sunFromEarth].
bool onSolarDisk(Vector3 direction, Vector3 sunFromEarth) {
  final cosSeparation = direction.unit.dot(sunFromEarth.unit);
  final sinRadius = solarRadius / sunFromEarth.length;
  return cosSeparation > math.sqrt(1 - sinRadius * sinRadius);
}

/// Deflection of light by the Sun (general relativity).
///
/// [u] – Earth→body direction (unit vector), [sunToBody] and
/// [sunToEarth] – vectors from the Sun. Formula: Explanatory Supplement
/// (2013), chapter 7.
Vector3 deflectLight(Vector3 u, Vector3 sunToBody, Vector3 sunToEarth) {
  final q = sunToBody.unit, e = sunToEarth.unit;
  final g = 2 * solarGM / (speedOfLight * speedOfLight * sunToEarth.length);
  final shift = (e * u.dot(q) - q * e.dot(u)) * (g / (1 + q.dot(e)));
  return (u + shift).unit;
}

/// Relativistic aberration: direction [u] as seen by an observer moving
/// with velocity [v] (in units of c).
///
/// `u′ = [u/γ + (1 + u·v/(1 + 1/γ))·v] / (1 + u·v)`, `1/γ = √(1 − v²)`.
Vector3 aberrate(Vector3 u, Vector3 v) {
  final inverseGamma = math.sqrt(1 - v.dot(v));
  final uv = u.dot(v);
  return ((u * inverseGamma + v * (1 + uv / (1 + inverseGamma))) *
          (1 / (1 + uv)))
      .unit;
}
