// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import '../events/rise_set.dart';
import '../math/vector3.dart';
import '../stars/fixed_star.dart';
import '../time/delta_t.dart';
import 'precession_nutation.dart';
import 'sidereal_time.dart';
import '../spk/ephemeris.dart';

const double _degree = math.pi / 180;

/// A place on the Earth: geodetic [latitude] and [longitude] (degrees,
/// north and east positive) and [height] above sea level in metres.
class Observer {
  final double latitude, longitude, height;

  /// Geocentric coordinates ρ·sin φ′ and ρ·cos φ′ in equatorial Earth
  /// radii (J. Meeus, Astronomical Algorithms, chapter 11).
  final double rhoSin, rhoCos;

  factory Observer({
    required double latitude,
    required double longitude,
    double height = 0,
  }) {
    final phi = latitude * _degree;
    final u = math.atan((1 - earthFlattening) * math.tan(phi));
    final h = height / 1000 / earthEquatorialRadius;
    return Observer._(
      latitude,
      longitude,
      height,
      (1 - earthFlattening) * math.sin(u) + h * math.sin(phi),
      math.cos(u) + h * math.cos(phi),
    );
  }

  const Observer._(
    this.latitude,
    this.longitude,
    this.height,
    this.rhoSin,
    this.rhoCos,
  );

  /// Local apparent sidereal time (radians) at [jdTT]; [deltaTSeconds]
  /// overrides the ΔT model.
  double localSiderealTime(double jdTT, {double? deltaTSeconds}) =>
      greenwichApparentSiderealTime(
        julianDayUT(jdTT, deltaTSeconds: deltaTSeconds),
        deltaTSeconds: deltaTSeconds,
      ) +
      longitude * _degree;

  /// Geocentric position of the observer in km, in the frame of the true
  /// equator and equinox of date at [jdTT].
  Vector3 position(double jdTT, {double? deltaTSeconds}) {
    final theta = localSiderealTime(jdTT, deltaTSeconds: deltaTSeconds);
    return Vector3(rhoCos * math.cos(theta), rhoCos * math.sin(theta), rhoSin) *
        earthEquatorialRadius;
  }
}

/// Flattening of the Earth (IERS Conventions 2010, table 1.1).
const double earthFlattening = 1 / 298.25642;

/// Position of a body in the sky of an [Observer].
class HorizontalPosition {
  /// Altitude above the horizon in degrees: geometric, or apparent when
  /// refraction was requested.
  final double altitude;

  /// Azimuth in degrees from north through east (0° north, 90° east).
  final double azimuth;

  /// Local hour angle in degrees (0 … 360, positive west of the meridian).
  final double hourAngle;

  /// Topocentric right ascension and declination in degrees, true equator
  /// and equinox of date.
  final double rightAscension, declination;

  /// Distance from the observer in km (infinite for a star without
  /// parallax or for [equatorialToHorizontal]).
  final double distance;

  const HorizontalPosition({
    required this.altitude,
    required this.azimuth,
    required this.hourAngle,
    required this.rightAscension,
    required this.declination,
    required this.distance,
  });

  @override
  String toString() =>
      'HorizontalPosition(altitude $altitude, azimuth $azimuth)';
}

/// Atmospheric refraction in degrees for the geometric (airless)
/// altitude [altitude] in degrees: Sæmundsson's formula (J. Meeus,
/// Astronomical Algorithms, eq. 16.4, made exactly zero at the zenith),
/// scaled for air [pressure] (millibars) and [temperature] (°C).
///
/// For yellow light and a standard atmosphere; near the horizon real
/// refraction varies by around 0.3° from this mean value. Below −1° the
/// value at −1° is returned (the body is not visible there anyway).
double refraction(
  double altitude, {
  double pressure = 1010,
  double temperature = 10,
}) {
  final h = math.max(altitude, -1.0);
  final arcminutes =
      1.02 / math.tan((h + 10.3 / (h + 5.11)) * _degree) + 0.0019279;
  return arcminutes / 60 * (pressure / 1010) * (283 / (273 + temperature));
}

