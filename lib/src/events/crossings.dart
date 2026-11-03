// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import '../reduction/apparent.dart';
import '../reduction/speed.dart';
import '../spk/spk_ephemeris.dart';
import '../time/calendar.dart';
import '../time/delta_t.dart';
import '../spk/ephemeris.dart';

/// A moment when a longitude reaches one of the searched values.
class LongitudeCrossing {
  /// Julian day in Terrestrial Time.
  final double jdTT;

  /// The value reached, in degrees (0 ≤ x < 360).
  final double longitude;

  /// Whether the longitude was decreasing at that moment.
  final bool retrograde;

  const LongitudeCrossing(this.jdTT, this.longitude, this.retrograde);

  @override
  String toString() =>
      'LongitudeCrossing($jdTT, $longitude°${retrograde ? ', R' : ''})';
}

/// A station: the moment when a body turns retrograde or direct.
class Station {
  /// Julian day in Terrestrial Time.
  final double jdTT;

  /// Longitude at the station, in degrees.
  final double longitude;

  /// True when the motion turns from direct to retrograde.
  final bool turnsRetrograde;

  const Station(this.jdTT, this.longitude, this.turnsRetrograde);

  @override
  String toString() =>
      'Station($jdTT, $longitude°, '
      '${turnsRetrograde ? 'retrograde' : 'direct'})';
}

/// An entry of a body into a zodiac sign.
class Ingress {
  /// Julian day in Terrestrial Time.
  final double jdTT;

  /// The sign entered: 0 = Aries … 11 = Pisces.
  final int sign;

  /// Whether the body entered the sign moving retrograde (from the next
  /// sign back).
  final bool retrograde;

  const Ingress(this.jdTT, this.sign, this.retrograde);

  @override
  String toString() => 'Ingress($jdTT, sign $sign${retrograde ? ', R' : ''})';
}

/// The equinoxes and solstices.
enum Season { marchEquinox, juneSolstice, septemberEquinox, decemberSolstice }

/// A function giving an ecliptic longitude in degrees for a Julian day in
/// Terrestrial Time.
typedef LongitudeFunction = double Function(double jdTT);

/// Apparent geocentric ecliptic longitude of body [naif] (NAIF code) as a
/// [LongitudeFunction], for use with [longitudeCrossings], [ingresses]
/// and [stations].
LongitudeFunction bodyLongitude(Ephemeris ephemeris, int naif) =>
    (jdTT) => geocentricEcliptic(ephemeris, naif, jdTT).longitude;

/// All moments in [startJdTT] … [endJdTT] when [longitudeAt] reaches
/// [offset] + k·[period] degrees for any integer k, in time order.
///
/// Works through retrograde motion: the span is first cut at stations,
/// and between stations the longitude changes in one direction only, so
/// no crossing is missed. [step] (days) must be shorter than the shortest
/// stretch of direct or retrograde motion and short enough for the
/// longitude to change by less than 180° – 1 day suits the Sun, the Moon,
/// the planets and the mean lunar points; use about 0.25 day for the true
/// node and the osculating apogee.
///
/// Times are accurate to about 1 ms of the longitude model.
List<LongitudeCrossing> longitudeCrossings(
  LongitudeFunction longitudeAt,
  double startJdTT,
  double endJdTT, {
  required double period,
  double offset = 0,
  double step = 1,
}) {
  final result = <LongitudeCrossing>[];
  for (final (a, b) in _pieces(longitudeAt, startJdTT, endJdTT, step)) {
    final la = longitudeAt(a);
    final lb = la + _wrap180(longitudeAt(b) - la);
    final retrograde = lb < la;
    // Values strictly after a and up to b in the direction of motion, so a
    // value at a span boundary is counted once.
    final low = retrograde ? lb : la, high = retrograde ? la : lb;
    var k = ((low - offset) / period).floor();
    final values = <double>[];
    for (var v = offset + k * period; v <= high; v = offset + ++k * period) {
      if (retrograde ? v >= low && v < high : v > low && v <= high) {
        values.add(v);
      }
    }
    if (retrograde) values.sort((x, y) => y.compareTo(x));
    for (final v in values) {
      final t = _solve((t) => _wrap180(longitudeAt(t) - v), a, b);
      result.add(LongitudeCrossing(t, _normalize(v), retrograde));
    }
  }
  return result;
}

