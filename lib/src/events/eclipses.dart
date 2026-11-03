// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import '../math/vector3.dart';
import '../reduction/apparent.dart';
import '../reduction/horizontal.dart';
import '../spk/spk_ephemeris.dart';
import 'lunar_phases.dart';
import 'rise_set.dart';
import '../spk/ephemeris.dart';

/// Kind of a solar eclipse.
enum SolarEclipseType { partial, annular, total, hybrid }

/// Kind of a lunar eclipse.
enum LunarEclipseType { penumbral, partial, total }

/// How the Earth's shadow is enlarged for the atmosphere in lunar
/// eclipse calculations.
enum ShadowEnlargement {
  /// Danjon (1951): the Earth's radius, i.e. the Moon's parallax, is
  /// increased by about 1/85 – as in the French Connaissance des Temps
  /// and the NASA Five Millennium Canon (Espenak and Meeus).
  danjon,

  /// Chauvenet (1891): the shadow radii are increased by 1/50 – the
  /// traditional convention of the Astronomical Almanac. Umbral
  /// magnitudes come out about 0.006 larger, penumbral about 0.026.
  chauvenet,
}

/// A solar eclipse, seen from the Earth as a whole.
class SolarEclipse {
  /// Greatest eclipse: the moment the axis of the Moon's shadow passes
  /// closest to the Earth's centre. Julian day in Terrestrial Time.
  final double jdTT;

  final SolarEclipseType type;

  /// Whether the shadow axis meets the Earth (a line of central eclipse
  /// exists). Total and annular eclipses can be non-central when only
  /// the edge of the umbral cone touches the polar regions.
  final bool central;

  /// Eclipse magnitude at greatest eclipse: for a partial eclipse the
  /// fraction of the Sun's diameter covered at the point of the Earth
  /// closest to the shadow axis, for a central one the ratio of the
  /// apparent diameters of the Moon and the Sun.
  final double magnitude;

  /// Least distance of the shadow axis from the Earth's centre in
  /// equatorial Earth radii; positive when the axis passes north of the
  /// centre.
  final double gamma;

  /// Apparent geocentric ecliptic longitude of the Sun at greatest
  /// eclipse, in degrees.
  final double longitude;

  const SolarEclipse({
    required this.jdTT,
    required this.type,
    required this.central,
    required this.magnitude,
    required this.gamma,
    required this.longitude,
  });

  @override
  String toString() =>
      'SolarEclipse($jdTT, ${type.name}, magnitude $magnitude, '
      'gamma $gamma)';
}

/// A lunar eclipse.
class LunarEclipse {
  /// Greatest eclipse: the moment the Moon's centre is closest to the axis
  /// of the Earth's shadow. Julian day in Terrestrial Time.
  final double jdTT;

  final LunarEclipseType type;

  /// Fraction of the Moon's diameter inside the umbra at greatest eclipse
  /// (negative when the Moon misses the umbra).
  final double umbralMagnitude;

  /// Fraction of the Moon's diameter inside the penumbra at greatest
  /// eclipse.
  final double penumbralMagnitude;

  /// Least distance of the Moon's centre from the shadow axis in
  /// equatorial Earth radii; positive when the Moon passes north of the
  /// axis.
  final double gamma;

  /// Apparent geocentric ecliptic longitude of the Moon at greatest
  /// eclipse, in degrees.
  final double longitude;

  /// Contacts (Julian days in Terrestrial Time), the same for the whole
  /// Earth: the Moon's limb touches the penumbra from outside (P1, P4) and
  /// the umbra from outside (U1, U4) and from inside (U2, U3). U1 and U4
  /// are null for a penumbral eclipse, U2 and U3 unless it is total.
  final double penumbralBegin, penumbralEnd;
  final double? partialBegin, totalBegin, totalEnd, partialEnd;

  const LunarEclipse({
    required this.jdTT,
    required this.type,
    required this.umbralMagnitude,
    required this.penumbralMagnitude,
    required this.gamma,
    required this.longitude,
    required this.penumbralBegin,
    required this.partialBegin,
    required this.totalBegin,
    required this.totalEnd,
    required this.partialEnd,
    required this.penumbralEnd,
  });

