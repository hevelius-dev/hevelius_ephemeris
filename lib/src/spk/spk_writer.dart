// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

/// An SPK type 2 segment for writing: motion of [target] relative to
/// [center] as Chebyshev polynomials for position.
class SpkType2Segment {
  final String name;
  final int target, center;

  /// Start of the first interval (TDB seconds past J2000).
  final double startEt;

  /// Length of each interval in seconds.
  final double intervalLength;

  /// Coefficients: for each interval three lists (x, y, z) of equal
  /// length, in km.
  final List<(List<double>, List<double>, List<double>)> records;

  const SpkType2Segment({
    required this.name,
    required this.target,
    required this.center,
    required this.startEt,
    required this.intervalLength,
    required this.records,
  });

  double get endEt => startEt + intervalLength * records.length;
}

/// Writes an SPK file (DAF format, little-endian) with [segments] in the
/// J2000/ICRF frame.
///
/// File layout: header record, one summary record, one name record, data
/// – as in NAIF "DAF Required Reading" and "SPK Required Reading".
Uint8List writeSpk(String internalName, List<SpkType2Segment> segments) {
  const recordWords = 128, recordBytes = 1024;
  const summaryWords = 5; // ND = 2 liczby double + NI = 6 liczb int32
  if (segments.length > (recordWords - 3) ~/ summaryWords) {
    throw ArgumentError('Too many segments for one summary record');
  }

  // Dane segmentów zaczynają się po trzech rekordach (nagłówek, spis,
  // nazwy); adresy DAF liczone są w słowach 8-bajtowych od 1.
  final data = <double>[];
  final addresses = <(int, int)>[];
  const firstDataWord = 3 * recordWords + 1;
  for (final s in segments) {
    final n = s.records.first.$1.length;
    final begin = firstDataWord + data.length;
    final radius = s.intervalLength / 2;
    for (var i = 0; i < s.records.length; i++) {
      final (x, y, z) = s.records[i];
      if (x.length != n || y.length != n || z.length != n) {
        throw ArgumentError('Inconsistent coefficient counts in "${s.name}"');
      }
      data
        ..add(s.startEt + i * s.intervalLength + radius)
        ..add(radius)
        ..addAll(x)
        ..addAll(y)
        ..addAll(z);
    }
    data.addAll([
      s.startEt,
      s.intervalLength,
      (2 + 3 * n).toDouble(),
      s.records.length.toDouble(),
    ]);
    addresses.add((begin, firstDataWord + data.length - 1));
  }

  final dataRecords = (data.length + recordWords - 1) ~/ recordWords;
  final bytes = ByteData((3 + dataRecords) * recordBytes);
  void text(int offset, String value, int length) {
    final encoded = latin1.encode(value.padRight(length));
    for (var i = 0; i < length; i++) {
      bytes.setUint8(offset + i, encoded[i]);
    }
  }

  const le = Endian.little;
  // Rekord 1: nagłówek pliku.
  text(0, 'DAF/SPK', 8);
  bytes.setInt32(8, 2, le); // ND
  bytes.setInt32(12, 6, le); // NI
  text(16, internalName, 60);
  bytes.setInt32(76, 2, le); // pierwszy rekord spisu
  bytes.setInt32(80, 2, le); // ostatni rekord spisu
  bytes.setInt32(84, firstDataWord + data.length, le); // pierwsze wolne
  text(88, 'LTL-IEEE', 8);
  // Ciąg kontrolny wykrywający uszkodzenie pliku przy przesyłaniu w trybie
  // tekstowym (FTP) – stały, opisany w DAF Required Reading.
  const ftp = [
    0x46, 0x54, 0x50, 0x53, 0x54, 0x52, 0x3A, 0x0D, 0x3A, 0x0A, 0x3A, 0x0D, //
    0x0A, 0x3A, 0x0D, 0x00, 0x3A, 0x81, 0x3A, 0x10, 0xCE, 0x3A, 0x45, 0x4E,
    0x44, 0x46, 0x54, 0x50,
  ];
  for (var i = 0; i < ftp.length; i++) {
    bytes.setUint8(699 + i, ftp[i]);
  }

  // Rekord 2: spis segmentów (następny, poprzedni, liczba wpisów).
  const summary = recordBytes;
  bytes.setFloat64(summary, 0, le);
  bytes.setFloat64(summary + 8, 0, le);
  bytes.setFloat64(summary + 16, segments.length.toDouble(), le);
  for (var i = 0; i < segments.length; i++) {
    final s = segments[i];
    final at = summary + 24 + i * summaryWords * 8;
    bytes.setFloat64(at, s.startEt, le);
    bytes.setFloat64(at + 8, s.endEt, le);
    final ints = [s.target, s.center, 1, 2, addresses[i].$1, addresses[i].$2];
    for (var k = 0; k < 6; k++) {
      bytes.setInt32(at + 16 + 4 * k, ints[k], le);
    }
    // Rekord 3: nazwy segmentów, po 40 znaków.
    text(2 * recordBytes + i * summaryWords * 8, s.name, summaryWords * 8);
  }

  for (var i = 0; i < data.length; i++) {
    bytes.setFloat64(3 * recordBytes + 8 * i, data[i], le);
  }
  return bytes.buffer.asUint8List();
}