/// Entries of [longitudeAt] into zodiac signs in [startJdTT] … [endJdTT],
/// including re-entries during retrograde motion. See
/// [longitudeCrossings] for [step].
List<Ingress> ingresses(
  LongitudeFunction longitudeAt,
  double startJdTT,
  double endJdTT, {
  double step = 1,
}) => [
  for (final c in longitudeCrossings(
    longitudeAt,
    startJdTT,
    endJdTT,
    period: 30,
    step: step,
  ))
    Ingress(
      c.jdTT,
      // Moving back over a boundary enters the sign below it.
      ((c.longitude / 30).round() - (c.retrograde ? 1 : 0)) % 12,
      c.retrograde,
    ),
];

/// Stations of [longitudeAt] in [startJdTT] … [endJdTT]: moments when the
/// speed in longitude changes sign. See [longitudeCrossings] for [step].
///
/// The longitude hardly changes near a station, so its time is
/// determined less sharply than a crossing – to about a minute for the
/// planets.
List<Station> stations(
  LongitudeFunction longitudeAt,
  double startJdTT,
  double endJdTT, {
  double step = 1,
}) => [
  for (final t in _stationTimes(longitudeAt, startJdTT, endJdTT, step))
    Station(
      t,
      _normalize(longitudeAt(t)),
      longitudeSpeed(longitudeAt, t - step / 4) > 0,
    ),
];

/// The equinoxes and solstices of [year] (calendar year as in
/// [julianDay]), as Julian days in Terrestrial Time: the moments when the
/// apparent geocentric longitude of the Sun is 0°, 90°, 180° and 270°.
Map<Season, double> seasons(Ephemeris ephemeris, int year) {
  final start = julianDayTT(julianDay(year, 1, 1));
  final end = julianDayTT(julianDay(year + 1, 1, 1));
  return {
    for (final c in longitudeCrossings(
      bodyLongitude(ephemeris, Naif.sun),
      start,
      end,
      period: 90,
      step: 5,
    ))
      Season.values[(c.longitude / 90).round() % 4]: c.jdTT,
  };
}

/// [start] … [end] cut at stations and every [step] days, in time order.
///
/// Within a piece the longitude changes in one direction and by less
/// than 180°, so the change is known from the two ends.
List<(double, double)> _pieces(
  LongitudeFunction longitudeAt,
  double start,
  double end,
  double step,
) {
  final cuts = [start, ..._stationTimes(longitudeAt, start, end, step), end];
  return [
    for (var i = 0; i + 1 < cuts.length; i++)
      for (var a = cuts[i]; a < cuts[i + 1]; a += step)
        (a, a + step < cuts[i + 1] ? a + step : cuts[i + 1]),
  ];
}

/// Times in [start] … [end] when the speed of [longitudeAt] changes sign.
List<double> _stationTimes(
  LongitudeFunction longitudeAt,
  double start,
  double end,
  double step,
) {
  double speed(double t) => longitudeSpeed(longitudeAt, t);
  final result = <double>[];
  var a = start, va = speed(a);
  while (a < end) {
    final b = a + step < end ? a + step : end;
    final vb = speed(b);
    if (va < 0 != vb < 0 && va != 0) result.add(_solve(speed, a, b));
    a = b;
    va = vb;
  }
  return result;
}

/// Root of [f] in [a] … [b], where f(a) and f(b) differ in sign (or one
/// is zero): bisection with the Illinois variant of the false position
/// method, to 1e-8 day (about 1 ms).
double _solve(double Function(double) f, double a, double b) {
  var fa = f(a), fb = f(b);
  if (fa == 0) return a;
  if (fb == 0) return b;
  var side = 0;
  for (var i = 0; i < 100 && b - a > 1e-8; i++) {
    final c = (a * fb - b * fa) / (fb - fa);
    // Fall back to bisection if false position leaves the interval or
    // stalls near one end.
    final t = c > a && c < b ? c : (a + b) / 2;
    final ft = f(t);
    if (ft == 0) return t;
    if (ft < 0 == fa < 0) {
      a = t;
      fa = ft;
      if (side == -1) fb /= 2;
      side = -1;
    } else {
      b = t;
      fb = ft;
      if (side == 1) fa /= 2;
      side = 1;
    }
    if (i % 4 == 3) {
      // Every few steps a plain bisection guarantees convergence.
      final m = (a + b) / 2, fm = f(m);
      if (fm == 0) return m;
      if (fm < 0 == fa < 0) {
        a = m;
        fa = fm;
      } else {
        b = m;
        fb = fm;
      }
      side = 0;
    }
  }
  return (a + b) / 2;
}

/// Angle in degrees → −180 < x ≤ 180.
double _wrap180(double degrees) {
  final d = degrees % 360;
  return d > 180 ? d - 360 : d;
}

/// Angle in degrees → 0 ≤ x < 360.
double _normalize(double degrees) {
  final d = degrees % 360;
  return d < 0 ? d + 360 : d;
}