  @override
  String toString() =>
      'LunarEclipse($jdTT, ${type.name}, umbral $umbralMagnitude, '
      'penumbral $penumbralMagnitude)';
}

/// The Sun at one moment of a solar eclipse as seen from a place.
class SolarEclipseContact {
  /// Julian day in Terrestrial Time.
  final double jdTT;

  /// Topocentric geometric altitude of the Sun's centre (no refraction),
  /// degrees.
  final double altitude;

  /// Azimuth of the Sun, degrees from north through east.
  final double azimuth;

  /// Position angle of the Moon's centre from the Sun's centre, degrees
  /// from the north point of the Sun's disk through east. At first
  /// contact it shows where the Moon touches the Sun, at fourth contact
  /// where it leaves (add 180° for the opposite side).
  final double positionAngle;

  const SolarEclipseContact({
    required this.jdTT,
    required this.altitude,
    required this.azimuth,
    required this.positionAngle,
  });

  /// Whether the Sun is above the horizon: its centre higher than
  /// [sunHorizonAltitude] (upper limb on the horizon with standard
  /// refraction).
  bool get visible => altitude > sunHorizonAltitude;

  @override
  String toString() =>
      'SolarEclipseContact($jdTT, altitude $altitude, azimuth $azimuth, '
      'P $positionAngle)';
}

/// Local circumstances of a solar eclipse: how it looks from one place.
///
/// The geometry is computed whether or not the Sun is above the horizon;
/// [SolarEclipseContact.visible] tells which phases can be seen.
class LocalSolarEclipse {
  /// Partial, annular or total – at this place (never hybrid).
  final SolarEclipseType type;

  /// Start of the partial phase (first contact).
  final SolarEclipseContact firstContact;

  /// Start and end of the total or annular phase (second and third
  /// contact); null for a partial eclipse.
  final SolarEclipseContact? secondContact, thirdContact;

  /// Maximum eclipse: the Moon's centre closest to the Sun's centre.
  final SolarEclipseContact maximum;

  /// End of the partial phase (fourth contact).
  final SolarEclipseContact fourthContact;

  /// Fraction of the Sun's diameter covered at maximum eclipse (at least
  /// 1 for a total eclipse).
  final double magnitude;

  /// Fraction of the Sun's disk area covered at maximum eclipse.
  final double obscuration;

  /// Ratio of the apparent diameters of the Moon and the Sun at maximum.
  final double diameterRatio;

  const LocalSolarEclipse({
    required this.type,
    required this.firstContact,
    required this.secondContact,
    required this.thirdContact,
    required this.maximum,
    required this.fourthContact,
    required this.magnitude,
    required this.obscuration,
    required this.diameterRatio,
  });

  /// Duration of the total or annular phase in seconds; null for a
  /// partial eclipse.
  double? get centralDuration => secondContact == null
      ? null
      : (thirdContact!.jdTT - secondContact!.jdTT) * 86400;

  @override
  String toString() =>
      'LocalSolarEclipse(${type.name}, magnitude $magnitude, '
      'maximum ${maximum.jdTT})';
}

/// The Moon at one moment of a lunar eclipse as seen from a place.
class LunarEclipseContact {
  /// Julian day in Terrestrial Time.
  final double jdTT;

  /// Topocentric geometric altitude of the Moon's centre (parallax
  /// included, no refraction), degrees.
  final double altitude;

  /// Azimuth of the Moon, degrees from north through east.
  final double azimuth;

  /// Whether the Moon is above the horizon: its upper limb above the
  /// horizon with standard refraction (centre higher than −34′ minus the
  /// Moon's semidiameter).
  final bool visible;

  const LunarEclipseContact({
    required this.jdTT,
    required this.altitude,
    required this.azimuth,
    required this.visible,
  });

  @override
  String toString() =>
      'LunarEclipseContact($jdTT, altitude $altitude, azimuth $azimuth'
      '${visible ? '' : ', below horizon'})';
}

/// A lunar eclipse as seen from one place: the Moon's position at each
/// contact and at greatest eclipse. The times are those of the
/// [LunarEclipse] – the same for the whole Earth.
class LocalLunarEclipse {
  final LunarEclipse eclipse;
  final LunarEclipseContact penumbralBegin;
  final LunarEclipseContact? partialBegin, totalBegin;
  final LunarEclipseContact maximum;
  final LunarEclipseContact? totalEnd, partialEnd;
  final LunarEclipseContact penumbralEnd;

