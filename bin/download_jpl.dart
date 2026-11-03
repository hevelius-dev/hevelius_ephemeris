// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

// Downloads NASA JPL ephemeris files and verifies their SHA-256 sums.
//
//   dart run hevelius_ephemeris:download_jpl                  # de440s
//   dart run hevelius_ephemeris:download_jpl de442 de441      # chosen files
//   dart run hevelius_ephemeris:download_jpl --dir eph de442  # other folder
//
// Files already present with a correct checksum are skipped.
import 'dart:io';

import 'package:crypto/crypto.dart';

const _base = 'https://ssd.jpl.nasa.gov/ftp/eph/planets';

/// Known files: name → (URL, SHA-256 recorded on first download over HTTPS
/// from the JPL server; DE440 2026-10-30, DE441 and DE442 2026-11-02).
const jplFiles = <String, (String, String)>{
  'de440s.bsp': (
    '$_base/bsp/de440s.bsp',
    'c1c7feeab882263fc493a9d5a5b2ddd71b54826cdf65d8d17a76126b260a49f2',
  ),
  'de440.bsp': (
    '$_base/bsp/de440.bsp',
    'a4ce9bf9b3282becc9f4b2ac3cebe03a2ae7599981aabd7265fd8482fff7c4b5',
  ),
  'testpo.440': (
    '$_base/ascii/de440/testpo.440',
    '45084a7f406b8e41032e7d99dd8042d4df97a9f752a68c06d1a27af16693429f',
  ),
  'de442.bsp': (
    '$_base/bsp/de442.bsp',
    '8d5001fab315eeff222cc51f7cf7ffcdb43fb38fb9ac73ff09e09a5b361fd388',
  ),
  'testpo.442': (
    '$_base/ascii/de442/testpo.442',
    '4c088ba7c75903f4573d99b5ab34aa205b1b91791fb8f3c0af0f43334033aa93',
  ),
  'de441.bsp': (
    '$_base/bsp/de441.bsp',
    '9a824e6a8ce3d39f8a513b17278ff7b7ad226f964c76d2019b0a51d8808d6ff5',
  ),
  'testpo.441': (
    '$_base/ascii/de441/testpo.441',
    'e60c08ced7741a07d4dfe89b124afb4b1648bd1e3d0eb68dd9a79bf6990bb9c2',
  ),
};

const _sizes = {
  'de440s.bsp': '32 MB, 1849–2150',
  'de440.bsp': '115 MB, 1550–2650',
  'de441.bsp': '3.3 GB, −13200 … +17191',
  'de442.bsp': '115 MB, 1550–2650',
};

Future<void> main(List<String> args) async {
  var dir = 'data/jpl';
  final names = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--dir' && i + 1 < args.length) {
      dir = args[++i];
    } else if (a == '-h' || a == '--help') {
      _usage();
      return;
    } else {
      final name = a.contains('.') ? a : '$a.bsp';
      if (!jplFiles.containsKey(name)) {
        stderr.writeln('Unknown file: $a');
        _usage();
        exit(64);
      }
      names.add(name);
    }
  }
  if (names.isEmpty) names.add('de440s.bsp');
  exit(await download(names, dir) ? 0 : 1);
}

void _usage() {
  stdout.writeln(
    'Usage: dart run hevelius_ephemeris:download_jpl [--dir DIR] [FILE ...]\n'
    'Files (default de440s):',
  );
  for (final name in jplFiles.keys) {
    stdout.writeln('  ${name.padRight(12)} ${_sizes[name] ?? 'JPL test file'}');
  }
}

/// Downloads [names] from [jplFiles] into [dir]; true if all checksums match.
Future<bool> download(List<String> names, String dir) async {
  final folder = Directory(dir)..createSync(recursive: true);
  var ok = true;
  for (final name in names) {
    final (url, expected) = jplFiles[name]!;
    final file = File('${folder.path}/$name');
    if (file.existsSync() && await _sha256(file) == expected) {
      print('$name: already present, checksum OK');
      continue;
    }
    stdout.write('$name: downloading $url … ');
    await _download(url, file);
    final actual = await _sha256(file);
    if (actual == expected) {
      print('OK');
    } else {
      ok = false;
      print('WRONG CHECKSUM\n  expected $expected\n  got      $actual');
    }
  }
  return ok;
}

/// Streamed – DE441 is 3.3 GB and is not read into memory.
Future<String> _sha256(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

Future<void> _download(String url, File file) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }
    final tmp = File('${file.path}.part');
    await response.pipe(tmp.openWrite());
    tmp.renameSync(file.path);
  } finally {
    client.close();
  }
}
