// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Zaćmienia porównane z kanonem NASA (F. Espenak, J. Meeus, Five Millennium
// Canon of Solar/Lunar Eclipses; tabele dekad 2021–2030 ze strony
// https://eclipse.gsfc.nasa.gov/, pobrane 2026-11-01). NASA liczy
// teoriami VSOP87 i ELP-2000/82, my DE440 – czasy maksimum (TD) zgadzają
// się do ok. 1,5 s, wielkości fazy do 0,001 (NASA podaje trzy miejsca).
import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';

/// Zaćmienia Słońca 2021–2030: data i czas maksimum (TD), rodzaj,
/// wielkość fazy.
const nasaSolar = [
  (2021, 6, 10, 10, 43, 6, SolarEclipseType.annular, 0.943),
  (2021, 12, 4, 7, 34, 38, SolarEclipseType.total, 1.037),
  (2022, 4, 30, 20, 42, 36, SolarEclipseType.partial, 0.640),
  (2022, 10, 25, 11, 1, 19, SolarEclipseType.partial, 0.862),
  (2023, 4, 20, 4, 17, 55, SolarEclipseType.hybrid, 1.013),
  (2023, 10, 14, 18, 0, 40, SolarEclipseType.annular, 0.952),
  (2024, 4, 8, 18, 18, 29, SolarEclipseType.total, 1.057),
  (2024, 10, 2, 18, 46, 13, SolarEclipseType.annular, 0.933),
  (2025, 3, 29, 10, 48, 36, SolarEclipseType.partial, 0.938),
  (2025, 9, 21, 19, 43, 4, SolarEclipseType.partial, 0.855),
  (2026, 2, 17, 12, 13, 5, SolarEclipseType.annular, 0.963),
  (2026, 8, 12, 17, 47, 5, SolarEclipseType.total, 1.039),
  (2027, 2, 6, 16, 0, 47, SolarEclipseType.annular, 0.928),
  (2027, 8, 2, 10, 7, 49, SolarEclipseType.total, 1.079),
  (2028, 1, 26, 15, 8, 58, SolarEclipseType.annular, 0.921),
  (2028, 7, 22, 2, 56, 39, SolarEclipseType.total, 1.056),
  (2029, 1, 14, 17, 13, 47, SolarEclipseType.partial, 0.871),
  (2029, 6, 12, 4, 6, 13, SolarEclipseType.partial, 0.458),
  (2029, 7, 11, 15, 37, 18, SolarEclipseType.partial, 0.230),
  (2029, 12, 5, 15, 3, 57, SolarEclipseType.partial, 0.891),
  (2030, 6, 1, 6, 29, 13, SolarEclipseType.annular, 0.944),
  (2030, 11, 25, 6, 51, 37, SolarEclipseType.total, 1.047),
];

/// Zaćmienia Księżyca 2021–2030: data i czas maksimum (TD), rodzaj,
/// wielkość fazy w cieniu (umbral magnitude).
const nasaLunar = [
  (2021, 5, 26, 11, 19, 53, LunarEclipseType.total, 1.009),
  (2021, 11, 19, 9, 4, 6, LunarEclipseType.partial, 0.974),
  (2022, 5, 16, 4, 12, 42, LunarEclipseType.total, 1.414),
  (2022, 11, 8, 11, 0, 22, LunarEclipseType.total, 1.359),
  (2023, 5, 5, 17, 24, 5, LunarEclipseType.penumbral, -0.046),
  (2023, 10, 28, 20, 15, 18, LunarEclipseType.partial, 0.122),
  (2024, 3, 25, 7, 13, 59, LunarEclipseType.penumbral, -0.132),
  (2024, 9, 18, 2, 45, 25, LunarEclipseType.partial, 0.085),
  (2025, 3, 14, 6, 59, 56, LunarEclipseType.total, 1.178),
  (2025, 9, 7, 18, 12, 58, LunarEclipseType.total, 1.362),
  (2026, 3, 3, 11, 34, 52, LunarEclipseType.total, 1.151),
  (2026, 8, 28, 4, 14, 4, LunarEclipseType.partial, 0.930),
  (2027, 2, 20, 23, 14, 6, LunarEclipseType.penumbral, -0.057),
  (2027, 7, 18, 16, 4, 9, LunarEclipseType.penumbral, -1.068),
  (2027, 8, 17, 7, 14, 59, LunarEclipseType.penumbral, -0.525),
  (2028, 1, 12, 4, 14, 13, LunarEclipseType.partial, 0.066),
  (2028, 7, 6, 18, 20, 57, LunarEclipseType.partial, 0.389),
  (2028, 12, 31, 16, 53, 15, LunarEclipseType.total, 1.246),
  (2029, 6, 26, 3, 23, 22, LunarEclipseType.total, 1.844),
  (2029, 12, 20, 22, 43, 12, LunarEclipseType.total, 1.117),
  (2030, 6, 15, 18, 34, 34, LunarEclipseType.partial, 0.502),
  (2030, 12, 9, 22, 28, 51, LunarEclipseType.penumbral, -0.163),
];