  const LocalLunarEclipse({
    required this.eclipse,
    required this.penumbralBegin,
    required this.partialBegin,
    required this.totalBegin,
    required this.maximum,
    required this.totalEnd,
    required this.partialEnd,
    required this.penumbralEnd,
  });

  /// Contacts and greatest eclipse in time order (absent phases left out).
  List<LunarEclipseContact> get all => [
    penumbralBegin,
    ?partialBegin,
    ?totalBegin,
    maximum,
    ?totalEnd,
    ?partialEnd,
    penumbralEnd,
  ];
}

/// Mean radius of the Moon in km (IAU 2015).
const double moonRadius = 1737.4;

/// Ratio of the Moon's radius to the Earth's equatorial radius used for
/// the penumbral cone of solar eclipses (k = 0.2725076, IAU 1982).
const double moonRadiusRatio = 0.2725076;

/// Smaller ratio used for the umbral cone of solar eclipses
/// (k = 0.2722810), which allows for the valleys on the lunar limb.
const double moonRadiusRatioUmbra = 0.2722810;

/// Ecliptic latitude of the Moon at New or Full Moon beyond which no
/// eclipse is possible, with a margin (degrees).
const double _latitudeLimit = 1.8;

/// Solar eclipses with greatest eclipse in [startJdTT] … [endJdTT].
List<SolarEclipse> solarEclipses(
  Ephemeris ephemeris,
  double startJdTT,
  double endJdTT,
) {
  final result = <SolarEclipse>[];
  for (final p in lunarPhases(ephemeris, startJdTT - 1, endJdTT + 1)) {
    if (p.phase != MoonPhase.newMoon) continue;
    final beta = geocentricEcliptic(ephemeris, Naif.moon, p.jdTT).latitude;
    if (beta.abs() > _latitudeLimit) continue;
    final e = _solarEclipse(ephemeris, p.jdTT);
    if (e != null && e.jdTT >= startJdTT && e.jdTT <= endJdTT) result.add(e);
  }
  return result;
}

/// Lunar eclipses with greatest eclipse in [startJdTT] … [endJdTT],
/// penumbral ones included.
List<LunarEclipse> lunarEclipses(
  Ephemeris ephemeris,
  double startJdTT,
  double endJdTT, {
  ShadowEnlargement enlargement = ShadowEnlargement.danjon,
}) {
  final result = <LunarEclipse>[];
  for (final p in lunarPhases(ephemeris, startJdTT - 1, endJdTT + 1)) {
    if (p.phase != MoonPhase.fullMoon) continue;
    final beta = geocentricEcliptic(ephemeris, Naif.moon, p.jdTT).latitude;
    if (beta.abs() > _latitudeLimit) continue;
    final e = _lunarEclipse(ephemeris, p.jdTT, enlargement);
    if (e != null && e.jdTT >= startJdTT && e.jdTT <= endJdTT) result.add(e);
  }
  return result;
}

