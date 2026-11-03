// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import '../math/vector3.dart';
import '../reduction/apparent.dart';
import '../reduction/tdb.dart';
import '../spk/spk_ephemeris.dart';
import '../time/epochs.dart';
import '../spk/ephemeris.dart';

/// The astronomical unit in km (IAU 2012 Resolution B2).
const double astronomicalUnit = 149597870.7;

/// The Julian year in days.
const double daysPerJulianYear = 365.25;

/// Radiany na milisekundę kątową.
const double _mas = math.pi / (180 * 3600 * 1000);

/// A star (or another object outside the solar system) from a catalogue:
/// ICRS position at epoch J2000.0 and space motion.
class FixedStar {
  const FixedStar({
    required this.name,
    required this.designation,
    required this.rightAscension,
    required this.declination,
    this.properMotionRa = 0,
    this.properMotionDec = 0,
    this.parallax = 0,
    this.radialVelocity = 0,
    this.magnitude,
  });

  /// Traditional name (may be empty).
  final String name;

  /// Designation in IAU notation, e.g. "alf Tau" (as in
  /// data/stars/jasne_gwiazdy.csv).
  final String designation;

  /// ICRS right ascension and declination at epoch J2000.0, in degrees.
  final double rightAscension, declination;

  /// Proper motion in mas/year: in right ascension multiplied by cos δ
  /// (μα*) and in declination (μδ).
  final double properMotionRa, properMotionDec;

  /// Parallax in mas; 0 if unknown (object "infinitely far"). A negative
  /// value (measurement error for distant stars) is treated as 0 – as a
  /// negative distance it would reverse the direction.
  final double parallax;

  /// Paralaksa używana w obliczeniach, w radianach (nieujemna).
  double get _parallaxRadians => math.max(parallax, 0) * _mas;

  /// Radial velocity in km/s (positive – receding).
  final double radialVelocity;

  /// V magnitude; null if unknown.
  final double? magnitude;

  /// Stars from a file in the format of data/stars/jasne_gwiazdy.csv (see
  /// tool/build_fixed_stars.dart). Missing proper motion, parallax and
  /// radial velocity are taken as 0; so is a negative parallax
  /// (measurement error for distant objects).
  static List<FixedStar> parseCsv(String text) {
    final lines = [
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty && !line.startsWith('#')) line,
    ];
    final header = _fields(lines.first);
    int column(String name) => header.indexOf(name);
    final (name, designation, ra, dec, pmra, pmdec, plx, rv, v) = (
      column('nazwa'),
      column('oznaczenie'),
      column('ra'),
      column('dec'),
      column('pmra'),
      column('pmdec'),
      column('plx'),
      column('rv'),
      column('v'),
    );
    return [
      for (final line in lines.skip(1))
        if (_fields(line) case final f)
          FixedStar(
            name: f[name],
            designation: f[designation],
            rightAscension: double.parse(f[ra]),
            declination: double.parse(f[dec]),
            properMotionRa: double.tryParse(f[pmra]) ?? 0,
            properMotionDec: double.tryParse(f[pmdec]) ?? 0,
            parallax: math.max(double.tryParse(f[plx]) ?? 0, 0),
            radialVelocity: double.tryParse(f[rv]) ?? 0,
            magnitude: double.tryParse(f[v]),
          ),
    ];
  }

  /// Direction to the star from the solar system barycentre at [jdTDB],
  /// scaled by parallax: the vector r/d₀ (d₀ – distance at the catalogue
  /// epoch), in the ICRS.
  ///
  /// Space motion is linear: r(t) = r₀ + v·(t − t₀), where v combines the
  /// proper motion (perpendicular to the direction) and the radial
  /// velocity (along it). After dividing by d₀ zero parallax is not a
  /// special case – the radial velocity then drops out of the direction
  /// and the proper motion remains.
  Vector3 barycentricScaled(double jdTDB) {
    final a = rightAscension * math.pi / 180;
    final d = declination * math.pi / 180;
    final (sa, ca, sd, cd) = (
      math.sin(a),
      math.cos(a),
      math.sin(d),
      math.cos(d),
    );
    final u = Vector3(cd * ca, cd * sa, sd);
    final p = Vector3(-sa, ca, 0);
    final q = Vector3(-sd * ca, -sd * sa, cd);
    // Prędkość radialna jako zmiana odległości względnej na rok:
    // vr / d₀ = vr · ϖ / AU (ϖ w radianach).
    final radial =
        radialVelocity *
        86400 *
        daysPerJulianYear /
        astronomicalUnit *
        _parallaxRadians;
    final years = (jdTDB - j2000) / daysPerJulianYear;
    return u +
        (p * (properMotionRa * _mas) +
                q * (properMotionDec * _mas) +
                u * radial) *
            years;
  }

  @override
  String toString() => 'FixedStar($name, $designation)';
}

