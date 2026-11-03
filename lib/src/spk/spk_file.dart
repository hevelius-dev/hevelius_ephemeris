// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'state_vector.dart';

/// Source of SPK file bytes: the whole file in memory ([SpkFile.fromBytes])
/// or on-demand reads from disk (`openSpkFile` in `spk_io.dart`).
abstract interface class SpkSource {
  /// File size in bytes.
  int get length;

  /// [count] bytes starting at [offset].
  Uint8List read(int offset, int count);
}

class _BytesSource implements SpkSource {
  _BytesSource(this._bytes);

  final Uint8List _bytes;

  @override
  int get length => _bytes.length;

  @override
  Uint8List read(int offset, int count) =>
      Uint8List.sublistView(_bytes, offset, offset + count);
}

/// An ephemeris file in SPK format (e.g. `de440s.bsp` from NASA JPL).
///
/// Format: NAIF "DAF Required Reading" and "SPK Required Reading". The
/// file consists of 1024-byte records; the first is the header, followed
/// by linked summary records and segment data.
///
/// Reads from the [SpkSource] only the summaries and the records needed
/// for a calculation.
class SpkFile {
  /// The internal name written into the file by its author.
  final String internalName;

  final List<SpkSegment> segments;

  final SpkSource _source;
  final Endian _endian;

  SpkFile._(this.internalName, this.segments, this._source, this._endian);

  /// Reads a file from bytes (the whole file in memory).
  ///
  /// Throws [FormatException] if it is not an SPK file.
  factory SpkFile.fromBytes(Uint8List bytes) =>
      SpkFile.fromSource(_BytesSource(bytes));

  /// Reads the file summaries from [source]; segment data is read only
  /// when needed.
  ///
  /// Throws [FormatException] if it is not an SPK file.
  factory SpkFile.fromSource(SpkSource source) {
    if (source.length < _recordBytes) {
      throw const FormatException('File too short for a DAF header');
    }
    final bytes = source.read(0, _recordBytes);
    final data = ByteData.sublistView(bytes);
    final id = _text(bytes, 0, 8);
    if (id != 'DAF/SPK') {
      throw FormatException('Not an SPK file (identifier "$id")');
    }
    final format = _text(bytes, 88, 8);
    final endian = switch (format) {
      'LTL-IEEE' => Endian.little,
      'BIG-IEEE' => Endian.big,
      _ => throw FormatException('Unknown number format "$format"'),
    };
    final nd = data.getInt32(8, endian);
    final ni = data.getInt32(12, endian);
    if (nd != 2 || ni != 6) {
      throw FormatException('Unexpected SPK summary: ND=$nd, NI=$ni');
    }
    final internalName = _text(bytes, 16, 60);
    final firstSummary = data.getInt32(76, endian);

    final file = SpkFile._(internalName, [], source, endian);
    // Rozmiar jednego wpisu spisu w słowach 8-bajtowych: ND liczb double
    // i NI liczb int32 (po dwie na słowo).
    const summaryWords = 2 + (6 + 1) ~/ 2;
    var record = firstSummary;
    while (record != 0) {
      // Rekord spisu i tuż za nim rekord z nazwami segmentów.
      final bytes = source.read((record - 1) * _recordBytes, 2 * _recordBytes);
      final data = ByteData.sublistView(bytes);
      final next = data.getFloat64(0, endian).toInt();
      final count = data.getFloat64(16, endian).toInt();
      for (var i = 0; i < count; i++) {
        final at = 24 + i * summaryWords * 8;
        int int32(int k) => data.getInt32(at + 16 + 4 * k, endian);
        final nameAt = _recordBytes + i * summaryWords * 8;
        file.segments.add(
          SpkSegment._(
            file,
            name: _text(bytes, nameAt, summaryWords * 8),
            startEt: data.getFloat64(at, endian),
            endEt: data.getFloat64(at + 8, endian),
            target: int32(0),
            center: int32(1),
            frame: int32(2),
            dataType: int32(3),
            beginWord: int32(4),
            endWord: int32(5),
          ),
        );
      }
      record = next;
    }
    return file;
  }

  /// The double at address [word] (DAF addresses start at 1).
  double word(int word) => words(word, 1)[0];

  /// [count] consecutive doubles starting at address [first].
  Float64List words(int first, int count) {
    final data = ByteData.sublistView(_source.read((first - 1) * 8, count * 8));
    return Float64List.fromList([
      for (var i = 0; i < count; i++) data.getFloat64(i * 8, _endian),
    ]);
  }

  static const _recordBytes = 1024;

  static String _text(Uint8List bytes, int start, int length) =>
      latin1.decode(bytes.sublist(start, start + length)).trimRight();
}

/// A segment of an SPK file: motion of [target] relative to [center]
/// over the time span [startEt]…[endEt].
class SpkSegment {
  final String name;

