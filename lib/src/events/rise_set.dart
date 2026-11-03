// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import '../reduction/apparent.dart';
import '../reduction/precession_nutation.dart';
import '../reduction/sidereal_time.dart';
import '../spk/spk_ephemeris.dart';
import '../time/delta_t.dart';
import 'crossings.dart';
import '../spk/ephemeris.dart';

/// Apparent geocentric position on the true equator and equinox of date.
class EquatorialPosition {
  /// Right ascension in degrees, 0 ≤ α < 360.
  final double rightAscension;

  /// Declination in degrees.
  final double declination;

  /// Distance in km (light-time corrected).
  final double distance;

  const EquatorialPosition(
    this.rightAscension,
    this.declination,
    this.distance,
  );
}

/// What happens at a [HorizonEvent].
enum HorizonEventKind {
  /// The body rises: its altitude grows through the horizon altitude.
  rise,

  /// The body sets: its altitude falls through the horizon altitude.
  set,

  /// Upper culmination: the body crosses the meridian above the pole.
  upperTransit,

  /// Lower culmination: the body crosses the meridian below the pole.
  lowerTransit,
}

/// A rising, setting or meridian transit.
class HorizonEvent {
  /// Julian day in Terrestrial Time.
  final double jdTT;

  final HorizonEventKind kind;

  const HorizonEvent(this.jdTT, this.kind);

  @override
  String toString() => 'HorizonEvent($jdTT, ${kind.name})';
}

/// Twilight: the Sun's centre at a given altitude below the horizon.
enum Twilight {
  civil(-6),
  nautical(-12),
  astronomical(-18);

  /// Altitude of the Sun's centre in degrees.
  final double altitude;

  const Twilight(this.altitude);
}

/// Standard altitude of the Sun's centre at sunrise and sunset in
/// degrees: refraction 34′ plus semidiameter 16′.
const double sunHorizonAltitude = -50 / 60;

/// Standard altitude of the centre of a star or planet at rising and
/// setting in degrees: refraction 34′.
const double starHorizonAltitude = -34 / 60;

/// Equatorial radius of the Earth in km (IERS Conventions 2010, table
/// 1.1), for the Moon's horizontal parallax.
const double earthEquatorialRadius = 6378.1366;

/// Apparent geocentric right ascension and declination of body [target]
/// (NAIF code) on the true equator and equinox of date at [jdTT].
EquatorialPosition equatorialOfDate(
  Ephemeris ephemeris,
  int target,
  double jdTT,
) {
  final (:direction, :distance) = geocentricDirection(ephemeris, target, jdTT);
  final t = centuriesSinceJ2000(jdTT);
  final equator = gcrsToEclipticOfDate(
    direction,
    t,
    nutationInLongitude: nutation(t).longitude,
  ).rotateX(-trueObliquity(t));
  final ra = math.atan2(equator.y, equator.x) / _radian;
  return EquatorialPosition(
    ra < 0 ? ra + 360 : ra,
    math.asin(equator.z.clamp(-1.0, 1.0)) / _radian,
    distance,
  );
}

/// Geometric altitude (no refraction) of body [target] above the
/// horizon of a place at [latitude] and geographic [longitude] (degrees,
/// east positive) at [jdTT], in degrees, as seen from the Earth's centre.
double altitude(
  Ephemeris ephemeris,
  int target,
  double latitude,
  double longitude,
  double jdTT,
) {
  final p = equatorialOfDate(ephemeris, target, jdTT);
  return _altitude(p, _hourAngle(p, longitude, jdTT), latitude);
}

