// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Lokalne okoliczności zaćmień Słońca porównane z elementami Bessela NASA
// (F. Espenak, NASA GSFC – strony SEgoogle, np.
// https://eclipse.gsfc.nasa.gov/SEgoogle/SEgoogle2001/SE2024Apr08Tgoogle.html,
// pobrane 2026-11-02). Z elementów liczymy kontakty niezależną, podręcznikową
// metodą (Explanatory Supplement to the Astronomical Ephemeris, 1961,
// rozdz. 9) – tu, w funkcji [_Besselian.local]; silnik liczy z DE440, przy
// ΔT przyjętym przez NASA.
//
// Różnice: C1 ok. 1 s później, C4 do 0,5 s wcześniej – mamy promień Słońca
// 695 700 km (IAU 2015), NASA ok. 696 000 km, więc nieco mniejszy półcień.
import 'dart:math' as math;

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';

/// Elementy Bessela NASA: JD maksimum (TT), t0 (h TT), ΔT (s), wielomiany
/// x, y, d, μ, l1, l2 w (t − t0) w godzinach, tg f1, tg f2.
class _Besselian {
  final double jd, t0, deltaT;
  final List<double> x, y, d, mu, l1, l2;
  final double tanF1, tanF2;

  const _Besselian(
    this.jd,
    this.t0,
    this.deltaT,
    this.x,
    this.y,
    this.d,
    this.mu,
    this.l1,
    this.l2,
    this.tanF1,
    this.tanF2,
  );

  /// Początek doby (0h TT) dnia maksimum.
  double get day => (jd - 0.5).floorToDouble() + 0.5;

  static double _poly(List<double> c, double t) {
    var s = 0.0;
    for (var i = c.length - 1; i >= 0; i--) {
      s = s * t + c[i];
    }
    return s;
  }

