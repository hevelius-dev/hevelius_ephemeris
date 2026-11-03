// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import '../math/vector3.dart';

/// Position (km) and velocity (km/s) of a body in rectangular coordinates.
class StateVector {
  final double x, y, z;
  final double vx, vy, vz;

  const StateVector(this.x, this.y, this.z, this.vx, this.vy, this.vz);

  static const zero = StateVector(0, 0, 0, 0, 0, 0);

  Vector3 get position => Vector3(x, y, z);
  Vector3 get velocity => Vector3(vx, vy, vz);

  StateVector operator +(StateVector o) =>
      StateVector(x + o.x, y + o.y, z + o.z, vx + o.vx, vy + o.vy, vz + o.vz);

  StateVector operator -(StateVector o) =>
      StateVector(x - o.x, y - o.y, z - o.z, vx - o.vx, vy - o.vy, vz - o.vz);

  @override
  String toString() =>
      'StateVector(x: $x, y: $y, z: $z km; '
      'vx: $vx, vy: $vy, vz: $vz km/s)';
}
