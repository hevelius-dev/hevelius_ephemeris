# hevelius_ephemeris

An ephemeris engine in pure Dart (no Flutter, no native libraries), named
after Johannes Hevelius, the 17th-century astronomer of Gdańsk.

- Positions of solar system bodies come from NASA JPL ephemerides: DE442
  (recommended, 1550–2650), DE440 (the same range, used by the tests),
  DE440s (1849–2150) and DE441 (−13200 … +17191). The files are not part
  of the package – a script downloads them.
- All calculation code is written from scratch from published scientific
  sources, listed formula by formula in [SOURCES.md](SOURCES.md) (in
  Polish). No code from Swiss Ephemeris, SOFA or ERFA.

## What it computes

- Time: Julian day ↔ date in the Julian and Gregorian calendars, ΔT
  (−720 … today, extrapolated outside), UT ↔ TT, TDB.
- Apparent geocentric positions on the ecliptic of date: Sun, Moon,
  planets, Pluto; Chiron, Ceres, Pallas, Juno, Vesta. Light-time,
  gravitational light deflection, relativistic aberration, long-term
  precession (Vondrák, Capitaine and Wallace 2011, valid for ±200 000
  years; within 0.02″ of IAU 2006 in 1600–2500) and IAU 2000A nutation.
- Lunar points: mean and true node, mean and osculating apogee (Lilith).
- Speeds in longitude (retrograde motion).
- Sidereal time (Earth rotation angle, GMST, GAST), ascendant and MC.
- Events: sign ingresses (with retrograde re-entries), stations,
  equinoxes and solstices, moments when a longitude reaches any value,
  lunar phases, rising, setting, meridian transits and twilight.
- Solar and lunar eclipses: type (including hybrid and non-central),
  greatest eclipse, magnitude, gamma, ecliptic longitude – matching the
  NASA eclipse canon.
- Local circumstances of solar eclipses: contact times, maximum,
  magnitude and obscuration, the Sun's altitude and azimuth, and whether
  each phase is above the horizon.
- Lunar eclipse contacts (penumbral, partial, total) and the Moon's
  altitude and azimuth at each of them for a given place.
- Horizontal coordinates for any place on the Earth (`Observer`):
  topocentric altitude and azimuth (with parallax – about 1° for the
  Moon) of the Sun, Moon, planets, small bodies (`horizontalPosition`),
  fixed stars (`fixedStarHorizontal`) and any right ascension and
  declination (`equatorialToHorizontal`); optional refraction for given
  pressure and temperature. Agrees with JPL Horizons to 0.7″.
- Fixed stars: proper motion, annual parallax, deflection and aberration;
  22 bright stars included (Hipparcos values – ESA licence with a
  non-commercial clause, authorisation requested; see NOTICE).
- Reading and writing JPL SPK files (types 2 and 3).

Accuracy: astrometric positions agree with NASA/JPL Horizons to better
than 0.01″, typically 0.0001″ (75 comparisons, 15 bodies, 1849–2150);
apparent ecliptic positions differ only by the known offset between the
IAU 1976/1980 precession–nutation models used by Horizons and the
IAU 2006/2000A models used here (0.3″ in 1879); details in SOURCES.md.

## Data

The JPL ephemerides are not part of the package. Download them with:

```
dart run hevelius_ephemeris:download_jpl                  # de440s (32 MB, 1849–2150)
dart run hevelius_ephemeris:download_jpl de442            # 115 MB, 1550–2650
dart run hevelius_ephemeris:download_jpl de441            # 3.3 GB, −13200 … +17191
dart run hevelius_ephemeris:download_jpl --dir eph de442  # into another folder
```

Files go to `data/jpl/` by default; every file's SHA-256 is checked.

In the package repository (for its tests and tools):

```
dart run tool/download_jpl.dart          # DE442, DE440, DE440s and JPL test files
dart run tool/download_jpl.dart --de441  # also DE441
dart run tool/build_small_bodies.dart    # Chiron and asteroids from JPL Horizons (1600–2500)
dart run tool/build_fixed_stars.dart <list.csv> <out.csv>  # fixed stars from SIMBAD
```

## Example

```dart
import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:hevelius_ephemeris/spk_io.dart';

void main() {
  final ephemeris = SpkEphemeris([openSpkFile('data/jpl/de440s.bsp')]);
  // Ulm, 14 March 1879, 11:30 local mean time (10:50 UT).
  final jdUt = julianDay(1879, 3, 14, hour: 10, minute: 50);
  final jdTT = julianDayTT(jdUt);

  final sun = geocentricEcliptic(ephemeris, Naif.sun, jdTT);
  print(sun.longitude); // 353.508° – 23°30′28″ Pisces

  final a = angles(jdUt, 48.4, 10.0);
  print(a.ascendant); // 101.646° – 11°38′47″ Cancer
}
```

A complete version is in [example/example.dart](example/example.dart).

## Tests

```
dart test
```

The tests need the JPL files (see Data). Tests on DE441 and DE442 are
skipped by default (tag `duze-pliki`); run them with
`dart test -P duze-pliki`.

## Updating ΔT

Download new USNO measurements from https://maia.usno.navy.mil/ser7/deltat.data
into `data/delta_t/`, then:

```
dart run tool/generate_delta_t.dart
dart test
```

## Status and to do

Open points (details in SOURCES.md):

1. ΔT and the lunar tidal acceleration – the correction for early dates
   (roughly 1 s, i.e. below 1″ for the Moon) is not applied yet.
2. Mean inclination of the lunar orbit (used for mean Lilith) – a primary
   source for the full-precision value is still to be found.

## Attribution and citing

If you use Hevelius in an app, a website or a paper, a credit is very
much appreciated – for example in an "About" screen:

> Ephemeris calculations by Hevelius (https://hevelius.dev)

The same text is available in code as `heveliusAttribution`. For
scientific work, please cite the package using [CITATION.cff](CITATION.cff)
(GitHub shows it as "Cite this repository").

Using Hevelius in a project? We would be glad to hear about it:
contact@hevelius.dev.

## License

Code: [Apache License 2.0](LICENSE), copyright 2026 Mirosław Kozłowski.
If you distribute software that contains this package, include its
LICENSE and NOTICE (in Flutter apps the LICENSE appears automatically on
the licence page). Acknowledgements and licences of
third-party data (USNO, UKHO, IERS, NASA JPL, CDS/SIMBAD) are in
[NOTICE](NOTICE) and in [SOURCES.md](SOURCES.md), section "Licencje
danych".