/// Local circumstances of solar eclipse [eclipse] for a place at
/// geodetic [latitude] and [longitude] (degrees, east positive) and
/// [height] above sea level in metres; null if the eclipse is not seen
/// there at all (the penumbra misses the place).
///
/// The Moon is a sphere with the radii of the NASA Five Millennium Canon
/// ([moonRadiusRatio], and [moonRadiusRatioUmbra] for the second and third
/// contacts), so the limb profile is ignored: contacts II and III may
/// differ from observed ones by a second or two. Polar motion is ignored.
///
/// [deltaTSeconds] overrides the ΔT model (it sets the Earth's
/// orientation at a given moment of Terrestrial Time), e.g. to reproduce
/// predictions made with a different ΔT.
LocalSolarEclipse? localSolarEclipse(
  Ephemeris ephemeris,
  SolarEclipse eclipse, {
  required double latitude,
  required double longitude,
  double height = 0,
  double? deltaTSeconds,
}) {
  final observer = Observer(
    latitude: latitude,
    longitude: longitude,
    height: height,
  );
  _Local at(double t) =>
      _Local(_shadow(ephemeris, t), observer, t, deltaTSeconds);

  // Maksimum lokalne: najmniejsza odległość obserwatora od osi cienia.
  // Całe zaćmienie trwa najwyżej ok. 6 h, więc ±0,2 doby wystarcza.
  final start = eclipse.jdTT - 0.2, end = eclipse.jdTT + 0.2;
  final tMax = _minimize((t) => at(t).m, start, end);
  final max = at(tMax);
  if (max.m >= max.l1) return null;

  // Obserwator na brzegu półcienia (I, IV) i cienia (II, III).
  double outer(double t) {
    final l = at(t);
    return l.m - l.l1;
  }

  double inner(double t) {
    final l = at(t);
    return l.m - l.l2.abs();
  }

  final first = _root(outer, start, tMax);
  final fourth = _root(outer, tMax, end);
  double? second, third;
  if (max.m < max.l2.abs()) {
    second = _root(inner, first, tMax);
    third = _root(inner, tMax, fourth);
  }

  SolarEclipseContact contact(double t) {
    final local = at(t);
    final sun = horizontalPosition(
      ephemeris,
      Naif.sun,
      observer,
      t,
      deltaTSeconds: deltaTSeconds,
    );
    // Kierunek od obserwatora do osi cienia na płaszczyźnie podstawowej
    // = kierunek od środka Słońca do środka Księżyca na niebie.
    final p = math.atan2(local.u, local.v) / _degree;
    return SolarEclipseContact(
      jdTT: t,
      altitude: sun.altitude,
      azimuth: sun.azimuth,
      positionAngle: p < 0 ? p + 360 : p,
    );
  }

  // W jednostkach promienia Słońca: Księżyc ma promień r, odległość
  // środków c = 2m/(L1 + L2) (c = 1 + r przy m = L1, c = |1 − r| przy
  // m = |L2|).
  final sum = max.l1 + max.l2;
  final r = (max.l1 - max.l2) / sum;
  final c = 2 * max.m / sum;
  return LocalSolarEclipse(
    type: second == null
        ? SolarEclipseType.partial
        : max.l2 < 0
        ? SolarEclipseType.total
        : SolarEclipseType.annular,
    firstContact: contact(first),
    secondContact: second == null ? null : contact(second),
    thirdContact: third == null ? null : contact(third),
    maximum: contact(tMax),
    fourthContact: contact(fourth),
    magnitude: (max.l1 - max.m) / sum,
    obscuration: _overlap(r, c),
    diameterRatio: r,
  );
}

/// The Moon's position at each contact of lunar eclipse [eclipse] for a
/// place at geodetic [latitude] and [longitude] (degrees, east positive)
/// and [height] above sea level in metres. [deltaTSeconds] overrides the
/// ΔT model.
LocalLunarEclipse localLunarEclipse(
  Ephemeris ephemeris,
  LunarEclipse eclipse, {
  required double latitude,
  required double longitude,
  double height = 0,
  double? deltaTSeconds,
}) {
  final observer = Observer(
    latitude: latitude,
    longitude: longitude,
    height: height,
  );

  LunarEclipseContact contact(double t) {
    final moon = horizontalPosition(
      ephemeris,
      Naif.moon,
      observer,
      t,
      deltaTSeconds: deltaTSeconds,
    );
    final semidiameter = math.asin(moonRadius / moon.distance) / _degree;
    return LunarEclipseContact(
      jdTT: t,
      altitude: moon.altitude,
      azimuth: moon.azimuth,
      visible: moon.altitude > starHorizonAltitude - semidiameter,
    );
  }

  LunarEclipseContact? optional(double? t) => t == null ? null : contact(t);
  return LocalLunarEclipse(
    eclipse: eclipse,
    penumbralBegin: contact(eclipse.penumbralBegin),
    partialBegin: optional(eclipse.partialBegin),
    totalBegin: optional(eclipse.totalBegin),
    maximum: contact(eclipse.jdTT),
    totalEnd: optional(eclipse.totalEnd),
    partialEnd: optional(eclipse.partialEnd),
    penumbralEnd: contact(eclipse.penumbralEnd),
  );
}