/// Risings, settings and meridian transits of body [target] for a place
/// at [latitude] and geographic [longitude] (degrees, east positive) in
/// [startJdTT] … [endJdTT], in time order.
///
/// The body rises or sets when its geocentric centre is at
/// [horizonAltitude] degrees. By default that is the almanac convention:
/// [sunHorizonAltitude] for the Sun, [starHorizonAltitude] for planets,
/// and for the Moon 0.7275·π − 34′, where π is its horizontal parallax
/// (J. Meeus, Astronomical Algorithms, chapter 15). Refraction is a
/// standard value; real refraction near the horizon varies by several
/// arcminutes, i.e. by tens of seconds or more in time.
///
/// Near the poles a body may stay above or below the horizon: then the
/// list has only transits.
List<HorizonEvent> horizonEvents(
  Ephemeris ephemeris,
  int target,
  double latitude,
  double longitude,
  double startJdTT,
  double endJdTT, {
  double? horizonAltitude,
}) {
  double h0(EquatorialPosition p) =>
      horizonAltitude ??
      switch (target) {
        Naif.sun => sunHorizonAltitude,
        Naif.moon =>
          0.7275 * math.asin(earthEquatorialRadius / p.distance) / _radian +
              starHorizonAltitude,
        _ => starHorizonAltitude,
      };
  double hourAngleAt(double t) =>
      _hourAngle(equatorialOfDate(ephemeris, target, t), longitude, t);
  double aboveHorizon(double t) {
    final p = equatorialOfDate(ephemeris, target, t);
    return _altitude(p, _hourAngle(p, longitude, t), latitude) - h0(p);
  }

  // Culminations: hour angle 0° (upper) and 180° (lower). Between them
  // the altitude changes in one direction, so each piece has at most one
  // rising or setting.
  final transits = longitudeCrossings(
    hourAngleAt,
    startJdTT,
    endJdTT,
    period: 180,
    step: 0.25,
  );
  final events = <HorizonEvent>[
    for (final c in transits)
      HorizonEvent(
        c.jdTT,
        c.longitude < 90
            ? HorizonEventKind.upperTransit
            : HorizonEventKind.lowerTransit,
      ),
  ];
  final cuts = [startJdTT, for (final c in transits) c.jdTT, endJdTT];
  for (var i = 0; i + 1 < cuts.length; i++) {
    final a = cuts[i], b = cuts[i + 1];
    final fa = aboveHorizon(a), fb = aboveHorizon(b);
    if (fa < 0 == fb < 0) continue;
    events.add(
      HorizonEvent(
        _bisect(aboveHorizon, a, b, fa),
        fa < 0 ? HorizonEventKind.rise : HorizonEventKind.set,
      ),
    );
  }
  return events..sort((x, y) => x.jdTT.compareTo(y.jdTT));
}

/// Dawns and dusks of [twilight] for a place at [latitude] and
/// [longitude] in [startJdTT] … [endJdTT]: moments when the centre of the
/// Sun is at [Twilight.altitude]. Dawn is a [HorizonEventKind.rise], dusk
/// a [HorizonEventKind.set]; transits of the Sun are left out.
List<HorizonEvent> twilights(
  Ephemeris ephemeris,
  Twilight twilight,
  double latitude,
  double longitude,
  double startJdTT,
  double endJdTT,
) => [
  for (final e in horizonEvents(
    ephemeris,
    Naif.sun,
    latitude,
    longitude,
    startJdTT,
    endJdTT,
    horizonAltitude: twilight.altitude,
  ))
    if (e.kind == HorizonEventKind.rise || e.kind == HorizonEventKind.set) e,
];

/// Local hour angle in degrees (0 ≤ H < 360) of position [p] at [jdTT]
/// for geographic [longitude].
double _hourAngle(EquatorialPosition p, double longitude, double jdTT) {
  final gast = greenwichApparentSiderealTime(julianDayUT(jdTT)) / _radian;
  return (gast + longitude - p.rightAscension) % 360;
}

/// Altitude in degrees for hour angle [hourAngle] and [latitude].
double _altitude(EquatorialPosition p, double hourAngle, double latitude) {
  final phi = latitude * _radian, delta = p.declination * _radian;
  final sinH =
      math.sin(phi) * math.sin(delta) +
      math.cos(phi) * math.cos(delta) * math.cos(hourAngle * _radian);
  return math.asin(sinH.clamp(-1.0, 1.0)) / _radian;
}

/// Root of [f] in [a] … [b] (f(a) = [fa] and f(b) of opposite signs) by
/// bisection to 1e-8 day (about 1 ms).
double _bisect(double Function(double) f, double a, double b, double fa) {
  while (b - a > 1e-8) {
    final m = (a + b) / 2, fm = f(m);
    if (fm < 0 == fa < 0) {
      a = m;
      fa = fm;
    } else {
      b = m;
    }
  }
  return (a + b) / 2;
}

const _radian = math.pi / 180;
