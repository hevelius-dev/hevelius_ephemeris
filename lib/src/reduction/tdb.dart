// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'precession_nutation.dart';

/// Approximate TDB − TT in seconds for [jdTT].
///
/// Main term only: 1.7 ms · sin l′ (l′ – mean anomaly of the Sun), IERS
/// Conventions (2010), section 5.6.4. Error about 0.03 ms; the Moon moves
/// about 0.00002″ in that time.
double tdbMinusTT(double jdTT) {
  final t = centuriesSinceJ2000(jdTT);
  final meanAnomalySun = (357.52910918 * 3600 + 129596581.0481 * t) * arcsecond;
  return 0.0017 * math.sin(meanAnomalySun);
}
