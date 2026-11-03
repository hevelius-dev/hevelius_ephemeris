// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'calendar.dart';
import 'delta_t_data.dart';
import 'epochs.dart';

/// ΔT = TT − UT in seconds at [jdUt] (Julian day in UT).
///
/// Sources by epoch:
/// - February 1973 to the latest measurement: measured USNO values
///   (linear interpolation between months),
/// - years −720 … 1973: the spline of Morrison, Stephenson et al. (2016,
///   2021),
/// - outside that range: the parabola from the same work with a linear
///   correction chosen so that the value and rate of ΔT match the data at
///   the junction (as in the formulas of Espenak and Meeus).
///
/// At the junction of the spline and measurements (1973) there is a step
/// of about 0.23 s; for the Moon that is about 0.1″.
double deltaT(double jdUt) {
  final jds = _monthlyJulianDays;
  if (jdUt >= jds.first) {
    if (jdUt > jds.last) {
      return _future.at(_year(jdUt));
    }
    return _interpolateMonthly(jdUt);
  }
  final year = _year(jdUt);
  if (year >= deltaTSpline.first.$1) return _spline(year);
  return _past.at(year);
}

/// Julian day in Terrestrial Time (TT) for [jdUt].
///
/// [deltaTSeconds] overrides the [deltaT] model with your own value.
double julianDayTT(double jdUt, {double? deltaTSeconds}) =>
    jdUt + (deltaTSeconds ?? deltaT(jdUt)) / 86400;

/// Julian day in UT for [jdTT]; the inverse of [julianDayTT].
double julianDayUT(double jdTT, {double? deltaTSeconds}) {
  if (deltaTSeconds != null) return jdTT - deltaTSeconds / 86400;
  // ΔT zależy od UT, którego szukamy; ΔT zmienia się powoli, więc
  // kilka przybliżeń wystarcza z ogromnym zapasem.
  var jdUt = jdTT;
  for (var i = 0; i < 3; i++) {
    jdUt = jdTT - deltaT(jdUt) / 86400;
  }
  return jdUt;
}

/// Rok z ułamkiem; dokładność do kilku dni wystarcza, bo ΔT zmienia się
/// powoli.
double _year(double jd) => 2000 + (jd - j2000) / 365.25;

/// Parabola długookresowa ΔT = −320 + 32,5·u², u = (rok − 1825)/100
/// (Stephenson i in. 2016, równanie 4.1).
double _parabola(double year) {
  final u = (year - 1825) / 100;
  return -320 + 32.5 * u * u;
}

/// Pochodna [_parabola] w sekundach na rok.
double _parabolaRate(double year) => 2 * 32.5 * (year - 1825) / 10000;

/// Parabola dołączona do danych w roku [year0]: ΔT(rok) = parabola(rok)
/// + [offset] + [slope]·(rok − [year0]).
class _Extrapolation {
  final double year0, offset, slope;

  /// Dobiera poprawkę tak, by w [year0] ΔT miało wartość [value]
  /// i tempo zmian [rate] (s/rok).
  _Extrapolation(this.year0, double value, double rate)
    : offset = value - _parabola(year0),
      slope = rate - _parabolaRate(year0);

  double at(double year) => _parabola(year) + offset + slope * (year - year0);
}

double _spline(double year) {
  for (final (from, to, a0, a1, a2, a3) in deltaTSpline) {
    if (year < to) {
      final t = (year - from) / (to - from);
      return a0 + t * (a1 + t * (a2 + t * a3));
    }
  }
  // Rok na samym końcu tabeli (nie powinno się zdarzyć – wcześniej
  // przejmują pomiary USNO).
  final (_, _, a0, a1, a2, a3) = deltaTSpline.last;
  return a0 + a1 + a2 + a3;
}

final List<double> _monthlyJulianDays = [
  for (final (year, month, _) in deltaTMonthly) julianDay(year, month, 1),
];

double _interpolateMonthly(double jdUt) {
  final jds = _monthlyJulianDays;
  // Wyszukiwanie binarne przedziału [jds[lo], jds[lo + 1]].
  var lo = 0, hi = jds.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) >> 1;
    if (jds[mid] <= jdUt) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final a = deltaTMonthly[lo].$3, b = deltaTMonthly[hi].$3;
  final t = (jdUt - jds[lo]) / (jds[hi] - jds[lo]);
  return a + t * (b - a);
}

/// Przed rokiem −720: łączenie z początkiem spline.
final _Extrapolation _past = () {
  final (from, to, a0, a1, _, _) = deltaTSpline.first;
  // Pochodna wielomianu przedziału w jego początku: a1 / długość.
  return _Extrapolation(from, a0, a1 / (to - from));
}();

/// Po ostatnim pomiarze: łączenie z jego wartością i średnim tempem
/// z ostatnich 24 miesięcy (pełne lata znoszą wahania sezonowe).
final _Extrapolation _future = () {
  final last = deltaTMonthly.length - 1;
  final rate = (deltaTMonthly[last].$3 - deltaTMonthly[last - 24].$3) / 2;
  return _Extrapolation(
    _year(_monthlyJulianDays[last]),
    deltaTMonthly[last].$3,
    rate,
  );
}();
