// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

/// The J2000.0 epoch as a Julian day: 1 January 2000, 12:00 TT.
///
/// The zero point of time in JPL ephemerides (seconds past J2000) and in
/// most modern astronomical formulas.
const double j2000 = 2451545.0;

/// Days in a Julian century; many formulas take time in centuries since
/// [j2000].
const double daysPerJulianCentury = 36525.0;