  /// Kontakty (JD TT; II i III null przy częściowym), wielkość fazy i kąty
  /// pozycyjne (stopnie) dla miejsca; null, gdy zaćmienia tam nie ma.
  ({List<double?> times, double magnitude, List<double?> angles})? local(
    double latitude,
    double longitude,
    double height,
  ) {
    const deg = math.pi / 180;
    final phi = latitude * deg;
    final u = math.atan((1 - earthFlattening) * math.tan(phi));
    final h = height / 1000 / earthEquatorialRadius;
    final rhoSin = (1 - earthFlattening) * math.sin(u) + h * math.sin(phi);
    final rhoCos = math.cos(u) + h * math.cos(phi);

    // (u, v, m, L1, L2) w chwili t (godziny od t0).
    List<double> state(double t) {
      final dd = _poly(d, t) * deg;
      // Kąt godzinny osi cienia; μ jest liczone w TT, stąd poprawka ΔT.
      final hh = (_poly(mu, t) + longitude - 0.00417807 * deltaT) * deg;
      final xi = rhoCos * math.sin(hh);
      final eta = rhoSin * math.cos(dd) - rhoCos * math.cos(hh) * math.sin(dd);
      final zeta = rhoSin * math.sin(dd) + rhoCos * math.cos(hh) * math.cos(dd);
      final uu = _poly(x, t) - xi, vv = _poly(y, t) - eta;
      return [
        uu,
        vv,
        math.sqrt(uu * uu + vv * vv),
        _poly(l1, t) - zeta * tanF1,
        _poly(l2, t) - zeta * tanF2,
      ];
    }

    double root(double Function(double) f, double a, double b) {
      var fa = f(a);
      for (var i = 0; i < 60; i++) {
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

    // Minimum odległości od osi cienia – złoty podział w ±4 h.
    const g = 0.6180339887498949;
    var a = -4.0, b = 4.0;
    while (b - a > 1e-9) {
      final c = b - g * (b - a), e = a + g * (b - a);
      if (state(c)[2] < state(e)[2]) {
        b = e;
      } else {
        a = c;
      }
    }
    final tm = (a + b) / 2;
    final s = state(tm);
    if (s[2] >= s[3]) return null;
    double outer(double t) => state(t)[2] - state(t)[3];
    double inner(double t) => state(t)[2] - state(t)[4].abs();
    final c1 = root(outer, -4, tm), c4 = root(outer, tm, 4);
    final central = s[2] < s[4].abs();
    final c2 = central ? root(inner, c1, tm) : null;
    final c3 = central ? root(inner, tm, c4) : null;
    double? jd(double? t) => t == null ? null : day + (t0 + t) / 24;
    double? angle(double? t) {
      if (t == null) return null;
      final st = state(t);
      return (math.atan2(st[0], st[1]) / deg) % 360;
    }

    return (
      times: [jd(c1), jd(c2), jd(tm), jd(c3), jd(c4)],
      magnitude: (s[3] - s[2]) / (s[3] + s[4]),
      angles: [angle(c1), angle(c2), angle(tm), angle(c3), angle(c4)],
    );
  }
}

/// 8.04.2024, całkowite (SE2024Apr08T).
const _se2024 = _Besselian(
  2460409.262835,
  18.0,
  70.6,
  [-0.31815711, 0.51171052, 0.00003265, -0.00000852],
  [0.21974689, 0.27095860, -0.00005943, -0.00000467],
  [7.58619928, 0.01484434, -0.00000168],
  [89.59121704, 15.00408363, -0.00000130],
  [0.53581262, 0.00006179, -0.00001275],
  [-0.01027351, 0.00006148, -0.00001269],
  0.00466826,
  0.00464501,
);

/// 14.10.2023, obrączkowe (SE2023Oct14A).
const _se2023 = _Besselian(
  2460232.250462,
  18.0,
  70.5,
  [0.16975069, 0.45854804, 0.00002733, -0.00000491],
  [0.33483735, -0.24136680, 0.00002402, 0.00000304],
  [-8.24418831, -0.01488791, 0.00000122],
  [93.50170135, 15.00353336, 0.00000197],
  [0.56431091, -0.00008908, -0.00001030],
  [0.01808279, -0.00008864, -0.00001026],
  0.00468819,
  0.00466485,
);

/// 12.08.2026, całkowite (SE2026Aug12T).
const _se2026 = _Besselian(
  2461265.241032,
  18.0,
  71.4,
  [0.47559288, 0.51892877, -0.00007733, -0.00000879],
  [0.77116090, -0.23016642, -0.00012455, 0.00000372],
  [14.79666901, -0.01206477, -0.00000274],
  [88.74776459, 15.00309277, 0.00000519],
  [0.53795421, 0.00009396, -0.00001209],
  [-0.00814245, 0.00009348, -0.00001206],
  0.00461406,
  0.00459108,
);

void main() {
  final ephemeris = SpkEphemeris([de440s]);

  SolarEclipse eclipseOf(_Besselian b) =>
      solarEclipses(ephemeris, b.jd - 1, b.jd + 1).single;

  LocalSolarEclipse? ours(
    _Besselian b,
    double latitude,
    double longitude,
    double height,
  ) => localSolarEclipse(
    ephemeris,
    eclipseOf(b),
    latitude: latitude,
    longitude: longitude,
    height: height,
    deltaTSeconds: b.deltaT,
  );

  // nazwa, elementy, szerokość, długość (wsch. +), wysokość (m), typ lokalny
  const places = [
    ('Torreón 2024', _se2024, 25.5167, -103.45, 1120.0, SolarEclipseType.total),
    ('Dallas 2024', _se2024, 32.7767, -96.797, 131.0, SolarEclipseType.total),
    (
      'Honolulu 2024',
      _se2024,
      21.3069,
      -157.8583,
      0.0,
      SolarEclipseType.partial,
    ),
    (
      'Albuquerque 2023',
      _se2023,
      35.0844,
      -106.6504,
      1619.0,
      SolarEclipseType.annular,
    ),
    (
      'Nowy Jork 2023',
      _se2023,
      40.7128,
      -74.006,
      10.0,
      SolarEclipseType.partial,
    ),
    ('Burgos 2026', _se2026, 42.3439, -3.6969, 860.0, SolarEclipseType.total),
    ('Reykjavik 2026', _se2026, 64.1466, -21.9426, 0.0, SolarEclipseType.total),
    (
      'Warszawa 2026',
      _se2026,
      52.2297,
      21.0122,
      100.0,
      SolarEclipseType.partial,
    ),
  ];

  for (final (name, b, lat, lon, h, type) in places) {
    test('$name: kontakty, wielkość i kąty jak z elementów NASA', () {
      final nasa = b.local(lat, lon, h)!;
      final l = ours(b, lat, lon, h)!;
      expect(l.type, type);
      final contacts = [
        l.firstContact,
        l.secondContact,
        l.maximum,
        l.thirdContact,
        l.fourthContact,
      ];
      // Tolerancje: C1, C2, maksimum, C3, C4 (s) i kąty (°).
      // C1 i C4 ok. 1 s później / wcześniej (promień Słońca, zob. wyżej),
      // przy płytkim zaćmieniu (Nowy Jork) do 2,6 s.
      const seconds = [3.0, 3.0, 1.0, 3.0, 3.0];
      const degrees = [1.0, 2.0, null, 2.0, 1.0];
      for (var i = 0; i < 5; i++) {
        final expected = nasa.times[i];
        if (expected == null) {
          expect(contacts[i], isNull, reason: 'kontakt ${i + 1}');
          continue;
        }
        final c = contacts[i]!;
        expect(
          (c.jdTT - expected) * 86400,
          closeTo(0, seconds[i]),
          reason: 'czas, pozycja $i',
        );
        if (degrees[i] != null) {
          final dp = (c.positionAngle - nasa.angles[i]! + 540) % 360 - 180;
          expect(dp, closeTo(0, degrees[i]!), reason: 'kąt P, pozycja $i');
        }
      }
      expect(l.magnitude, closeTo(nasa.magnitude, 0.001));
    });
  }

  test('Warszawa 2026: początek widoczny, koniec po zachodzie Słońca', () {
    final l = ours(_se2026, 52.2297, 21.0122, 100)!;
    expect(l.firstContact.visible, isTrue);
    expect(l.fourthContact.visible, isFalse);
    expect(l.fourthContact.altitude, lessThan(sunHorizonAltitude));
    // Słońce zachodzi na północnym zachodzie.
    expect(l.fourthContact.azimuth, inInclusiveRange(270, 320));
  });

  test('Sydney 2024: noc – geometria jest, ale nic nie widać', () {
    final l = ours(_se2024, -33.8688, 151.2093, 0)!;
    expect(_se2024.local(-33.8688, 151.2093, 0), isNotNull);
    for (final c in [l.firstContact, l.maximum, l.fourthContact]) {
      expect(c.visible, isFalse);
    }
  });

  test('Kapsztad 2024: cień w ogóle nie dociera – null', () {
    expect(_se2024.local(-33.9249, 18.4241, 0), isNull);
    expect(ours(_se2024, -33.9249, 18.4241, 0), isNull);
  });

  test('zaćmienie całkowite: zakrycie 1, czas fazy całkowitej', () {
    final l = ours(_se2024, 25.5167, -103.45, 1120)!;
    expect(l.obscuration, 1);
    expect(l.diameterRatio, greaterThan(1));
    // NASA: najdłuższa faza całkowita 4 min 28 s, Torreón leży blisko.
    expect(l.centralDuration, inInclusiveRange(240, 268));
  });

  test('zaćmienie obrączkowe: w maksimum zakrycie = (średnica K/S)²', () {
    final l = ours(_se2023, 35.0844, -106.6504, 1619)!;
    expect(l.diameterRatio, lessThan(1));
    expect(l.obscuration, closeTo(l.diameterRatio * l.diameterRatio, 1e-12));
  });

  test('zaćmienie częściowe: zakrycie między 0 a wielkością fazy', () {
    // Dla częściowego zakrycie (pole) jest mniejsze niż wielkość (średnica).
    final l = ours(_se2024, 21.3069, -157.8583, 0)!;
    expect(l.obscuration, greaterThan(0));
    expect(l.obscuration, lessThan(l.magnitude));
  });

  group('zaćmienie Księżyca 14.03.2025 z różnych miejsc', () {
    final day = julianDay(2025, 3, 14);
    final lunar = lunarEclipses(ephemeris, day - 1, day + 1).single;
    LocalLunarEclipse view(double lat, double lon) =>
        localLunarEclipse(ephemeris, lunar, latitude: lat, longitude: lon);

    // Mapa na karcie NASA LE2025Mar14T: Ameryki – całe zaćmienie widoczne,
    // środek Azji – niewidoczne.
    test('Chicago: wszystkie kontakty widoczne', () {
      final v = view(41.8781, -87.6298);
      expect(v.all, hasLength(7));
      expect(v.all.every((c) => c.visible), isTrue);
    });

    test('Nowe Delhi: nic nie widać', () {
      final v = view(28.6139, 77.209);
      expect(v.all.any((c) => c.visible), isFalse);
    });

    test('Warszawa: widoczność zgodna z zachodem Księżyca', () {
      const lat = 52.2297, lon = 21.0122;
      final v = view(lat, lon);
      final moonset = horizonEvents(
        ephemeris,
        Naif.moon,
        lat,
        lon,
        lunar.penumbralBegin - 0.5,
        lunar.penumbralEnd,
      ).where((e) => e.kind == HorizonEventKind.set).toList();
      final set = moonset
          .singleWhere((e) => e.jdTT > lunar.penumbralBegin - 0.25)
          .jdTT;
      // Księżyc zachodzi w trakcie zaćmienia.
      expect(set, inExclusiveRange(lunar.penumbralBegin, lunar.penumbralEnd));
      for (final c in v.all) {
        if ((c.jdTT - set).abs() * 1440 < 2) continue;
        expect(c.visible, c.jdTT < set, reason: 'chwila ${c.jdTT}');
      }
      // Ostatni widoczny kontakt – nisko na zachodzie.
      final last = v.all.lastWhere((c) => c.visible);
      expect(last.azimuth, inInclusiveRange(240, 300));
      expect(last.altitude, inInclusiveRange(-1, 15));
    });

    test('paralaksa w wysokości: sin p = ρ·sin π·cos h′ (π z karty NASA)', () {
      // Paralaksa horyzontalna w maksimum: 0°54′36,8″ (LE2025Mar14T);
      // h′ – wysokość topocentryczna (Meeus, rozdz. 40). Wzór zakłada
      // przesunięcie dokładnie w pionie; naprawdę biegnie ono wzdłuż
      // promienia Ziemi, odchylonego od pionu o φ − φ′ ≈ 0,19° (do
      // ok. 0,003° w wysokości), a π zmienia się o ułamek sekundy –
      // tolerancja 0,004°.
      const pi = (54 + 36.8 / 60) / 60 * math.pi / 180;
      final o = Observer(latitude: 52.2297, longitude: 21.0122);
      final rho = math.sqrt(o.rhoSin * o.rhoSin + o.rhoCos * o.rhoCos);
      for (final c in view(52.2297, 21.0122).all) {
        final geocentric = altitude(
          ephemeris,
          Naif.moon,
          52.2297,
          21.0122,
          c.jdTT,
        );
        final h = c.altitude * math.pi / 180;
        final p = math.asin(rho * math.sin(pi) * math.cos(h)) * 180 / math.pi;
        expect(geocentric - c.altitude, closeTo(p, 0.004));
      }
    });
  });
}