/// Ułamek powierzchni koła o promieniu 1 zakryty przez koło o promieniu
/// [r], gdy odległość środków wynosi [c].
double _overlap(double r, double c) {
  if (c >= 1 + r) return 0;
  if (c <= (1 - r).abs()) return r < 1 ? r * r : 1;
  // Pole części wspólnej dwóch kół (dwa odcinki koła).
  final a1 = math.acos((c * c + 1 - r * r) / (2 * c));
  final a2 = math.acos((c * c + r * r - 1) / (2 * c * r));
  final k = math.sqrt((-c + 1 + r) * (c + 1 - r) * (c - 1 + r) * (c + 1 + r));
  return (a1 + r * r * a2 - k / 2) / math.pi;
}

/// Cień względem obserwatora w chwili t: u, v – położenie osi cienia
/// względem obserwatora na płaszczyźnie podstawowej, m – odległość,
/// l1, l2 – promienie stożków na wysokości obserwatora.
class _Local {
  final double u, v, l1, l2;

  factory _Local(_Shadow s, Observer o, double jdTT, double? deltaTSeconds) {
    final r =
        o.position(jdTT, deltaTSeconds: deltaTSeconds) *
        (1 / earthEquatorialRadius);
    final zeta = r.dot(s.axis);
    return _Local._(
      s.x - r.dot(s.east),
      s.y - r.dot(s.north),
      s.l1 - zeta * s.tanF1,
      s.l2 - zeta * s.tanF2,
    );
  }

  _Local._(this.u, this.v, this.l1, this.l2);

  double get m => math.sqrt(u * u + v * v);
}

/// Geometry of the Moon's shadow on the fundamental plane – the plane
/// through the Earth's centre perpendicular to the shadow axis – in
/// equatorial Earth radii.
class _Shadow {
  /// Coordinates of the shadow axis: x to the east, y to the north.
  final double x, y;

  /// Radii of the penumbral and umbral cones in the fundamental plane
  /// (l2 negative: the umbral cone reaches beyond the plane).
  final double l1, l2;

  /// Tangents of the half-angles of the two cones.
  final double tanF1, tanF2;

  /// Declination of the shadow axis (radians).
  final double declination;

  /// Kierunki osi układu płaszczyzny podstawowej w układzie prawdziwego
  /// równika daty: x (wschód), y (północ), oś cienia (ku Słońcu).
  final Vector3 east, north, axis;

  _Shadow(
    this.x,
    this.y,
    this.l1,
    this.l2,
    this.tanF1,
    this.tanF2,
    this.declination,
    this.east,
    this.north,
    this.axis,
  );

  double get distanceSquared => x * x + y * y;
}

_Shadow _shadow(Ephemeris ephemeris, double jdTT) {
  final sun = _vector(equatorialOfDate(ephemeris, Naif.sun, jdTT));
  final moon = _vector(equatorialOfDate(ephemeris, Naif.moon, jdTT));
  final toSun = sun - moon;
  final g = toSun.unit;
  final a = math.atan2(g.y, g.x), d = math.asin(g.z);
  final east = Vector3(-math.sin(a), math.cos(a), 0);
  final north = Vector3(
    -math.sin(d) * math.cos(a),
    -math.sin(d) * math.sin(a),
    math.cos(d),
  );
  const r = earthEquatorialRadius;
  final x = moon.dot(east) / r, y = moon.dot(north) / r;
  final z = moon.dot(g) / r;
  final sunMoon = toSun.length;
  final sinF1 = (solarRadius + moonRadiusRatio * r) / sunMoon;
  final sinF2 = (solarRadius - moonRadiusRatioUmbra * r) / sunMoon;
  final tanF1 = sinF1 / math.sqrt(1 - sinF1 * sinF1);
  final tanF2 = sinF2 / math.sqrt(1 - sinF2 * sinF2);
  // Vertices of the cones: the penumbral one between the Moon and the
  // Sun, the umbral one beyond the Moon.
  final c1 = z + moonRadiusRatio / sinF1;
  final c2 = z - moonRadiusRatioUmbra / sinF2;
  return _Shadow(x, y, c1 * tanF1, c2 * tanF2, tanF1, tanF2, d, east, north, g);
}

