// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import '../math/vector3.dart';
import 'precession_nutation.dart';

// Długookresowa precesja (±200 000 lat od J2000):
// J. Vondrák, N. Capitaine, P. Wallace, „New precession expressions, valid
// for long time intervals”, A&A 534, A22 (2011), z poprawką A&A 541, C1
// (2012). Współczynniki w sekundach łuku, okresy w stuleciach juliańskich.

/// Wyraz okresowy: okres (stulecia), C i S dla dwóch wielkości.
typedef _Term = (double period, double c1, double s1, double c2, double s2);

/// Tabela 1: P_A, Q_A (C₇ dla Q_A = 198,296701 wg poprawki 2012).
const List<_Term> _ecliptic = [
  (708.15, -5486.751211, 667.666730, -684.661560, -5523.863691),
  (2309.00, -17.127623, -2354.886252, 2446.283880, -549.747450),
  (1620.00, -617.517403, -428.152441, 399.671049, -310.998056),
  (492.20, 413.442940, 376.202861, -356.652376, 421.535876),
  (1183.00, 78.614193, 184.778874, -186.387003, -36.776172),
  (622.00, -180.732815, 335.321713, -316.800070, -145.278396),
  (882.00, -87.676083, -185.138669, 198.296701, -34.744450),
  (547.00, 46.140315, -120.972830, 101.135679, 22.885731),
];

/// Tabela 2: X_A, Y_A.
const List<_Term> _equator = [
  (256.75, -819.940624, 81491.287984, 75004.344875, 1558.515853),
  (708.15, -8444.676815, 787.163481, 624.033993, 7774.939698),
  (274.20, 2600.009459, 1251.296102, 1251.136893, -2219.534038),
  (241.45, 2755.175630, -1257.950837, -1102.212834, -2523.969396),
  (2309.00, -167.659835, -2966.799730, -2660.664980, 247.850422),
  (492.20, 871.855056, 639.744522, 699.291817, -846.485643),
  (396.10, 44.769698, 131.600209, 153.167220, -1393.124055),
  (288.90, -512.313065, -445.040117, -950.865637, 368.526116),
  (231.10, -819.415595, 584.522874, 499.754645, 749.045012),
  (1610.00, -538.071099, -89.756563, -145.188210, 444.704518),
  (620.00, -189.793622, 524.429630, 558.116553, 235.934465),
  (157.87, -402.922932, -13.549067, -23.923029, 374.049623),
  (220.30, 179.516345, -210.157124, -165.405086, -171.330180),
  (1200.00, -9.814756, -44.919798, 9.344131, -22.899655),
];

/// Tabela 9: s_A (druga para kolumn nieużywana).
const List<_Term> _cioLocator = [
  (256.75, 861.759585, 17367.906013, 0, 0),
  (402.79, -3534.781660, -206.865955, 0, 0),
  (708.15, -1757.969632, 937.453020, 0, 0),
  (288.92, -379.971514, 794.788562, 0, 0),
  (274.20, 808.400066, 101.350197, 0, 0),
  (537.22, 528.646661, -509.801031, 0, 0),
  (241.45, 566.991239, -302.310637, 0, 0),
  (729.81, -164.251097, -538.092166, 0, 0),
  (483.00, 239.102099, 383.848135, 0, 0),
  (438.22, -239.146933, -373.925805, 0, 0),
  (128.38, -61.768986, -344.946642, 0, 0),
  (1552.00, -279.716974, -85.660616, 0, 0),
  (2022.00, -96.750819, -132.781674, 0, 0),
  (230.44, -57.265608, 38.452480, 0, 0),
];

/// Wielomian trzeciego stopnia + wyrazy okresowe (sekundy łuku);
/// [second] wybiera drugą parę kolumn tabeli.
double _series(
  double t,
  List<double> polynomial,
  List<_Term> terms, {
  bool second = false,
}) {
  var sum =
      polynomial[0] +
      t * (polynomial[1] + t * (polynomial[2] + t * polynomial[3]));
  for (final (period, c1, s1, c2, s2) in terms) {
    final a = 2 * math.pi * t / period;
    sum += second
        ? c2 * math.cos(a) + s2 * math.sin(a)
        : c1 * math.cos(a) + s1 * math.sin(a);
  }
  return sum;
}

/// Średnie nachylenie ekliptyki J2000 ε₀ = 84 381,406″ (IAU 2006).
const double _epsilon0 = 84381.406 * arcsecond;

