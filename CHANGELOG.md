## 0.1.0

- Package skeleton, J2000 and Julian century constants.
- Julian day ↔ date in the Julian and Gregorian calendars.
- ΔT (USNO measurements, spline of Morrison et al., parabola), UT ↔ TT.
- NASA SPK file reader (types 2 and 3), body positions and velocities,
  agreement with testpo.440 to 2 mm.
- Reductions: TDB, light-time, light deflection, aberration, IAU 2006
  precession, IAU 2000A nutation; apparent positions on the ecliptic of
  date.
- Nodes (mean, true), Lilith (mean, osculating), speeds.
- Chiron, Ceres, Pallas, Juno, Vesta from JPL Horizons; writing SPK files.
- Sidereal time (Earth rotation angle, GMST IAU 2006, GAST with the
  complementary terms of the equation of the equinoxes).
- Ascendant and MC (`angles`, `anglesFromArmc`); beyond the polar circle
  the ascendant is always on the eastern side; comparison with Swiss
  Ephemeris in `tool/compare_reference.dart`.
- DE440 (1550–2650) alongside DE440s; Chiron and asteroids for 1600–2500;
  `SpkEphemeris.covers` – whether there is data for a body at a moment.
- `openSpkFile` (`spk_io.dart`): SPK files read from disk on demand,
  without loading the whole file into memory; `SpkFile.fromSource`.
- Events: `longitudeCrossings`, `ingresses` (including retrograde
  re-entries), `stations`, `seasons` (equinoxes and solstices).
- Lunar phases: `lunarPhases`, `lunarElongation`.
- Rising, setting and meridian transits (`horizonEvents`), twilight
  (`twilights`), `equatorialOfDate`, `altitude`.
- Solar and lunar eclipses (`solarEclipses`, `lunarEclipses`): type,
  greatest eclipse, magnitude, gamma, ecliptic longitude; Danjon or
  Chauvenet shadow enlargement.
- Local circumstances of solar eclipses (`localSolarEclipse`): contacts
  I–IV and maximum with the Sun's altitude, azimuth, position angle and
  visibility; local type, magnitude, obscuration, duration of totality or
  annularity.
- Contacts of lunar eclipses (P1, U1, U2, U3, U4, P4 in `LunarEclipse`)
  and their visibility from a place (`localLunarEclipse`): topocentric
  altitude and azimuth of the Moon at each contact.
- DE441 and DE442 checked against the JPL test files; `download_jpl.dart`
  fetches DE442 by default and DE441 with `--de441` (checksums computed
  while streaming). Tests on these files carry the tag `duze-pliki`.
- Long-term precession (Vondrák, Capitaine and Wallace 2011) for the
  ecliptic of date, mean obliquity and mean sidereal time, valid for
  ±200 000 years; the IAU 2006 versions remain as `*Iau2006` functions.
- Horizontal coordinates: `Observer`, `HorizontalPosition`,
  `horizontalPosition` (topocentric, with parallax), `fixedStarHorizontal`,
  `equatorialToHorizontal`, `refraction` (Sæmundsson, pressure and
  temperature). Local eclipse circumstances now use the same topocentric
  positions.
- `Ephemeris` interface (`state`, `covers`), implemented by
  `SpkEphemeris`; all calculations accept any `Ephemeris`.
- `CombinedEphemeris`: several sources together (e.g. planets from one
  file, small bodies from another).
- `dart run hevelius_ephemeris:download_jpl [--dir DIR] [FILE ...]`
  downloads JPL ephemerides with checksum verification.
- 22 bright fixed stars; `tool/build_fixed_stars.dart` builds star files
  from SIMBAD.
- `heveliusAttribution`, `heveliusHomepage`; CITATION.cff; copyright
  line at the top of LICENSE.
- Fixed-star designations in IAU notation ("alf Tau" instead of "alTau");
  star names credited to the IAU WGSN (CC BY 4.0).
