// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

/// Coefficients c₀…cₙ of the Chebyshev polynomial of [degree] that best
/// approximates (least squares) [values] at [points] in the interval
/// −1 ≤ s ≤ 1.
///
/// Needs at least [degree] + 1 points.
List<double> fitChebyshev(
  List<double> points,
  List<double> values,
  int degree,
) {
  final n = degree + 1;
  if (points.length != values.length || points.length < n) {
    throw ArgumentError('Too few points for a fit of degree $degree');
  }
  // Równania normalne (AᵀA)·c = Aᵀ·y, A[k][j] = T_j(s_k).
  final ata = List.generate(n, (_) => List.filled(n, 0.0));
  final aty = List.filled(n, 0.0);
  for (var k = 0; k < points.length; k++) {
    final t = chebyshevBasis(points[k], n);
    for (var i = 0; i < n; i++) {
      aty[i] += t[i] * values[k];
      for (var j = 0; j < n; j++) {
        ata[i][j] += t[i] * t[j];
      }
    }
  }
  return _solve(ata, aty);
}

/// Values T₀(s)…Tₙ₋₁(s) of the Chebyshev polynomials.
List<double> chebyshevBasis(double s, int n) {
  final t = List.filled(n, 0.0);
  t[0] = 1;
  if (n > 1) t[1] = s;
  for (var k = 2; k < n; k++) {
    t[k] = 2 * s * t[k - 1] - t[k - 2];
  }
  return t;
}

/// Value of the Chebyshev polynomial with coefficients [c] at [s].
double evaluateChebyshev(List<double> c, double s) {
  final t = chebyshevBasis(s, c.length);
  var sum = 0.0;
  for (var k = 0; k < c.length; k++) {
    sum += c[k] * t[k];
  }
  return sum;
}

/// Rozwiązuje układ równań liniowych metodą eliminacji Gaussa
/// z wyborem elementu głównego (modyfikuje [a] i [b]).
List<double> _solve(List<List<double>> a, List<double> b) {
  final n = b.length;
  for (var col = 0; col < n; col++) {
    var pivot = col;
    for (var r = col + 1; r < n; r++) {
      if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
    }
    if (a[pivot][col].abs() < 1e-300) {
      throw StateError(
        'Singular system – the points do not determine '
        'the polynomial',
      );
    }
    if (pivot != col) {
      final tmpRow = a[col];
      a[col] = a[pivot];
      a[pivot] = tmpRow;
      final tmp = b[col];
      b[col] = b[pivot];
      b[pivot] = tmp;
    }
    for (var r = col + 1; r < n; r++) {
      final f = a[r][col] / a[col][col];
      if (f == 0) continue;
      for (var c = col; c < n; c++) {
        a[r][c] -= f * a[col][c];
      }
      b[r] -= f * b[col];
    }
  }
  final x = List.filled(n, 0.0);
  for (var r = n - 1; r >= 0; r--) {
    var sum = b[r];
    for (var c = r + 1; c < n; c++) {
      sum -= a[r][c] * x[c];
    }
    x[r] = sum / a[r][r];
  }
  return x;
}
