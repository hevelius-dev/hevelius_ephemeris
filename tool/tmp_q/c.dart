import 'dart:io';
import 'dart:math' as math;
import 'package:hevelius_ephemeris/hevelius_ephemeris.dart';
const deg = math.pi / 180;
double asec(double a, double b) { var d = (a - b) % 360; if (d > 180) d -= 360; return d * 3600; }
void main() {
  final eph = SpkEphemeris([SpkFile.fromBytes(File('data/jpl/de440s.bsp').readAsBytesSync())]);
  // 1. Meeus 22.a: Ω (średnia równonoc) 11.2531° w JDE 2446895.5
  var jd = 2446895.5; var t = centuriesSinceJ2000(jd); var dpsi = nutation(t).longitude / deg;
  print('Ω Meeus22a: ${asec(lunarPoint(eph, LunarPoint.meanNode, jd).longitude - dpsi, 11.2531).toStringAsFixed(3)}″');
  // 2. Meeus 47.a: L′=134.290182, M′=5.150833, F=219.889721 w JDE 2448724.5
  jd = 2448724.5; t = centuriesSinceJ2000(jd); dpsi = nutation(t).longitude / deg;
  final node = 134.290182 - 219.889721, apo = 134.290182 - 5.150833 + 180;
  final u = (apo - node) * deg, i = 5.1453964 * deg;
  final lon = node + math.atan2(math.sin(u) * math.cos(i), math.cos(u)) / deg;
  final p = lunarPoint(eph, LunarPoint.meanApogee, jd);
  print('Ω z L′−F: ${asec(lunarPoint(eph, LunarPoint.meanNode, jd).longitude - dpsi, node).toStringAsFixed(3)}″');
  print('Lilith z L′−M′: ${asec(p.longitude - dpsi, lon).toStringAsFixed(3)}″ lat ${((p.latitude - math.asin(math.sin(u)*math.sin(i))/deg)*3600).toStringAsFixed(3)}″');
  // 3. Horizons elementy J2000
  jd = 2451545.0; t = centuriesSinceJ2000(jd); dpsi = nutation(t).longitude / deg;
  final tn = lunarPoint(eph, LunarPoint.trueNode, jd);
  print('węzeł prawdziwy − Horizons OM: ${asec(tn.longitude - dpsi, 123.9580554371928).toStringAsFixed(4)}″');
  const om = 123.9580554371928, inc = 5.240273000309245, w = 308.9226727206595;
  final ua = (w + 180) * deg;
  final alon = om + math.atan2(math.sin(ua) * math.cos(inc * deg), math.cos(ua)) / deg;
  final alat = math.asin(math.sin(ua) * math.sin(inc * deg)) / deg;
  final oa = lunarPoint(eph, LunarPoint.osculatingApogee, jd);
  print('apogeum osk.: dlon ${asec(oa.longitude - dpsi, alon).toStringAsFixed(4)}″ dlat ${((oa.latitude - alat) * 3600).toStringAsFixed(4)}″ dist ${(oa.distance - 405988.8382805416).toStringAsFixed(4)} km');
  // 4. ASC/MC z LAST Horizons
  final armc = 344.1840588 , phi = 48.4;
  final jdUt = julianDay(1879, 3, 14, hour: 10, minute: 50);
  final eps = trueObliquity(centuriesSinceJ2000(julianDayTT(jdUt))) / deg;
  final r = armc * deg, e = eps * deg, f = phi * deg;
  final mc = (math.atan2(math.tan(r), math.cos(e)) / deg + (math.cos(r) < 0 ? 180 : 0)) % 360;
  final asc = (math.atan2(-math.cos(r), math.sin(e) * math.tan(f) + math.cos(e) * math.sin(r)) / deg + 180) % 360;
  final a = angles(jdUt, phi, 10);
  print('eps $eps; ASC wzór $asc ours ${a.ascendant} d ${asec(a.ascendant, asc).toStringAsFixed(3)}″; MC wzór $mc d ${asec(a.midheaven, mc).toStringAsFixed(3)}″');
}
