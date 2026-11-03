// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
import 'package:test/test.dart';

void main() {
  group('julianDay – wartości z literatury', () {
    // J. Meeus, Astronomical Algorithms, 2nd ed., rozdz. 7 (przykłady
    // i tabela 7.a). Domyślny kalendarz: juliański przed 15.10.1582.
    const cases = [
      // rok, miesiąc, dzień, godzina, JD
      (2000, 1, 1, 12.0, 2451545.0),
      (1999, 1, 1, 0.0, 2451179.5),
      (1987, 1, 27, 0.0, 2446822.5),
      (1987, 6, 19, 12.0, 2446966.0),
      (1988, 1, 27, 0.0, 2447187.5),
      (1988, 6, 19, 12.0, 2447332.0),
      (1900, 1, 1, 0.0, 2415020.5),
      (1600, 1, 1, 0.0, 2305447.5),
      (1600, 12, 31, 0.0, 2305812.5),
      (1582, 10, 15, 0.0, 2299160.5),
      (1582, 10, 4, 12.0, 2299160.0),
      (333, 1, 27, 12.0, 1842713.0),
      (-123, 12, 31, 0.0, 1676496.5),
      (-122, 1, 1, 0.0, 1676497.5),
      (-1000, 7, 12, 12.0, 1356001.0),
      (-1000, 2, 29, 0.0, 1355866.5),
      (-4712, 1, 1, 12.0, 0.0),
    ];
    for (final (y, m, d, hours, jd) in cases) {
      test('$y-$m-$d ${hours}h → $jd', () {
        expect(julianDay(y, m, d, hour: hours.toInt()), jd);
        final back = calendarDateTime(jd);
        expect(
          (back.year, back.month, back.day, back.hour),
          (y, m, d, hours.toInt()),
        );
      });
    }

    test('start Sputnika: 1957-10-04,81 → 2436116,31', () {
      // 0,81 doby = 19:26:24.
      expect(
        julianDay(1957, 10, 4, hour: 19, minute: 26, second: 24),
        closeTo(2436116.31, 1e-9),
      );
    });
  });

  group('kalendarze', () {
    test('ta sama doba w obu kalendarzach', () {
      // 4.10.1582 (jul.) był bezpośrednio przed 15.10.1582 (greg.).
      expect(
        julianDay(1582, 10, 5, calendar: Calendar.julian),
        julianDay(1582, 10, 15, calendar: Calendar.gregorian),
      );
    });

    test('dni 5–14.10.1582 bez jawnego kalendarza nie istnieją', () {
      expect(() => julianDay(1582, 10, 10), throwsArgumentError);
    });

    test('29 lutego 1900 tylko w kalendarzu juliańskim', () {
      expect(
        () => julianDay(1900, 2, 29, calendar: Calendar.gregorian),
        throwsArgumentError,
      );
      expect(
        julianDay(1900, 2, 29, calendar: Calendar.julian),
        julianDay(1900, 3, 13, calendar: Calendar.gregorian),
      );
    });

    test('Rosja: rewolucja październikowa była w listopadzie', () {
      expect(
        julianDay(1917, 10, 25, calendar: Calendar.julian),
        julianDay(1917, 11, 7, calendar: Calendar.gregorian),
      );
    });

    test('odrzuca nieprawidłowe daty i godziny', () {
      expect(() => julianDay(2001, 2, 29), throwsArgumentError);
      expect(() => julianDay(2000, 13, 1), throwsArgumentError);
      expect(() => julianDay(2000, 4, 31), throwsArgumentError);
      expect(() => julianDay(2000, 1, 1, hour: 24), throwsArgumentError);
      expect(() => julianDay(2000, 1, 1, second: 60), throwsArgumentError);
    });
  });

  group('zgodność z DateTime Darta (proleptyczny gregoriański)', () {
    test('co 7 lat od roku −13200 do +17191', () {
      final epoch = DateTime.utc(2000, 1, 1, 12);
      for (var y = -13200; y <= 17191; y += 7) {
        final t = DateTime.utc(y, (y % 12).abs() + 1, (y % 28).abs() + 1, 7);
        final expected = j2000 + t.difference(epoch).inMilliseconds / 86400000;
        expect(
          julianDay(
            t.year,
            t.month,
            t.day,
            hour: 7,
            calendar: Calendar.gregorian,
          ),
          closeTo(expected, 1e-8),
          reason: '$t',
        );
      }
    });
  });

  group('tam i z powrotem', () {
    test('każdy co 37. dzień od roku −13200 do +17191, oba kalendarze', () {
      const first = -3100000, last = 8000000;
      for (final cal in Calendar.values) {
        for (var n = first; n <= last; n += 37) {
          final d = calendarDateTime(n.toDouble(), calendar: cal);
          expect(d.hour, 12);
          expect(
            julianDay(d.year, d.month, d.day, hour: 12, calendar: cal),
            n.toDouble(),
            reason: '$d',
          );
        }
      }
    });

    test('kolejne dni to kolejne daty', () {
      for (final cal in Calendar.values) {
        var prev = calendarDateTime(-3100000.5, calendar: cal);
        for (var n = -3099999; n <= -3099999 + 3000; n++) {
          final d = calendarDateTime(n - 0.5, calendar: cal);
          final sameMonth = d.year == prev.year && d.month == prev.month;
          if (sameMonth) {
            expect(d.day, prev.day + 1, reason: '$d');
          } else {
            expect(d.day, 1, reason: '$d');
            expect(prev.day, daysInMonth(prev.year, prev.month, cal));
          }
          prev = d;
        }
      }
    });

    test('godzina z dokładnością do milisekundy', () {
      final jd = julianDay(1879, 3, 14, hour: 10, minute: 50, second: 12.345);
      expect(
        calendarDateTime(jd),
        const CalendarDateTime(
          1879,
          3,
          14,
          hour: 10,
          minute: 50,
          second: 12.345,
          calendar: Calendar.gregorian,
        ),
      );
    });

    test('zaokrąglenie tuż przed północą przechodzi na następny dzień', () {
      final d = calendarDateTime(2451545.5 - 1e-9);
      expect((d.year, d.month, d.day, d.hour), (2000, 1, 2, 0));
    });
  });
}
