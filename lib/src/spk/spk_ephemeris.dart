// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'ephemeris.dart';
import 'spk_file.dart';
import 'state_vector.dart';

/// NAIF codes of the bodies in JPL planetary ephemerides.
abstract final class Naif {
  static const solarSystemBarycenter = 0;
  static const mercuryBarycenter = 1;
  static const venusBarycenter = 2;
  static const earthMoonBarycenter = 3;
  static const marsBarycenter = 4;
  static const jupiterBarycenter = 5;
  static const saturnBarycenter = 6;
  static const uranusBarycenter = 7;
  static const neptuneBarycenter = 8;
  static const plutoBarycenter = 9;
  static const sun = 10;
  static const mercury = 199;
  static const venus = 299;
  static const moon = 301;
  static const earth = 399;
}

/// Body positions from one or more SPK files.
///
/// Each segment describes a body relative to another body; [state] chains
/// segments up to the solar system barycentre.
class SpkEphemeris implements Ephemeris {
  final List<SpkFile> files;

  SpkEphemeris(this.files);

  /// Position and velocity of [target] relative to [center] at [et]
  /// (TDB seconds past J2000), in the ICRF/J2000 frame.
  ///
  /// Throws [ArgumentError] if there is no data for the body at that
  /// moment.
  @override
  StateVector state(int target, int center, double et) =>
      _barycentric(target, et) - _barycentric(center, et);

  /// Whether the files have data for [target] at [et] – along the whole
  /// chain up to the solar system barycentre.
  @override
  bool covers(int target, double et) {
    for (var b = target; b != Naif.solarSystemBarycenter;) {
      final segment = _segmentOrNull(b, et);
      if (segment == null) return false;
      b = segment.center;
    }
    return true;
  }

  StateVector _barycentric(int body, double et) {
    var result = StateVector.zero;
    // Kolejne ogniwa łańcucha: np. Księżyc → barycentrum Ziemia–Księżyc
    // → barycentrum Układu Słonecznego.
    for (var b = body; b != Naif.solarSystemBarycenter;) {
      final segment = _segmentFor(b, et);
      result = result + segment.state(et);
      b = segment.center;
    }
    return result;
  }

  SpkSegment _segmentFor(int body, double et) =>
      _segmentOrNull(body, et) ??
      (throw ArgumentError('No data for body $body at $et s'));

  SpkSegment? _segmentOrNull(int body, double et) {
    // Przy kilku pasujących segmentach pierwszeństwo ma późniejszy
    // (późniejszy plik, a w pliku – dalszy segment).
    for (final file in files.reversed) {
      for (final segment in file.segments.reversed) {
        if (segment.target == body && segment.covers(et)) return segment;
      }
    }
    return null;
  }
}