SolarEclipse? _solarEclipse(Ephemeris ephemeris, double newMoonJdTT) {
  final t = _minimize(
    (t) => _shadow(ephemeris, t).distanceSquared,
    newMoonJdTT - 0.25,
    newMoonJdTT + 0.25,
  );
  final s = _shadow(ephemeris, t);
  final gamma = math.sqrt(s.distanceSquared) * (s.y < 0 ? -1 : 1);
  // The Earth's outline on the fundamental plane is an ellipse: the
  // equatorial radius in x, the projected polar radius in y.
  const e2 = earthFlattening * (2 - earthFlattening);
  final rho = math.sqrt(1 - e2 * math.pow(math.cos(s.declination), 2));
  final q = s.x * s.x + math.pow(s.y / rho, 2);
  // Radius of the outline in the direction of the shadow axis.
  final edge = q > 0 ? gamma.abs() / math.sqrt(q) : 1.0;
  final longitude = geocentricEcliptic(ephemeris, Naif.sun, t).longitude;

  SolarEclipse eclipse(SolarEclipseType type, bool central, double m) =>
      SolarEclipse(
        jdTT: t,
        type: type,
        central: central,
        magnitude: m,
        gamma: gamma,
        longitude: longitude,
      );

  if (q < 1) {
    // Central: the axis meets the Earth at distance ζ from the plane.
    final zeta = math.sqrt(1 - q);
    final cone1 = s.l1 - zeta * s.tanF1, cone2 = s.l2 - zeta * s.tanF2;
    final magnitude = (cone1 - cone2) / (cone1 + cone2);
    if (cone2 > 0) {
      return eclipse(SolarEclipseType.annular, true, magnitude);
    }
    // Total at the point of greatest eclipse; annular towards the ends of
    // the path, where the surface is farther from the Moon, if the
    // umbral vertex lies above the Earth's limb.
    return eclipse(
      s.l2 > 0 ? SolarEclipseType.hybrid : SolarEclipseType.total,
      true,
      magnitude,
    );
  }
  // The axis misses the Earth: magnitude at the point of the Earth's
  // limb closest to the axis, at distance [outside] from it (Meeus,
  // formula 54.2, with the actual outline instead of 0.9972).
  final outside = gamma.abs() - edge;
  if (outside >= s.l1) return null;
  final magnitude = (s.l1 - outside) / (s.l1 + s.l2);
  if (outside < s.l2.abs()) {
    // Non-central: only the edge of the umbral cone touches the Earth.
    return eclipse(
      s.l2 < 0 ? SolarEclipseType.total : SolarEclipseType.annular,
      false,
      magnitude,
    );
  }
  return eclipse(SolarEclipseType.partial, false, magnitude);
}

/// Księżyc względem cienia Ziemi w chwili t (kąty w radianach):
/// odległość środka Księżyca od punktu przeciwległego Słońcu, promienie
/// półcienia i cienia, promień tarczy Księżyca.
({double distance, double penumbra, double umbra, double moon}) _earthShadow(
  Ephemeris ephemeris,
  double t,
  ShadowEnlargement enlargement,
) {
  final moonDir = geocentricDirection(ephemeris, Naif.moon, t);
  final sunDir = geocentricDirection(ephemeris, Naif.sun, t);
  final moonParallax = math.asin(earthEquatorialRadius / moonDir.distance);
  final sunParallax = math.asin(earthEquatorialRadius / sunDir.distance);
  final sunSemidiameter = math.asin(solarRadius / sunDir.distance);
  final (penumbra, umbra) = switch (enlargement) {
    ShadowEnlargement.danjon => (
      1.01 * moonParallax + sunSemidiameter + sunParallax,
      1.01 * moonParallax - sunSemidiameter + sunParallax,
    ),
    ShadowEnlargement.chauvenet => (
      1.02 * (0.998340 * moonParallax + sunSemidiameter + sunParallax),
      1.02 * (0.998340 * moonParallax - sunSemidiameter + sunParallax),
    ),
  };
  return (
    distance: _angle(moonDir.direction, sunDir.direction * -1),
    penumbra: penumbra,
    umbra: umbra,
    moon: math.asin(moonRadius / moonDir.distance),
  );
}