/// Horizontal coordinates of a direction given by apparent right
/// ascension and declination of date ([rightAscension], [declination],
/// degrees; true equator and equinox of date) for [observer] at [jdTT].
/// No parallax – for stars, galaxies and other distant objects.
///
/// For catalogue (ICRS/J2000) coordinates create a [FixedStar] and use
/// [fixedStarHorizontal], which also applies precession, nutation and
/// aberration.
HorizontalPosition equatorialToHorizontal(
  double rightAscension,
  double declination,
  Observer observer,
  double jdTT, {
  bool withRefraction = false,
  double pressure = 1010,
  double temperature = 10,
  double? deltaTSeconds,
}) => _horizontal(
  rightAscension,
  declination,
  double.infinity,
  observer,
  jdTT,
  withRefraction,
  pressure,
  temperature,
  deltaTSeconds,
);

/// Horizontal coordinates of body [target] (NAIF code: Sun, Moon,
/// planets, or a small body from an added file) for [observer] at [jdTT].
///
/// Topocentric: the observer's position is subtracted from the apparent
/// geocentric position (parallax – up to about 1° for the Moon, 30″ for
/// Venus, 8.8″ for the Sun). Diurnal aberration (at most 0.3″) is
/// neglected. [withRefraction] adds atmospheric [refraction].
HorizontalPosition horizontalPosition(
  Ephemeris ephemeris,
  int target,
  Observer observer,
  double jdTT, {
  bool withRefraction = false,
  double pressure = 1010,
  double temperature = 10,
  double? deltaTSeconds,
}) {
  final p = equatorialOfDate(ephemeris, target, jdTT);
  final ra = p.rightAscension * _degree, dec = p.declination * _degree;
  final geocentric =
      Vector3(
        math.cos(dec) * math.cos(ra),
        math.cos(dec) * math.sin(ra),
        math.sin(dec),
      ) *
      p.distance;
  final topocentric =
      geocentric - observer.position(jdTT, deltaTSeconds: deltaTSeconds);
  final distance = topocentric.length;
  final tra = math.atan2(topocentric.y, topocentric.x) / _degree;
  return _horizontal(
    tra < 0 ? tra + 360 : tra,
    math.asin(topocentric.z / distance) / _degree,
    distance,
    observer,
    jdTT,
    withRefraction,
    pressure,
    temperature,
    deltaTSeconds,
  );
}

/// Horizontal coordinates of [star] for [observer] at [jdTT] (apparent
/// place as in [fixedStarEcliptic]: space motion, annual parallax, light
/// deflection, aberration, precession and nutation).
HorizontalPosition fixedStarHorizontal(
  Ephemeris ephemeris,
  FixedStar star,
  Observer observer,
  double jdTT, {
  bool withRefraction = false,
  double pressure = 1010,
  double temperature = 10,
  double? deltaTSeconds,
}) {
  final (:direction, :distance) = fixedStarDirection(ephemeris, star, jdTT);
  final t = centuriesSinceJ2000(jdTT);
  final equator = gcrsToEclipticOfDate(
    direction,
    t,
    nutationInLongitude: nutation(t).longitude,
  ).rotateX(-trueObliquity(t));
  final ra = math.atan2(equator.y, equator.x) / _degree;
  return _horizontal(
    ra < 0 ? ra + 360 : ra,
    math.asin(equator.z.clamp(-1.0, 1.0)) / _degree,
    distance,
    observer,
    jdTT,
    withRefraction,
    pressure,
    temperature,
    deltaTSeconds,
  );
}

HorizontalPosition _horizontal(
  double rightAscension,
  double declination,
  double distance,
  Observer observer,
  double jdTT,
  bool withRefraction,
  double pressure,
  double temperature,
  double? deltaTSeconds,
) {
  final lst = observer.localSiderealTime(jdTT, deltaTSeconds: deltaTSeconds);
  final h = lst - rightAscension * _degree;
  final phi = observer.latitude * _degree, d = declination * _degree;
  var altitude =
      math.asin(
        math.sin(phi) * math.sin(d) + math.cos(phi) * math.cos(d) * math.cos(h),
      ) /
      _degree;
  final azimuth =
      math.atan2(
        -math.cos(d) * math.sin(h),
        math.sin(d) * math.cos(phi) - math.cos(d) * math.cos(h) * math.sin(phi),
      ) /
      _degree;
  if (withRefraction) {
    altitude += refraction(
      altitude,
      pressure: pressure,
      temperature: temperature,
    );
  }
  return HorizontalPosition(
    altitude: altitude,
    azimuth: azimuth < 0 ? azimuth + 360 : azimuth,
    hourAngle: (h / _degree) % 360,
    rightAscension: rightAscension,
    declination: declination,
    distance: distance,
  );
}
