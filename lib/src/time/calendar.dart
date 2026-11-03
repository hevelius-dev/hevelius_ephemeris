// Copyright 2026 Mirosław Kozłowski
// SPDX-License-Identifier: Apache-2.0

/// The calendar a date is expressed in.
enum Calendar {
  /// Julian calendar (a leap year every 4 years).
  julian,

  /// Gregorian calendar (1700, 1800, 1900, 2100… are not leap years).
  gregorian,
}

/// Julian day of 15 October 1582, 0:00 – the first day of the Gregorian
/// calendar. Earlier moments use the Julian calendar by default.
const double gregorianReformJulianDay = 2299160.5;

/// A date and time in a specific [calendar].
///
/// Years use astronomical numbering: year 0 is 1 BC, year −1 is 2 BC.
class CalendarDateTime {
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;

  /// Seconds with fraction (millisecond resolution).
  final double second;

  final Calendar calendar;

  const CalendarDateTime(
    this.year,
    this.month,
    this.day, {
    this.hour = 0,
    this.minute = 0,
    this.second = 0,
    required this.calendar,
  });

  @override
  bool operator ==(Object other) =>
      other is CalendarDateTime &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.hour == hour &&
      other.minute == minute &&
      other.second == second &&
      other.calendar == calendar;

  @override
  int get hashCode =>
      Object.hash(year, month, day, hour, minute, second, calendar);

  @override
  String toString() {
    String two(int v) => v.toString().padLeft(2, '0');
    final sec = second.toStringAsFixed(3).padLeft(6, '0');
    final cal = calendar == Calendar.julian ? 'Jul.' : 'Greg.';
    return '$year-${two(month)}-${two(day)} '
        '${two(hour)}:${two(minute)}:$sec ($cal)';
  }
}

/// Julian day for the date [year]-[month]-[day] and time in [calendar].
///
/// When [calendar] is omitted, dates from 15 October 1582 on are Gregorian
/// and earlier ones Julian; 5–14 October 1582 then do not exist.
/// Throws [ArgumentError] for a date that does not exist.
double julianDay(
  int year,
  int month,
  int day, {
  int hour = 0,
  int minute = 0,
  double second = 0,
  Calendar? calendar,
}) {
  final cal = calendar ?? _defaultCalendar(year, month, day);
  _checkDate(year, month, day, cal);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw ArgumentError('Invalid time $hour:$minute');
  }
  if (second < 0 || second >= 60) {
    throw ArgumentError('Invalid seconds $second');
  }
  // Dzień juliański zaczyna się w południe, stąd −0,5.
  return _dayNumber(year, month, day, cal) -
      0.5 +
      (hour * 3600 + minute * 60 + second) / 86400;
}

/// The date and time of the Julian day [jd].
///
/// When [calendar] is omitted it is chosen as in [julianDay] (see
/// [gregorianReformJulianDay]). The result is rounded to the millisecond.
CalendarDateTime calendarDateTime(double jd, {Calendar? calendar}) {
  final cal =
      calendar ??
      (jd >= gregorianReformJulianDay ? Calendar.gregorian : Calendar.julian);
  var dayNumber = (jd + 0.5).floor();
  var millis = ((jd + 0.5 - dayNumber) * 86400000).round();
  if (millis == 86400000) {
    // Zaokrąglenie przeskoczyło na północ następnego dnia.
    dayNumber += 1;
    millis = 0;
  }
  final (year, month, day) = _civilDate(dayNumber, cal);
  return CalendarDateTime(
    year,
    month,
    day,
    hour: millis ~/ 3600000,
    minute: millis ~/ 60000 % 60,
    second: millis % 60000 / 1000,
    calendar: cal,
  );
}

/// Number of days in [month] of [year] in [calendar].
int daysInMonth(int year, int month, Calendar calendar) {
  if (month == 2) return _isLeapYear(year, calendar) ? 29 : 28;
  return const [31, 0, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1];
}

bool _isLeapYear(int year, Calendar calendar) =>
    year % 4 == 0 &&
    (calendar == Calendar.julian || year % 100 != 0 || year % 400 == 0);

Calendar _defaultCalendar(int year, int month, int day) {
  final ymd = year * 10000 + month * 100 + day;
  if (ymd >= 15821015) return Calendar.gregorian;
  if (ymd >= 15821005) {
    throw ArgumentError(
      'Date $year-$month-$day does not exist (Gregorian reform); '
      'pass the calendar explicitly',
    );
  }
  return Calendar.julian;
}

void _checkDate(int year, int month, int day, Calendar calendar) {
  if (month < 1 || month > 12) {
    throw ArgumentError('Invalid month $month');
  }
  if (day < 1 || day > daysInMonth(year, month, calendar)) {
    throw ArgumentError('Invalid day $year-$month-$day');
  }
}

// Algorytm E. G. Richardsa (Explanatory Supplement, 3rd ed., rozdz. 15.11)
// z dzieleniem i resztą „w dół”, dzięki czemu działa też dla dni
// juliańskich ujemnych (przed 4713 p.n.e.).
const _y = 4716, _j = 1401, _m = 2, _n = 12, _r = 4, _p = 1461;
const _v = 3, _u = 5, _s = 153, _w = 2, _b = 274277, _c = -38;

/// Numer dnia juliańskiego (dzień zaczynający się w południe).
int _dayNumber(int year, int month, int day, Calendar calendar) {
  final h = month - _m;
  final g = year + _y - _div(_n - h, _n);
  final f = (h - 1 + _n) % _n;
  final e = _div(_p * g, _r) + day - 1 - _j;
  var j = e + _div(_s * f + _w, _u);
  if (calendar == Calendar.gregorian) {
    j -= _div(3 * _div(g + 184, 100), 4) + _c;
  }
  return j;
}

(int, int, int) _civilDate(int dayNumber, Calendar calendar) {
  var f = dayNumber + _j;
  if (calendar == Calendar.gregorian) {
    f += _div(_div(4 * dayNumber + _b, 146097) * 3, 4) + _c;
  }
  final e = _r * f + _v;
  final g = _div(e % _p, _r);
  final h = _u * g + _w;
  final day = _div(h % _s, _u) + 1;
  final month = (_div(h, _s) + _m) % _n + 1;
  final year = _div(e, _p) - _y + _div(_n + _m - month, _n);
  return (year, month, day);
}

/// Dzielenie całkowite zaokrąglane w dół (`~/` w Darcie obcina do zera).
int _div(int a, int b) => (a - a % b) ~/ b;
