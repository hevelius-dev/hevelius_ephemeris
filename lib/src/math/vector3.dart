// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

/// A vector in three-dimensional space.
class Vector3 {
  final double x, y, z;

  const Vector3(this.x, this.y, this.z);

  Vector3 operator +(Vector3 o) => Vector3(x + o.x, y + o.y, z + o.z);
  Vector3 operator -(Vector3 o) => Vector3(x - o.x, y - o.y, z - o.z);
  Vector3 operator *(double k) => Vector3(x * k, y * k, z * k);

  double dot(Vector3 o) => x * o.x + y * o.y + z * o.z;

  /// Cross product.
  Vector3 cross(Vector3 o) =>
      Vector3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(dot(this));

  /// Unit vector in the same direction.
  Vector3 get unit => this * (1 / length);

  /// Rotation of the coordinate frame by [angle] (radians) about the x
  /// axis – the R₁ matrix of the IERS Conventions (2010), chapter 5.
  Vector3 rotateX(double angle) {
    final c = math.cos(angle), s = math.sin(angle);
    return Vector3(x, c * y + s * z, -s * y + c * z);
  }

  /// Rotation of the coordinate frame by [angle] about the z axis (R₃).
  Vector3 rotateZ(double angle) {
    final c = math.cos(angle), s = math.sin(angle);
    return Vector3(c * x + s * y, -s * x + c * y, z);
  }

  @override
  String toString() => 'Vector3($x, $y, $z)';
}
