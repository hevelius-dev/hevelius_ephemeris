// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import '../spk/spk_ephemeris.dart';
import 'crossings.dart';
import '../spk/ephemeris.dart';

/// The principal phases of the Moon.
enum MoonPhase { newMoon, firstQuarter, fullMoon, lastQuarter }

/// A moment of a principal lunar phase.
class LunarPhase {
  /// Julian day in Terrestrial Time.
  final double jdTT;

  final MoonPhase phase;

  const LunarPhase(this.jdTT, this.phase);

  @override
  String toString() => 'LunarPhase($jdTT, ${phase.name})';
}

/// Elongation of the Moon from the Sun in ecliptic longitude: the
/// apparent geocentric longitude of the Moon minus that of the Sun, in
/// degrees (0 ≤ x < 360) – 0° at New Moon, 180° at Full Moon.
LongitudeFunction lunarElongation(Ephemeris ephemeris) {
  final moon = bodyLongitude(ephemeris, Naif.moon);
  final sun = bodyLongitude(ephemeris, Naif.sun);
  return (jdTT) => (moon(jdTT) - sun(jdTT)) % 360;
}

/// New Moons, First Quarters, Full Moons and Last Quarters in
/// [startJdTT] … [endJdTT], in time order: the moments when the excess
/// of the apparent geocentric longitude of the Moon over that of the Sun
/// is 0°, 90°, 180° and 270°.
List<LunarPhase> lunarPhases(
  Ephemeris ephemeris,
  double startJdTT,
  double endJdTT,
) => [
  for (final c in longitudeCrossings(
    lunarElongation(ephemeris),
    startJdTT,
    endJdTT,
    period: 90,
  ))
    LunarPhase(c.jdTT, MoonPhase.values[(c.longitude / 90).round() % 4]),
];
