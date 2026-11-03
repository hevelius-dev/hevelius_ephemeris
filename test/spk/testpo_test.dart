// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Zgodność z oficjalnym plikiem kontrolnym JPL testpo.440 (zob.
// testpo_check.dart).
import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

import '../jpl_files.dart';
import 'testpo_check.dart';

void main() {
  for (final (name, file) in [('de440s', de440s), ('de440', de440)]) {
    test('zgodność z testpo.440 w zakresie $name', () {
      final checked = checkTestpo(name, SpkEphemeris([file]), 'testpo.440');
      expect(checked, greaterThan(1000));
    });
  }
}