/// P_A i Q_A (radiany), równ. (8).
(double, double) longTermEclipticPoleAngles(double t) => (
  _series(t, [5851.607687, -0.1189000, -0.00028913, 101e-9], _ecliptic) *
      arcsecond,
  _series(
        t,
        [-1600.886300, 1.1689818, -0.00000020, -437e-9],
        _ecliptic,
        second: true,
      ) *
      arcsecond,
);

/// X_A i Y_A (radiany), równ. (9).
(double, double) longTermEquatorPoleAngles(double t) => (
  _series(t, [5453.282155, 0.4252841, -0.00037173, -152e-9], _equator) *
      arcsecond,
  _series(
        t,
        [-73750.930350, -0.7675452, -0.00018725, 231e-9],
        _equator,
        second: true,
      ) *
      arcsecond,
);

/// Pole of the mean ecliptic of date at [t] (Julian centuries TT since
/// J2000) as a unit vector in the J2000 mean equator and equinox frame;
/// long-term model valid for ±200 000 years (Vondrák, Capitaine and
/// Wallace 2011).
Vector3 longTermEclipticPole(double t) {
  final (p, q) = longTermEclipticPoleAngles(t);
  final z = math.sqrt(math.max(1 - p * p - q * q, 0));
  final s = math.sin(_epsilon0), c = math.cos(_epsilon0);
  return Vector3(p, -q * c - z * s, -q * s + z * c);
}

/// Pole of the mean equator of date at [t] as a unit vector in the J2000
/// mean equator and equinox frame (long-term model, as
/// [longTermEclipticPole]).
Vector3 longTermEquatorPole(double t) {
  final (x, y) = longTermEquatorPoleAngles(t);
  final w = x * x + y * y;
  return Vector3(x, y, w < 1 ? math.sqrt(1 - w) : 0);
}

/// CIO locator s_A due to precession at [t] (radians), equation (26) of
/// the long-term model.
double longTermCioLocator(double t) =>
    _series(t, [3566.723572, -414.3015011, 0.00085448, 365e-9], _cioLocator) *
    arcsecond;

// --- Użycie w silniku: ekliptyka daty, nachylenie, czas gwiazdowy. ---

/// Bieguny (równika, ekliptyki) dla ostatnich chwil – te same t liczymy
/// wielokrotnie (ciała, prędkości, czas gwiazdowy).
const int _cacheSize = 8;
final List<double> _cacheT = List.filled(_cacheSize, double.nan);
final List<(Vector3, Vector3)?> _cachePoles = List.filled(_cacheSize, null);
var _cacheNext = 0;

(Vector3, Vector3) _poles(double t) {
  for (var i = 0; i < _cacheSize; i++) {
    if (_cacheT[i] == t) return _cachePoles[i]!;
  }
  if (t.abs() > _validCenturies) {
    throw ArgumentError(
      'Long-term precession is valid for ±200 000 years from J2000 '
      '(t = $t centuries)',
    );
  }
  final poles = (longTermEquatorPole(t), longTermEclipticPole(t));
  _cacheT[_cacheNext] = t;
  _cachePoles[_cacheNext] = poles;
  _cacheNext = (_cacheNext + 1) % _cacheSize;
  return poles;
}

/// Zakres ważności modelu (stulecia od J2000), A&A 534, A22, rozdz. 7.
const double _validCenturies = 2000;

/// Mean obliquity of the ecliptic of date (radians): the angle between
/// the long-term mean equator and ecliptic poles.
double longTermMeanObliquity(double t) {
  final (n, k) = _poles(t);
  return math.atan2(n.cross(k).length, n.dot(k));
}

/// Przejście GCRS → średni równik i równonoc J2000 („frame bias”): macierz
/// z precesji IAU 2006 w J2000 (kąty Fukushimy–Williamsa w t = 0 zawierają
/// bias), złożona z odwrotnością obrotu J2000 równik → ekliptyka.
final List<Vector3> _biasColumns = () {
  final fw = fukushimaWilliams(0);
  final e0 = _eclipticFrame(0);
  Vector3 column(Vector3 e) {
    final u = e.rotateZ(fw.gamma).rotateX(fw.phi).rotateZ(-fw.psi);
    return e0[0] * u.x + e0[1] * u.y + e0[2] * u.z;
  }

  return [
    column(Vector3(1, 0, 0)),
    column(Vector3(0, 1, 0)),
    column(Vector3(0, 0, 1)),
  ];
}();