/// Geocentric direction (unit vector, GCRS/ICRF) to [star] at [jdTT] and
/// its distance in km (infinite for zero parallax).
///
/// In order: space motion since the catalogue epoch, annual parallax
/// (shift from the solar system barycentre to the Earth's centre),
/// deflection of light by the Sun and aberration – the last two as set
/// in [corrections]. No light-time: the catalogue gives the star as it
/// is seen.
({Vector3 direction, double distance}) fixedStarDirection(
  Ephemeris ephemeris,
  FixedStar star,
  double jdTT, {
  Corrections corrections = const Corrections(),
}) {
  final jdTDB = jdTT + tdbMinusTT(jdTT) / 86400;
  final et = (jdTDB - j2000) * 86400;
  final earth = ephemeris.state(Naif.earth, Naif.solarSystemBarycenter, et);
  final parallax = star._parallaxRadians;

  // r/d₀ − E/d₀, a 1/d₀ = ϖ/AU.
  final geocentric =
      star.barycentricScaled(jdTDB) -
      earth.position * (parallax / astronomicalUnit);
  var direction = geocentric.unit;
  final distance = parallax == 0
      ? double.infinity
      : geocentric.length * astronomicalUnit / parallax;

  if (corrections.deflection) {
    final sun = ephemeris
        .state(Naif.sun, Naif.solarSystemBarycenter, et)
        .position;
    final sunFromEarth = sun - earth.position;
    if (!onSolarDisk(direction, sunFromEarth)) {
      // Od Słońca gwiazda leży praktycznie w tym samym kierunku co od
      // Ziemi; poprawka (E − S)/d₀ ma znaczenie tylko dla najbliższych.
      final sunToStar =
          geocentric - sunFromEarth * (parallax / astronomicalUnit);
      direction = deflectLight(direction, sunToStar, sunFromEarth * -1);
    }
  }
  if (corrections.aberration) {
    direction = aberrate(direction, earth.velocity * (1 / speedOfLight));
  }
  return (direction: direction, distance: distance);
}

/// Position of [star] on the ecliptic of date [jdTT] as seen from the
/// Earth's centre (apparent, like planets in [geocentricEcliptic]).
EclipticPosition fixedStarEcliptic(
  Ephemeris ephemeris,
  FixedStar star,
  double jdTT, {
  Corrections corrections = const Corrections(),
}) {
  final (:direction, :distance) = fixedStarDirection(
    ephemeris,
    star,
    jdTT,
    corrections: corrections,
  );
  return eclipticOfDate(direction, distance, jdTT, corrections: corrections);
}

/// Pola wiersza CSV (cudzysłowy, "" jako cudzysłów).
List<String> _fields(String line) {
  final fields = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quoted) {
      if (ch == '"' && i + 1 < line.length && line[i + 1] == '"') {
        field.write('"');
        i++;
      } else if (ch == '"') {
        quoted = false;
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      fields.add(field.toString());
      field.clear();
    } else {
      field.write(ch);
    }
  }
  fields.add(field.toString().trimRight());
  return fields;
}