void main() {
  lunarContactTests();

  final eph = SpkEphemeris([de440s]);
  final start = julianDay(2021, 1, 1), end = julianDay(2031, 1, 1);

  double nasaJd((int, int, int, int, int, int, Object, double) e) => julianDay(
    e.$1,
    e.$2,
    e.$3,
    hour: e.$4,
    minute: e.$5,
    second: e.$6.toDouble(),
  );

  test('zaćmienia Słońca 2021–2030 jak w kanonie NASA', () {
    final found = solarEclipses(eph, start, end);
    expect(found, hasLength(nasaSolar.length));
    for (var i = 0; i < found.length; i++) {
      final (ours, nasa) = (found[i], nasaSolar[i]);
      final label = '${nasa.$1}-${nasa.$2}-${nasa.$3}';
      expect((ours.jdTT - nasaJd(nasa)) * 86400, closeTo(0, 3), reason: label);
      expect(ours.type, nasa.$7, reason: label);
      expect(ours.magnitude, closeTo(nasa.$8, 0.0015), reason: label);
    }
  });

  test('zaćmienia Księżyca 2021–2030 jak w kanonie NASA (Danjon)', () {
    final found = lunarEclipses(eph, start, end);
    expect(found, hasLength(nasaLunar.length));
    for (var i = 0; i < found.length; i++) {
      final (ours, nasa) = (found[i], nasaLunar[i]);
      final label = '${nasa.$1}-${nasa.$2}-${nasa.$3}';
      expect((ours.jdTT - nasaJd(nasa)) * 86400, closeTo(0, 3), reason: label);
      expect(ours.type, nasa.$7, reason: label);
      expect(ours.umbralMagnitude, closeTo(nasa.$8, 0.0015), reason: label);
    }
  });

  test('zaćmienia niecentralne (Meeus, rozdz. 54; wielkości z NASA)', () {
    // Oś cienia mija Ziemię, a brzeg stożka cienia dotyka okolic bieguna.
    for (final (y, m, d, type, magnitude) in [
      (2014, 4, 29, SolarEclipseType.annular, 0.987),
      (2043, 4, 9, SolarEclipseType.total, 1.010),
      (2043, 10, 3, SolarEclipseType.annular, 0.950),
    ]) {
      final jd = julianDay(y, m, d);
      final e = solarEclipses(eph, jd - 1, jd + 1).single;
      expect(e.type, type);
      expect(e.central, isFalse);
      expect(e.magnitude, closeTo(magnitude, 0.0015));
    }
  });

  test('8.04.2024: gamma 0,3431, długość ekliptyczna 19°24′ Barana', () {
    final jd = julianDay(2024, 4, 8);
    final e = solarEclipses(eph, jd - 1, jd + 1).single;
    expect(e.gamma, closeTo(0.3431, 0.0002));
    expect(e.central, isTrue);
    expect(e.longitude, closeTo(19.4, 0.1));
  });

  test('Chauvenet: wielkości większe o ok. 0,006 (cień) – NASA', () {
    final jd = julianDay(2026, 3, 3);
    final danjon = lunarEclipses(eph, jd - 1, jd + 1).single;
    final chauvenet = lunarEclipses(
      eph,
      jd - 1,
      jd + 1,
      enlargement: ShadowEnlargement.chauvenet,
    ).single;
    expect(
      chauvenet.umbralMagnitude - danjon.umbralMagnitude,
      inInclusiveRange(0.003, 0.009),
    );
    expect(
      chauvenet.penumbralMagnitude - danjon.penumbralMagnitude,
      inInclusiveRange(0.015, 0.035),
    );
  });
}

// Kontakty zaćmień Księżyca: karty NASA LEplot (F. Espenak, NASA GSFC,
// np. https://eclipse.gsfc.nasa.gov/LEplot/LEplot2001/LE2025Mar14T.pdf,
// pobrane 2026-11-02; reguła Danjona, VSOP87/ELP2000-85). Czasy UT do
// pełnej sekundy; ΔT NASA = różnica TD − UT maksimum z tej samej karty.
// Faza całkowita wychodzi u nas o 3–5 s dłuższa (U2 wcześniej, U3 później).
double _hms(int h, int m, int s) => (h * 3600 + m * 60 + s) / 86400;

final _nasaLunarContacts = [
  (
    2022,
    11,
    8,
    73.2,
    [
      _hms(8, 2, 17), _hms(9, 9, 12), _hms(10, 16, 39), //
      _hms(11, 41, 37), _hms(12, 49, 3), _hms(13, 56, 8),
    ],
  ),
  (
    2024,
    3,
    25,
    74.0,
    [_hms(4, 53, 11), null, null, null, null, _hms(9, 32, 18)],
  ),
  (
    2024,
    9,
    18,
    74.2,
    [
      _hms(0, 41, 2), _hms(2, 12, 48), null, null, //
      _hms(3, 15, 35), _hms(4, 47, 18),
    ],
  ),
  (
    2025,
    3,
    14,
    74.5,
    [
      _hms(3, 57, 24), _hms(5, 9, 33), _hms(6, 25, 59), //
      _hms(7, 31, 23), _hms(8, 47, 48), _hms(10, 0, 1),
    ],
  ),
  (
    2025,
    9,
    7,
    74.8,
    [
      _hms(15, 28, 21), _hms(16, 27, 2), _hms(17, 30, 41), //
      _hms(18, 52, 47), _hms(19, 56, 26), _hms(20, 55, 0),
    ],
  ),
];

void lunarContactTests() {
  final ephemeris = SpkEphemeris([de440s]);
  for (final (y, m, d, deltaT, nasa) in _nasaLunarContacts) {
    test('kontakty zaćmienia Księżyca $y-$m-$d jak u NASA (do 4 s)', () {
      final day = julianDay(y, m, d);
      final e = lunarEclipses(ephemeris, day - 1, day + 1.5).single;
      final ours = [
        e.penumbralBegin,
        e.partialBegin,
        e.totalBegin,
        e.totalEnd,
        e.partialEnd,
        e.penumbralEnd,
      ];
      for (var i = 0; i < 6; i++) {
        if (nasa[i] == null) {
          expect(ours[i], isNull, reason: 'kontakt $i');
          continue;
        }
        final expected = day + nasa[i]! + deltaT / 86400;
        expect((ours[i]! - expected) * 86400, closeTo(0, 4), reason: '$i');
      }
    });
  }
}
