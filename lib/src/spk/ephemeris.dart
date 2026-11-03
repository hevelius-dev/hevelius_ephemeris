// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'state_vector.dart';

/// A source of positions and velocities of solar system bodies: JPL SPK
/// files (`SpkEphemeris`) or any other implementation, e.g. a compact
/// format. All calculations of the engine take an [Ephemeris].
abstract interface class Ephemeris {
  /// Position and velocity of [target] relative to [center] (NAIF codes)
  /// at [et] (TDB seconds past J2000), in the ICRF/J2000 frame, in km and
  /// km/s.
  ///
  /// Throws [ArgumentError] if there is no data for the body at that
  /// moment.
  StateVector state(int target, int center, double et);

  /// Whether there is data for [target] at [et] (TDB seconds past J2000).
  bool covers(int target, double et);
}
