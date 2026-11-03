// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

/// Rate of change of ecliptic longitude in degrees per day.
///
/// A central difference of [longitudeAt] (degrees for a TT Julian day)
/// around [jdTT] with a step of [step] days; handles the 0°/360°
/// crossing. A negative value means retrograde motion.
double longitudeSpeed(
  double Function(double jdTT) longitudeAt,
  double jdTT, {
  double step = 0.005,
}) {
  var d = longitudeAt(jdTT + step) - longitudeAt(jdTT - step);
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d / (2 * step);
}