LunarEclipse? _lunarEclipse(
  Ephemeris ephemeris,
  double fullMoonJdTT,
  ShadowEnlargement enlargement,
) {
  ({double distance, double penumbra, double umbra, double moon}) at(
    double t,
  ) => _earthShadow(ephemeris, t, enlargement);

  final t = _minimize(
    (t) => at(t).distance,
    fullMoonJdTT - 0.25,
    fullMoonJdTT + 0.25,
  );
  final s = at(t);
  final penumbral = (s.penumbra + s.moon - s.distance) / (2 * s.moon);
  if (penumbral <= 0) return null;
  final umbral = (s.umbra + s.moon - s.distance) / (2 * s.moon);

  // Kontakty: brzeg Księżyca na brzegu półcienia (P) i cienia (U).
  // Całe zaćmienie trwa najwyżej ok. 6 h, więc ±0,25 doby wystarcza.
  final start = t - 0.25, end = t + 0.25;
  (double, double) contacts(double Function(double) f) =>
      (_root(f, start, t), _root(f, t, end));
  final (p1, p4) = contacts((x) {
    final a = at(x);
    return a.distance - a.penumbra - a.moon;
  });
  final (u1, u4) = umbral > 0
      ? contacts((x) {
          final a = at(x);
          return a.distance - a.umbra - a.moon;
        })
      : (null, null);
  final (u2, u3) = umbral >= 1
      ? contacts((x) {
          final a = at(x);
          return a.distance - a.umbra + a.moon;
        })
      : (null, null);

  final moon = equatorialOfDate(ephemeris, Naif.moon, t);
  final sun = equatorialOfDate(ephemeris, Naif.sun, t);
  final antisolar = _vector(sun) * -1;
  final north = _vector(moon).unit.z > antisolar.unit.z;
  return LunarEclipse(
    jdTT: t,
    type: umbral >= 1
        ? LunarEclipseType.total
        : umbral > 0
        ? LunarEclipseType.partial
        : LunarEclipseType.penumbral,
    umbralMagnitude: umbral,
    penumbralMagnitude: penumbral,
    gamma:
        math.sin(s.distance) *
        moon.distance /
        earthEquatorialRadius *
        (north ? 1 : -1),
    longitude: geocentricEcliptic(ephemeris, Naif.moon, t).longitude,
    penumbralBegin: p1,
    partialBegin: u1,
    totalBegin: u2,
    totalEnd: u3,
    partialEnd: u4,
    penumbralEnd: p4,
  );
}

/// Position as a vector in km in the frame of the true equator of date.
Vector3 _vector(EquatorialPosition p) {
  const r = math.pi / 180;
  final a = p.rightAscension * r, d = p.declination * r;
  return Vector3(
        math.cos(d) * math.cos(a),
        math.cos(d) * math.sin(a),
        math.sin(d),
      ) *
      p.distance;
}

/// Angle between unit vectors [u] and [v] in radians, accurate also for
/// small angles.
double _angle(Vector3 u, Vector3 v) => math.atan2(u.cross(v).length, u.dot(v));

/// Minimum of [f] in [a] … [b] (one minimum expected), by golden-section
/// search to 1e-7 day (about 0.01 s).
double _minimize(double Function(double) f, double a, double b) {
  const g = 0.6180339887498949;
  var c = b - g * (b - a), d = a + g * (b - a);
  var fc = f(c), fd = f(d);
  while (b - a > 1e-7) {
    if (fc < fd) {
      b = d;
      d = c;
      fd = fc;
      c = b - g * (b - a);
      fc = f(c);
    } else {
      a = c;
      c = d;
      fc = fd;
      d = a + g * (b - a);
      fd = f(d);
    }
  }
  return (a + b) / 2;
}

/// Pierwiastek [f] w [a] … [b] (f zmienia znak), bisekcja do 1e-8 doby
/// (ok. 1 ms).
double _root(double Function(double) f, double a, double b) {
  var fa = f(a);
  while (b - a > 1e-8) {
    final m = (a + b) / 2, fm = f(m);
    if ((fm < 0) == (fa < 0)) {
      a = m;
      fa = fm;
    } else {
      b = m;
    }
  }
  return (a + b) / 2;
}

const _degree = math.pi / 180;