  /// NAIF code of the body (e.g. 399 Earth, 301 Moon, 4 Mars barycentre).
  final int target;

  /// NAIF code of the reference body (0 = solar system barycentre).
  final int center;

  /// Reference frame (1 = J2000/ICRF).
  final int frame;

  /// SPK data type (2 = Chebyshev polynomials for position).
  final int dataType;

  /// Start and end in TDB seconds past J2000.
  final double startEt, endEt;

  /// Addresses of the first and last data word of the segment.
  final int beginWord, endWord;

  final SpkFile file;

  SpkSegment._(
    this.file, {
    required this.name,
    required this.target,
    required this.center,
    required this.frame,
    required this.dataType,
    required this.startEt,
    required this.endEt,
    required this.beginWord,
    required this.endWord,
  });

  /// Whether the segment covers [et] (TDB seconds past J2000).
  bool covers(double et) => et >= startEt && et <= endEt;

  /// Ostatnie 4 słowa segmentu: początek pierwszego przedziału, długość
  /// przedziału (s), długość rekordu (słowa), liczba rekordów.
  late final Float64List _directory = file.words(endWord - 3, 4);

  // Ostatnio użyty rekord – kolejne obliczenia (prędkość, czas biegu
  // światła, sąsiednie chwile) trafiają zwykle w ten sam.
  int _recordIndex = -1;
  Float64List _record = Float64List(0);

  /// Position and velocity of [target] relative to [center] at [et]
  /// (TDB seconds past J2000).
  ///
  /// Supports types 2 (position polynomials; velocity from the
  /// derivative) and 3 (separate position and velocity polynomials).
  StateVector state(double et) {
    if (!covers(et)) {
      throw RangeError('Time $et s outside segment $this');
    }
    if (dataType != 2 && dataType != 3) {
      throw UnsupportedError('SPK segment type $dataType not supported');
    }
    final init = _directory[0];
    final intervalLength = _directory[1];
    final recordSize = _directory[2].toInt();
    final count = _directory[3].toInt();

    final index = ((et - init) / intervalLength).floor().clamp(0, count - 1);
    if (index != _recordIndex) {
      _record = file.words(beginWord + index * recordSize, recordSize);
      _recordIndex = index;
    }
    // Rekord: środek przedziału, połowa długości, potem współczynniki
    // kolejnych składowych (3 dla typu 2, 6 dla typu 3).
    final record = _record;
    final mid = record[0];
    final radius = record[1];
    final components = dataType == 2 ? 3 : 6;
    final n = (recordSize - 2) ~/ components;
    final s = (et - mid) / radius;

    double value(int component) => _chebyshev(record, 2 + component * n, n, s);
    double derivative(int component) =>
        _chebyshevDerivative(record, 2 + component * n, n, s) / radius;

    return dataType == 2
        ? StateVector(
            value(0),
            value(1),
            value(2),
            derivative(0),
            derivative(1),
            derivative(2),
          )
        : StateVector(
            value(0),
            value(1),
            value(2),
            value(3),
            value(4),
            value(5),
          );
  }

  /// Suma c₀·T₀(s) + … + cₙ₋₁·Tₙ₋₁(s) dla współczynników c od pozycji
  /// [first] w [c].
  ///
  /// T₀ = 1, T₁ = s, Tₖ = 2s·Tₖ₋₁ − Tₖ₋₂.
  static double _chebyshev(Float64List c, int first, int n, double s) {
    var tPrev = 1.0, t = s;
    var sum = c[first] + (n > 1 ? c[first + 1] * s : 0);
    for (var k = 2; k < n; k++) {
      final tNext = 2 * s * t - tPrev;
      sum += c[first + k] * tNext;
      tPrev = t;
      t = tNext;
    }
    return sum;
  }

  /// Pochodna [_chebyshev] względem s.
  ///
  /// T′₀ = 0, T′₁ = 1, T′ₖ = 2·Tₖ₋₁ + 2s·T′ₖ₋₁ − T′ₖ₋₂.
  static double _chebyshevDerivative(
    Float64List c,
    int first,
    int n,
    double s,
  ) {
    if (n < 2) return 0;
    var tPrev = 1.0, t = s; // Tₖ₋₂, Tₖ₋₁
    var dPrev = 0.0, d = 1.0; // T′ₖ₋₂, T′ₖ₋₁
    var sum = c[first + 1];
    for (var k = 2; k < n; k++) {
      final dNext = 2 * t + 2 * s * d - dPrev;
      final tNext = 2 * s * t - tPrev;
      sum += c[first + k] * dNext;
      tPrev = t;
      t = tNext;
      dPrev = d;
      d = dNext;
    }
    return sum;
  }

  @override
  String toString() =>
      'SpkSegment($target względem $center, typ $dataType, '
      'układ $frame, „$name”)';
}
