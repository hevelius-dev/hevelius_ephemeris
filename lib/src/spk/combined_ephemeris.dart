// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'ephemeris.dart';
import 'spk_ephemeris.dart';
import 'state_vector.dart';

/// Several ephemeris sources together, e.g. a compact file for the planets
/// and an SPK file with small bodies. Each body is taken from the first
/// source in [sources] that covers it.
class CombinedEphemeris implements Ephemeris {
  final List<Ephemeris> sources;

  CombinedEphemeris(this.sources);

  @override
  StateVector state(int target, int center, double et) {
    for (final s in sources) {
      if (s.covers(target, et) &&
          (center == Naif.solarSystemBarycenter || s.covers(center, et))) {
        return s.state(target, center, et);
      }
    }
    // Ciała z różnych źródeł – przez barycentrum Układu Słonecznego.
    return _barycentric(target, et) - _barycentric(center, et);
  }

  StateVector _barycentric(int body, double et) {
    if (body == Naif.solarSystemBarycenter) return StateVector.zero;
    for (final s in sources) {
      if (s.covers(body, et)) {
        return s.state(body, Naif.solarSystemBarycenter, et);
      }
    }
    throw ArgumentError('No data for body $body at $et s');
  }

  @override
  bool covers(int target, double et) =>
      sources.any((s) => s.covers(target, et));
}
