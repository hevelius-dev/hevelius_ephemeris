// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

/// Reading SPK files from disk on demand, without loading the whole file
/// into memory (a separate library because it needs `dart:io`).
library;

import 'dart:io';
import 'dart:typed_data';

import 'src/spk/spk_file.dart';

/// Opens the SPK file at [path]: reads the summary records now and
/// segment data from disk only when needed. The file stays open until
/// the program exits.
///
/// Throws [FormatException] if the file is not an SPK file.
SpkFile openSpkFile(String path) =>
    SpkFile.fromSource(_FileSource(File(path).openSync()));

class _FileSource implements SpkSource {
  _FileSource(this._file) : length = _file.lengthSync();

  final RandomAccessFile _file;

  @override
  final int length;

  @override
  Uint8List read(int offset, int count) {
    _file.setPositionSync(offset);
    final bytes = _file.readSync(count);
    if (bytes.length != count) {
      throw FileSystemException(
        'Truncated SPK file: wanted $count bytes at $offset, '
        'got ${bytes.length}',
        _file.path,
      );
    }
    return bytes;
  }
}