Vector3 _gcrsToMeanJ2000(Vector3 r) =>
    _biasColumns[0] * r.x + _biasColumns[1] * r.y + _biasColumns[2] * r.z;

/// Wiersze macierzy: średni równik J2000 → średnia ekliptyka daty; oś x
/// – punkt równonocy (n × k), oś z – biegun ekliptyki (równ. 23).
List<Vector3> _eclipticFrame(double t) {
  final (n, k) = _poles(t);
  final x = n.cross(k).unit;
  return [x, k.cross(x), k];
}

/// Transforms vector [r] from the GCRS to the mean ecliptic and equinox
/// of date at [t], with the long-term precession model.
Vector3 longTermGcrsToMeanEclipticOfDate(Vector3 r, double t) {
  final m = _gcrsToMeanJ2000(r);
  final f = _eclipticFrame(t);
  return Vector3(f[0].dot(m), f[1].dot(m), f[2].dot(m));
}

/// Inverse of [longTermGcrsToMeanEclipticOfDate]: vector [v] in the mean
/// ecliptic and equinox of date at [t] back to the GCRS.
Vector3 longTermMeanEclipticOfDateToGcrs(Vector3 v, double t) {
  final f = _eclipticFrame(t);
  final m = f[0] * v.x + f[1] * v.y + f[2] * v.z;
  return Vector3(
    _biasColumns[0].dot(m),
    _biasColumns[1].dot(m),
    _biasColumns[2].dot(m),
  );
}

/// Greenwich mean sidereal time minus the Earth rotation angle at [t]
/// (radians): the angle from the CIO to the mean equinox of date along
/// the equator, from the long-term precession model.
///
/// The CIO is carried along the equator without rotation (its kinematic
/// definition) from its J2000 position, the GCRS x axis, as the equator
/// pole moves; tabulated on first use every 0.01 century and interpolated.
double longTermGmstMinusEra(double t) {
  final (n, k) = _poles(t);
  final equinox = n.cross(k).unit;
  final cio = _cio.at(t);
  return -math.atan2(cio.cross(equinox).dot(n), cio.dot(equinox));
}

final _cio = _CioTable();

/// Położenia CIO w układzie średnim J2000 co [_step] stulecia, w obie
/// strony od J2000, liczone w miarę potrzeb.
class _CioTable {
  static const double _step = 0.01;

  // Indeks i: t = ±i·krok. Ostatni biegun każdej gałęzi do dalszego
  // przenoszenia.
  final List<Vector3> _forward = [], _backward = [];
  late Vector3 _forwardPole, _backwardPole;

  _CioTable() {
    // W J2000 CIO leży (z dokładnością do s ≈ 0,0001″) na osi x GCRS.
    final start = _gcrsToMeanJ2000(Vector3(1, 0, 0));
    _forward.add(start);
    _backward.add(start);
    _forwardPole = _backwardPole = longTermEquatorPole(0);
  }

  Vector3 at(double t) {
    final position = t.abs() / _step;
    final i = position.floor();
    final branch = t >= 0 ? _forward : _backward;
    while (branch.length <= i + 1) {
      final sign = t >= 0 ? 1 : -1;
      final next = longTermEquatorPole(sign * branch.length * _step);
      final previous = t >= 0 ? _forwardPole : _backwardPole;
      branch.add(_carry(branch.last, previous, next));
      if (t >= 0) {
        _forwardPole = next;
      } else {
        _backwardPole = next;
      }
    }
    // Interpolacja liniowa i rzut na równik daty (błąd ok. 0,00001″).
    final f = position - i;
    final v = branch[i] * (1 - f) + branch[i + 1] * f;
    final (n, _) = _poles(t);
    return (v - n * v.dot(n)).unit;
  }

  /// Obrót przenoszący biegun [from] na [to] (wokół from × to, wzór
  /// Rodriguesa) zastosowany do [x] – przeniesienie bez obrotu wokół
  /// bieguna.
  static Vector3 _carry(Vector3 x, Vector3 from, Vector3 to) {
    final axis = from.cross(to);
    final s = axis.length, c = from.dot(to);
    if (s == 0) return x;
    final k = axis * (1 / s);
    return x * c + k.cross(x) * s + k * (k.dot(x) * (1 - c));
  }
}
