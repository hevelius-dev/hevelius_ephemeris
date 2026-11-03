# Źródła

Hevelius jest pisany od zera. Każdy wzór, stała i zbiór danych musi mieć
tu wpis ze źródłem.

Zasady:

- nie czytamy ani nie tłumaczymy kodu Swiss Ephemeris ani SOFA;
- korzystamy wyłącznie z publikacji naukowych, standardów (IAU, IERS)
  i dokumentacji formatów danych (NASA NAIF, JPL);
- pakiet nie zależy od `sweph` – porównania ze Swiss Ephemeris robi
  aplikacja, poza tym pakietem.

## Stałe i epoki

| element | plik | źródło |
|---|---|---|
| J2000.0 = JD 2451545,0 TT; stulecie juliańskie = 36525 dni | `lib/src/time/epochs.dart` | IAU 1976 System of Astronomical Constants; Explanatory Supplement to the Astronomical Almanac, 3rd ed. (2013), rozdz. 3 |

## Czas

| element | plik | źródło |
|---|---|---|
| Dzień juliański ↔ data (kalendarz juliański i gregoriański), algorytm na liczbach całkowitych | `lib/src/time/calendar.dart` | E. G. Richards, „Calendars”, w: Explanatory Supplement to the Astronomical Almanac, 3rd ed. (2013), rozdz. 15.11; rozszerzony o dzielenie „w dół” dla ujemnych dni juliańskich |
| Reforma gregoriańska: 4.10.1582 (jul.) → 15.10.1582 (greg.) | `lib/src/time/calendar.dart` | bulla Inter gravissimas (1582) |
| ΔT, lata −720 … 1973: spline (tabela S15.2020) | `data/delta_t/Table-S15.2020.txt` → `lib/src/time/delta_t_data.dart` | L. V. Morrison, F. R. Stephenson, C. Y. Hohenkerk, M. Zawilski, „Addendum 2020 to ‘Measurement of the Earth's rotation: 720 BC to AD 2015’”, Proc. R. Soc. A 477 (2021), doi:10.1098/rspa.2020.0776; tabela z materiałów dodatkowych: „Tables S2, S3 and S5 from Addendum 2020…”, figshare, doi:10.6084/m9.figshare.13885863.v2, licencja CC BY 4.0 |
| ΔT, od 1973: pomiary miesięczne | `data/delta_t/deltat.data` → `lib/src/time/delta_t_data.dart` | U.S. Naval Observatory, https://maia.usno.navy.mil/ser7/deltat.data (pobrane 2026-10-30; dane rządu USA, public domain) |
| ΔT poza zakresem danych: parabola −320 + 32,5·((rok − 1825)/100)² s | `lib/src/time/delta_t.dart` | F. R. Stephenson, L. V. Morrison, C. Y. Hohenkerk, „Measurement of the Earth's rotation: 720 BC to AD 2015”, Proc. R. Soc. A 472 (2016), równ. (4.1), doi:10.1098/rspa.2016.0404 |
| Łączenie paraboli z danymi: poprawka liniowa, by zgadzały się wartość i tempo zmian ΔT (tempo po 2026 r. z ostatnich 24 miesięcy pomiarów) | `lib/src/time/delta_t.dart` | własna konstrukcja – praca nie podaje sposobu; ten sam pomysł (człon liniowy usuwający nieciągłość) stosują F. Espenak, J. Meeus, Five Millennium Canon of Solar Eclipses, NASA/TP-2006-214141 |

Uwagi o ΔT:

- Strona UKHO (astro.ukho.gov.uk) była 2026-10-30 niedostępna; tabelę
  S15.2020 pobrano z kopii w repozytorium Skyfield
  (github.com/skyfielders/python-skyfield, plik `Table-S15.2020.txt`,
  sha256 `cfcb7dfc…e723`). 2026-11-01 sprawdzone: plik jest identyczny
  z `Table-S15.2020.txt` w archiwum `rspa20200776_si_002.zip`
  z materiałów dodatkowych artykułu na figshare (CC BY 4.0). Poprawność sprawdzona testami: przedziały
  łączą się do 0,002 s, a spline zgadza się z niezależnymi pomiarami
  USNO z lat 1973–2019 do 0,3 s.
- Przyspieszenie pływowe Księżyca: autorzy ΔT zalecają efemerydę DE430
  (−25,82″/stulecie²) „lub inną o zbliżonej wartości” (Stephenson i in.
  2016). Artykuł o DE440 (Park i in. 2021) nie podaje jawnej liczby –
  przyspieszenie wynika z modelu pływów dopasowanego do pomiarów
  laserowych Księżyca. W zakresie de440s (1850–2150) ewentualna poprawka
  to ułamek sekundy; DO SPRAWDZENIA przy DE441 i datach starożytnych.
- Przyszłość (po ostatnim pomiarze) to ekstrapolacja – nikt nie zna
  przyszłego obrotu Ziemi. W latach 2027–2150 wynik różni się od Swiss
  Ephemeris 2.10 najwyżej o ok. 4 s.

Dane testowe: przykłady i tabela 7.a z J. Meeus, Astronomical Algorithms,
2nd ed. (1998), rozdz. 7.

## Efemerydy JPL i format SPK

| element | plik | źródło |
|---|---|---|
| Dane o ruchu ciał: DE440 (`de440.bsp`, 1550–2650; `de440s.bsp`, 1849–2150) | `data/jpl/` (poza gitem; `tool/download_jpl.dart`) | R. S. Park, W. M. Folkner, J. G. Williams, D. H. Boggs, „The JPL Planetary and Lunar Ephemerides DE440 and DE441”, Astron. J. 161:105 (2021); pliki: https://ssd.jpl.nasa.gov/ftp/eph/planets/ (NASA JPL; bez formalnej licencji – zob. „Licencje danych”) |
| Dane o ruchu ciał: DE441 (`de441.bsp`, −13200 … +17191; dla planet identyczne z DE440, Księżyc różni się do 0,27″ w 1600 r.) | `data/jpl/` (poza gitem; `tool/download_jpl.dart --de441`) | Park i in. (2021), jak wyżej |
| Dane o ruchu ciał: DE442 (`de442.bsp`, 1550–2650, plik z 15.07.2026) – zalecana dla aplikacji; względem DE440: Uran do 0,38″ w latach 1900–2100 (do 2,7″ w 2559 r.), Neptun do 0,43″, Mars do 0,27″ (2572 r.), reszta ≤ 0,03″ | `data/jpl/` (poza gitem; `tool/download_jpl.dart`) | NASA JPL, nagłówek „JPL Planetary Ephemeris DE442/LE442” (https://ssd.jpl.nasa.gov/ftp/eph/planets/ascii/de442/header.442); publikacja opisująca DE442 nie była dostępna 2026-11-02 (brak w ftp/eph/planets/ioms/) – DO UZUPEŁNIENIA |
| Format pliku DAF (nagłówek, spis segmentów, adresy) | `lib/src/spk/spk_file.dart` | NAIF, „DAF Required Reading” (dokumentacja SPICE, NASA) |
| Segmenty SPK typu 2 i 3, łańcuch ciał | `lib/src/spk/spk_file.dart`, `lib/src/spk/spk_ephemeris.dart` | NAIF, „SPK Required Reading” (dokumentacja SPICE, NASA) |
| Wielomiany Czebyszewa i ich pochodne (rekurencje) | `lib/src/spk/spk_file.dart` | M. Abramowitz, I. A. Stegun, Handbook of Mathematical Functions (1964), rozdz. 22 |
| Jednostka astronomiczna 149 597 870,7 km | `test/spk/testpo_test.dart` | IAU 2012, rezolucja B2 |

Dane testowe: `testpo.440` z https://ssd.jpl.nasa.gov/ftp/eph/planets/ascii/de440/
(oficjalne wartości kontrolne JPL) – zgodność do 2 mm dla de440s
(3099 wartości) i de440 (11 354 wartości, 1550–2650).
Także `testpo.441` (312 685 wartości, −13200 … +17191; do 4,3 mm) i
`testpo.442` (11 354 wartości; do 2,1 mm) – test `test/spk/large_ephemerides_test.dart`
(tag `duze-pliki`, uruchomienie `dart test -P duze-pliki`). W testpo.441 przy
latach ujemnych pola wiersza się sklejają („441-13200.09.01-3099998.5”) –
dzielimy wiersz wyrażeniem regularnym.

## Redukcje astronomiczne

| element | plik | źródło |
|---|---|---|
| TDB − TT ≈ 1,7 ms · sin l′ (tylko główny wyraz) | `lib/src/reduction/tdb.dart` | IERS Conventions (2010), IERS Technical Note 36, rozdz. 5.6.4 |
| Precesja IAU 2006 (funkcje `*Iau2006`, do porównań; w silniku tylko bias ramki z kątów w t = 0): kąty Fukushimy–Williamsa γ̄, φ̄, ψ̄ (z biasem ramki), średnie nachylenie ε_A | `lib/src/reduction/precession_nutation.dart` | IERS Conventions (2010), równ. (5.40); N. Capitaine, P. T. Wallace, J. Chapront, Astron. Astrophys. 412, 567 (2003); J. L. Hilton i in., Celest. Mech. Dyn. Astron. 94, 351 (2006) |
| Macierz R₁(−ε)·R₃(−ψ)·R₁(φ̄)·R₃(γ̄), konwencja obrotów R₁, R₃ | `lib/src/reduction/precession_nutation.dart`, `lib/src/math/vector3.dart` | IERS Conventions (2010), rozdz. 5.4.5 i 5.3; T. Fukushima, Astron. J. 126, 494 (2003) |
| **Precesja w silniku – model długookresowy (±200 000 lat):** biegun ekliptyki z P_A, Q_A (równ. 8, tabela 1; C₇ dla Q_A = 198,296701 wg poprawki), biegun równika z X_A, Y_A (równ. 9, tabela 2); wektor bieguna ekliptyki (P, −Q cos ε₀ − Z sin ε₀, −Q sin ε₀ + Z cos ε₀), Z = √(1 − P² − Q²) | `lib/src/reduction/long_term_precession.dart` | J. Vondrák, N. Capitaine, P. Wallace, „New precession expressions, valid for long time intervals”, A&A 534, A22 (2011), rozdz. 4.2 i dodatek A.1–A.2; poprawka A&A 541, C1 (2012) (PDF w ~/Claude_projects/źródła/) |
| Ekliptyka daty: oś x – punkt równonocy n × k, oś z – biegun ekliptyki k (macierz z dwóch biegunów); średnie nachylenie ε_A = kąt między n i k; nutacja w długości – obrót wokół bieguna ekliptyki daty; przejście GCRS → średni J2000 (bias) z kątów IAU 2006 w t = 0 | `lib/src/reduction/long_term_precession.dart`, `precession_nutation.dart` | Vondrák i in. (2011), równ. (23) (za Fabri 1980, Murray 1983); bias – IERS Conventions (2010) |
| Średni czas gwiazdowy: GMST = θ(UT1) + kąt od CIO do średniej równonocy daty; CIO przenoszony bez obrotu wokół bieguna (definicja kinematyczna) od osi x GCRS w J2000, dokładnym obrotem n(t) → n(t + 0,01 stulecia) (wzór Rodriguesa), tablica co 0,01 stulecia liczona w miarę potrzeb, interpolacja liniowa | `lib/src/reduction/long_term_precession.dart`, `sidereal_time.dart` | definicja CIO: N. Capitaine, P. T. Wallace (2006), A&A 450, 855 (za Vondrák i in. 2011, rozdz. 5.5); metoda numeryczna własna. Błąd kroku: 0,0002″ w −3000 (sprawdzone krokiem 0,001) |
| Szereg s_A (równ. 26, tabela 9) – przepisany i sprawdzony (s_A(0) = 0), ale NIEUŻYWANY: z macierzą równ. (24) dawał GMST różne od IAU 2006 o ok. 0,0726″·t³ (38 s czasu w roku 0), a przeniesienie CIO zgadza się z IAU 2006. Przyczyna nieustalona (DO WYJAŚNIENIA – może inna definicja s w równ. 24) | `lib/src/reduction/long_term_precession.dart` (`longTermCioLocator`) | Vondrák i in. (2011), rozdz. 5.5 |

Zgodność modelu długookresowego z IAU 2006 (pomiar 2026-11-02): w latach
1600–2500 długość ekliptyczna do 0,008″, nachylenie do 0,008″, GMST do
0,02″ (1,4 ms); w J2000 GMST − θ = 0,014600″ wobec 0,014506″ w IAU 2006
(różnica 0,000094″ = s₀, pominięte położenie CIO). Daleko od J2000 IAU 2006
się rozjeżdża: w roku 0 o 0,4″, w −3000 o 17″ (długość) i 12″
(nachylenie), w −13000 o ok. 0,5°. Nutacja IAU 2000A zostaje bez zmian
także w dalekich epokach (amplituda ok. 17″ – mało wobec niepewności ΔT).
| Nutacja IAU 2000A z poprawkami R06 (1358 + 1056 wyrazów) | `data/iers/tab5.3a.txt`, `tab5.3b.txt` → `lib/src/reduction/nutation_data.dart` | IERS Conventions (2010), tabele 5.3a i 5.3b, https://iers-conventions.obspm.fr/content/chapter5/additional_info/ (pobrane 2026-10-30) |
| Argumenty podstawowe nutacji F1–F14 | `lib/src/reduction/precession_nutation.dart` | IERS Conventions (2010), równ. (5.43) i (5.44) |
| Czas światła (iteracja), ugięcie światła przez Słońce, aberracja relatywistyczna | `lib/src/reduction/apparent.dart` | Explanatory Supplement to the Astronomical Almanac, 3rd ed. (2013), rozdz. 7; wzór na aberrację wyprowadzony z transformacji Lorentza |
| c = 299 792,458 km/s | `lib/src/reduction/apparent.dart` | definicja SI |
| GM Słońca = 1,3271244·10²⁰ m³/s², promień Słońca 695 700 km | `lib/src/reduction/apparent.dart` | IAU 2015, rezolucja B3 |
| Brak ugięcia światła dla ciała za tarczą Słońca | `lib/src/reduction/apparent.dart` | własna decyzja zgodna z wynikami NASA JPL Horizons (sprawdzone 2026-10-30) |

Dane testowe: `test/reduction/horizons_reference.csv` – wartości z NASA JPL
Horizons (https://ssd.jpl.nasa.gov/horizons/, pobrane 2026-10-30).

## Punkty orbity Księżyca i prędkości

| element | plik | źródło |
|---|---|---|
| Węzeł średni Ω i średnie perygeum Π | `lib/src/points/lunar_points.dart` | J. Chapront, M. Chapront-Touzé, G. Francou, „Introduction dans ELP 2000-82B de nouvelles valeurs des paramètres orbitaux de la Lune et du barycentre Terre-Lune”, Paryż (1998), za: J. Meeus, Astronomical Algorithms, 2nd ed. (1998), równ. (47.7), s. 343 |
| Lilith średnia jako rzut średniego apogeum na ekliptykę (z szerokością) | `lib/src/points/lunar_points.dart` | trygonometria sferyczna; test: J. Meeus, Astronomical Algorithms, przykład 47.a (L′, M′, F) – stała różnica 0,703″, bo L′ ze wzoru (47.1) różni się o 0,000195° od stałych wzorów na Ω i Π (węzeł L′ − F ma tę samą różnicę) |
| Średnie nachylenie orbity Księżyca 5,1453964° | `lib/src/points/lunar_points.dart` | WARTOŚĆ ROBOCZA – powszechnie podawane 5°08′43″. Ustalone 2026-11-02: 5,1453964° = 5°08′43,427″ = 2·arcsin γ dla γ = sin(i/2) = 0,044886967 – klasyczna stała nachylenia w teoriach Księżyca typu Hill–Brown (stała γ teorii Browna). Źródła pierwotnego z tą liczbą nadal nie odnaleziono (DO ZROBIENIA; sprawdzone: Meeus rozdz. 47, 51 i indeks; dokumentacja ELP/MPP02 Y.-T. Liu – podaje tylko poprawkę ΔΓ, bez samej wartości; artykuł Chapront i Francou 2003 niedostępny (strona A&A zwraca błąd HTTP 403). Kandydaci: E. W. Brown, Tables of the Motion of the Moon (1919); Explanatory Supplement (1961)). Wpływ na Lilith średnią (rzut apogeum na ekliptykę) – błąd 0,01° dałby ok. 2″ |
| Węzeł prawdziwy i Lilith oskulacyjna z chwilowej orbity: h = r × v, e = (v × h)/μ − r/|r|, wielka półoś z równania vis-viva | `lib/src/points/lunar_points.dart` | mechanika nieba (zagadnienie dwóch ciał), np. Explanatory Supplement (2013) |
| GM⊕ = 3,986004415·10¹⁴ m³/s² (TT), M☾/M⊕ = 0,0123000371 | `lib/src/points/lunar_points.dart` | IERS Conventions (2010), tabela 1.1 |
| Prędkość w długości: różnica centralna ±0,005 doby | `lib/src/reduction/speed.dart` | metoda numeryczna |

Porównanie ze Swiss Ephemeris 2.10 (2000 dat, 1850–2149): węzeł średni do
0,15″, prawdziwy do 0,11″, Lilith średnia i oskulacyjna do 0,83″,
prędkości planet do 0,03″/dobę poza okolicą tarczy Słońca. (Ze wzorami
Simona 1994 z IERS węzeł średni różnił się o 0,33″, a Lilith o 0,35″ –
wybrano jedno nowsze źródło dla obu punktów zamiast dopasowywać się do
Swiss.)

## Chiron i planetoidy

| element | plik | źródło |
|---|---|---|
| Położenia i prędkości barycentryczne (ICRF, TDB) co dobę, 1600–2500 (Horizons nie podaje planetoid przed 11.12.1599 ani po 1.01.2501 – sprawdzone 2026-10-30): Chiron (rozwiązanie orbity JPL#171), Ceres (JPL#48), Pallas (JPL#74), Juno (JPL#144), Westa (JPL#36) | `data/horizons/` (poza gitem) → `data/jpl/small_bodies.bsp` (`tool/build_small_bodies.dart`) | NASA JPL Horizons, https://ssd.jpl.nasa.gov/horizons/ (pobrane 2026-10-30; całkowanie z DE441 i 16 największymi planetoidami SB441-N16) |
| Dopasowanie wielomianów Czebyszewa stopnia 12 w przedziałach 32-dobowych (najmniejsze kwadraty), zapis jako SPK typu 2 | `lib/src/spk/chebyshev_fit.dart`, `lib/src/spk/spk_writer.dart` | metoda własna; format: NAIF „DAF Required Reading”, „SPK Required Reading” |
| Kody NAIF planetoid: 2 000 000 + numer | `tool/build_small_bodies.dart` | NAIF, „NAIF Integer ID codes” |

Kontrola dopasowania (wielomiany z dób parzystych, błąd w nieparzystych):
30–98 m (lata 1600–2500). Zgodność z Horizons: astrometrycznie poniżej 0,01″. Swiss
Ephemeris 2.10 różni się o 0,4–1″ średnio (do 8,6″ dla Pallas w XIX w.) –
różnica jest w samych orbitach (starsze rozwiązania w plikach Swiss),
najmniejsza w latach 1950–2049.

## Gwiazdy stałe

| element | plik | źródło |
|---|---|---|
| Położenie ICRS (epoka J2000), ruch własny, paralaksa, prędkość radialna, jasność V – 22 jasne i znane gwiazdy, dla każdej wartości bibcode publikacji | `data/stars/jasne_gwiazdy.csv` (wybór z pełnego katalogu budowanego przez `tool/build_fixed_stars.dart`) | baza SIMBAD, CDS Strasburg, https://simbad.cds.unistra.fr/ (pobrane 2026-10-31); M. Wenger i in., „The SIMBAD astronomical database”, Astron. Astrophys. Suppl. 143, 9 (2000). Wartości pochodzą z katalogów: F. van Leeuwen, „Validation of the new Hipparcos reduction”, Astron. Astrophys. 474, 653 (2007) – 21 gwiazd; B. D. Mason i in., Washington Double Star Catalog, Astron. J. 122, 3466 (2001) – położenie α Cen; prędkości radialne i jasności – publikacje podane w kolumnach bib_*. Celowo bez wartości z Gaia (licencja CC BY-NC 3.0 IGO wyklucza użycie komercyjne bez zgody ESA) |

| element | plik | źródło |
|---|---|---|
| Ruch gwiazdy w przestrzeni: liniowy, r(t) = r₀ + v·(t − t₀), v z ruchu własnego i prędkości radialnej; liczony w jednostkach odległości z epoki katalogu (r/d₀), więc paralaksa 0 nie jest szczególnym przypadkiem | `lib/src/stars/fixed_star.dart` | G. H. Kaplan, J. A. Hughes, P. K. Seidelmann, C. A. Smith, B. D. Yallop, „Mean and apparent place computations in the new IAU system. III. Apparent, topocentric, and astrometric places of planets and stars”, Astron. J. 97, 1197 (1989); Explanatory Supplement to the Astronomical Almanac, 3rd ed. (2013), rozdz. 7 |
| Paralaksa roczna: przesunięcie z barycentrum do środka Ziemi (położenie Ziemi z DE440); ugięcie światła i aberracja – jak dla planet; bez czasu światła | `lib/src/stars/fixed_star.dart` | jw. |
| Ujemna paralaksa (błąd pomiaru) liczona jak 0 | `lib/src/stars/fixed_star.dart` | własna decyzja – ujemna odległość odwróciłaby kierunek (tak robi Swiss Ephemeris 2.10: al-1Her i th-1Ori w sefstars.txt wychodzą o 180° obok) |
| Jednostka astronomiczna 149 597 870,7 km | `lib/src/stars/fixed_star.dart` | IAU 2012, rezolucja B2 |

Zgodność metody ze Swiss Ephemeris 2.10 na tych samych danych katalogowych
(liczby z sefstars.txt, 1110 obiektów, 12 dat 1850–2150, ekliptyka daty):
mediana 0,0004″, 99% poniżej 0,0016″, najwięcej 0,034″ (Sgr A*) –
osobne narzędzie porównawcze, poza tym pakietem. Testy własne
(`test/stars/`): ruch własny, paralaksa roczna, aberracja i ugięcie
światła zgodne z wielkościami z teorii.

## Czas gwiazdowy, ASC i MC

| element | plik | źródło |
|---|---|---|
| Kąt obrotu Ziemi θ(UT1); GMST według IAU 2006 (`greenwichMeanSiderealTimeIau2006`; w silniku – model długookresowy, zob. „Redukcje astronomiczne”) | `lib/src/reduction/sidereal_time.dart` | IERS Conventions (2010), IERS Technical Note 36, rozdz. 5, tabela 5.2e (współczynniki potwierdzone 2026-10-30; numery równań DO SPRAWDZENIA w pełnym tekście) |
| Prawdziwy czas gwiazdowy: GMST + Δψ·cos ε_A + wyrazy uzupełniające; prawdziwe nachylenie ε = ε_A + Δε | `lib/src/reduction/sidereal_time.dart` | IERS Conventions (2010), rozdz. 5; nutacja i ε_A jak wyżej |
| Wyrazy uzupełniające równania równonocy (33 + 1 wyrazów, razem < 0,003″; argumenty jak w nutacji) | `data/iers/tab5.2e.txt` → `lib/src/reduction/nutation_data.dart`, `precession_nutation.dart` | IERS Conventions (2010), tabela 5.2e, https://iers-conventions.obspm.fr/content/chapter5/additional_info/tab5.2e.txt (pobrane 2026-11-02) |
| ASC – to z dwóch przecięć ekliptyki z horyzontem (kierunki ±k × z: biegun ekliptyki × zenit), które leży po wschodniej stronie południka; MC: tg λ = tg ARMC / cos ε | `lib/src/angles/angles.dart` | definicja ascendentu (punkt wschodzący) i MC; własne wyprowadzenie (geometria wektorowa sfery). Za kołem podbiegunowym stała kolejność iloczynu wektorowego daje czasem punkt zachodni – stąd jawny wybór strony wschodniej |

Dane testowe: przykłady 12.a i 12.b z J. Meeus, Astronomical Algorithms,
2nd ed. (1998) – czas gwiazdowy (wzory IAU 1982, różnica 0,004 s);
horoskop wzorcowy: Albert Einstein, 14.03.1879 10:50 UT, Ulm, 48°24′ N,
10°00′ E – wszystko wobec NASA/JPL Horizons (zapytania 2026-11-03,
parametry w testach): ASC i MC z lokalnego pozornego czasu gwiazdowego
Horizons (22h56m44,1741s) i klasycznych wzorów (tg λ = tg ARMC / cos ε;
ASC = atan2(−cos ARMC, sin ε tg φ + cos ε sin ARMC)) – zgodne do 0,02″;
węzeł prawdziwy i Lilith oskulacyjna z elementów oskulacyjnych orbity
Księżyca z Horizons (przeniesionych z ekliptyki J2000 IAU 1976 do ICRF
i do ekliptyki daty) – do 0,05″ i 1 m; kierunek i prędkość ruchu planet
z długości Horizons ±12 h. Węzeł średni: J. Meeus, przykład 22.a
(Ω = 11,2531°) – 0,05″.

Położenia Słońca, Księżyca, planet, Chirona i czterech planetoid w tym
horoskopie – porównanie z NASA/JPL Horizons
(`test/reduction/reference_chart_test.dart`; zapytanie 2026-11-03,
DE441 i SB441-N16, ta sama chwila w TT): astrometrycznie w ICRF zgodne do
0,0001″ (Księżyc na DE440s: 0,005″ – różnica DE440/DE441); pozornie na
ekliptyce daty – stałe przesunięcie długości 0,30″ (rozrzut 0,296–0,314″)
i szerokość do 0,05″: Horizons liczy precesję i nutację modelami
IAU 1976/1980, my IAU 2006/2000A (różnica tempa precesji ok. 0,3″ na
stulecie).

Porównanie ze Swiss Ephemeris 2.10 (plik wzorcowy z osobnego narzędzia,
poza tym pakietem; 2000 dat 1850–2149, losowe miejsca o szerokości
−80°…80°; `tool/compare_reference.dart`):

- sama geometria (ARMC i ε ze Swiss): ASC i MC zgodne do 0,0000″, także
  za kołem podbiegunowym;
- całość, lata 1850–2049: ARMC do 0,004″, nachylenie ekliptyki do
  0,0014″;
- od 1.01.2050 ARMC ze Swiss skacze o 1,910″ (różnica przed i po tej
  dacie jest stała co do 0,01″, więc skok jest po stronie Swiss –
  przełączenie modelu czasu gwiazdowego); nasz model IAU 2006 jest
  ciągły.

## Zdarzenia: ingresy, stacje, pory roku

| element | plik | źródło |
|---|---|---|
| Równonoce i przesilenia: chwile, gdy pozorna długość geocentryczna Słońca wynosi 0°, 90°, 180°, 270° | `lib/src/events/crossings.dart` | definicja: J. Meeus, Astronomical Algorithms, 2nd ed. (1998), rozdz. 27, s. 177 |
| Szukanie przecięć: podział przedziału w stacjach (zmiana znaku prędkości) i co krok, w każdym kawałku długość monotoniczna i zmiana < 180°; pierwiastek metodą regula falsi w wariancie Illinois z bisekcją, do 1e-8 doby | `lib/src/events/crossings.dart` | metody numeryczne, np. M. Dowell, P. Jarratt, „A modified regula falsi method for computing the root of an equation”, BIT 11, 168 (1971); podział w stacjach – własna konstrukcja |

Dane testowe: przesilenie czerwcowe 1962 – 21h24m42s TD według pełnej
teorii VSOP87 (Meeus, przykład 27.a, s. 180); u nas 21h24m39s TT. Różnica
ok. 3 s to ok. 0,12″ w długości Słońca – Meeus stosuje VSOP87 z poprawką
do układu FK5, my DE440 w ICRS. Testy własne: liczba ingresów Merkurego,
Księżyca i węzła prawdziwego zgodna z próbkowaniem co 0,01 doby.

## Fazy Księżyca

| element | plik | źródło |
|---|---|---|
| Nów, I kwadra, pełnia, III kwadra: nadwyżka pozornej długości geocentrycznej Księżyca nad długością Słońca 0°, 90°, 180°, 270° | `lib/src/events/lunar_phases.dart` | definicja: J. Meeus, Astronomical Algorithms, 2nd ed. (1998), rozdz. 49, s. 349; szukanie chwil jak w „Zdarzenia” |

Dane testowe: nów 18.02.1977 3h37m40s TD według teorii ELP-2000/82
(Meeus, przykład 49.a, s. 353) – u nas 3h37m39,9s TT; III kwadra
21.01.2044 23h48m17s TD (przykład 49.b, metoda przybliżona Meeusa) – u nas
23h48m17,1s.

## Wschody, zachody, górowania, zmierzchy

| element | plik | źródło |
|---|---|---|
| Współrzędne równikowe daty: ekliptyka daty obrócona o −ε (prawdziwe nachylenie) | `lib/src/events/rise_set.dart` | IERS Conventions (2010), rozdz. 5.4.5 (ostatni obrót R₁(−ε) macierzy precesji–nutacji) |
| Wysokość: sin h = sin φ sin δ + cos φ cos δ cos H; kąt godzinny H = GAST + λ − α | `lib/src/events/rise_set.dart` | trygonometria sferyczna, np. J. Meeus, Astronomical Algorithms, 2nd ed. (1998), rozdz. 13 |
| Wysokości standardowe środka ciała przy wschodzie i zachodzie: gwiazdy i planety −0°34′, Słońce −0°50′, Księżyc 0,7275·π − 0°34′ (π – paralaksa horyzontalna) | `lib/src/events/rise_set.dart` | J. Meeus, Astronomical Algorithms, 2nd ed. (1998), rozdz. 15, s. 101–102 |
| Zmierzch cywilny, żeglarski, astronomiczny: środek Słońca na −6°, −12°, −18° | `lib/src/events/rise_set.dart` | Explanatory Supplement to the Astronomical Almanac, 3rd ed. (2013), definicje zmierzchu |
| Promień równikowy Ziemi 6378,1366 km (do paralaksy Księżyca) | `lib/src/events/rise_set.dart` | IERS Conventions (2010), tabela 1.1 |
| Szukanie: najpierw górowania i dołowania (kąt godzinny 0° i 180°), między nimi wysokość monotoniczna – w każdym odcinku najwyżej jeden wschód lub zachód; bisekcja do 1e-8 doby | `lib/src/events/rise_set.dart` | własna konstrukcja (jak podział w stacjach w „Zdarzenia”) |

Dane testowe: Wenus nad Bostonem 20.03.1988 (Meeus, przykład 15.a, s. 103–104):
wschód 12h25m26s, górowanie 19h40m31s, zachód 2h54m40s UT – u nas
12h25m25,6s, 19h40m30,4s, 2h54m40,0s (Meeus podaje ułamki doby
z dokładnością ok. 0,4 s). Testy własne: dzień polarny w Tromsø, liczba
wschodów i zachodów Księżyca za kołem podbiegunowym zgodna z próbkowaniem
co 2 minuty.

## Zaćmienia

| element | plik | źródło |
|---|---|---|
| Definicje: gamma (najmniejsza odległość osi cienia od środka Ziemi, w promieniach równikowych), zaćmienie centralne, niecentralne, wielkość fazy zaćmienia częściowego (1,5433 + u − \|γ\|)/(0,5461 + 2u), promienie cienia i półcienia | `lib/src/events/eclipses.dart` | J. Meeus, Astronomical Algorithms, 2nd ed. (1998), rozdz. 54, s. 381–383 |
| Płaszczyzna podstawowa (przez środek Ziemi, prostopadle do osi cienia Księżyca), stożki półcienia i cienia: sin f = (R☉ ± R☾)/odległość Słońce–Księżyc, wierzchołki c = z ± k/sin f, promienie l = c·tg f | `lib/src/events/eclipses.dart` | geometria stożków (elementy Bessela), por. Meeus, rozdz. 54; własne wyprowadzenie |
| Wielkość fazy zaćmienia centralnego: stosunek średnic Księżyca i Słońca = (L₁ − L₂)/(L₁ + L₂) w punkcie na osi | `lib/src/events/eclipses.dart` | własne wyprowadzenie z geometrii stożków; definicja wielkości jak w kanonie NASA (Espenak, Meeus) |
| Zaćmienie hybrydowe: całkowite w punkcie największego zaćmienia (L₂ < 0), a wierzchołek stożka cienia nad brzegiem Ziemi (l₂ > 0) | `lib/src/events/eclipses.dart` | własne kryterium geometryczne |
| Kontur Ziemi na płaszczyźnie podstawowej: elipsa, półoś w kierunku y √(1 − e² cos² d); spłaszczenie 1/298,25642 | `lib/src/events/eclipses.dart` | IERS Conventions (2010), tabela 1.1; Meeus rozdz. 54 (stała 0,9972 – średni promień biegunowy) |
| k = 0,2725076 (półcień), 0,2722810 (cień); promień Księżyca 1737,4 km | `lib/src/events/eclipses.dart` | wartości jak w kanonie NASA (Espenak, Meeus); IAU 2015 (promień średni) |
| Powiększenie cienia Ziemi: Danjon Rp = 1,01·πₘ + s☉ + π☉, Rᵤ = 1,01·πₘ − s☉ + π☉; Chauvenet Rp,ᵤ = 1,02·(0,998340·πₘ ± s☉ + π☉) | `lib/src/events/eclipses.dart` | F. Espenak, „Enlargement of Earth's Shadows”, https://eclipse.gsfc.nasa.gov/LEcat5/shadow.html (pobrane 2026-11-01) – wzory (1-3)–(1-6); A. Danjon (1951), W. Chauvenet (1891) |
| Największe zaćmienie: minimum odległości (metoda złotego podziału do 1e-7 doby) w pobliżu nowiu lub pełni; zaćmienie możliwe tylko przy |β☾| < 1,8° | `lib/src/events/eclipses.dart` | metoda numeryczna; próg z zapasem względem granic zaćmień (Meeus, rozdz. 54) |

Dane testowe: kanon NASA (F. Espenak, J. Meeus, Five Millennium Canon of
Solar/Lunar Eclipses), tabele dekad 2021–2030 ze strony
https://eclipse.gsfc.nasa.gov/ (pobrane 2026-11-01): wszystkie 22
zaćmienia Słońca i 22 Księżyca znalezione, rodzaje zgodne, czasy maksimum
do 1,5 s, wielkości fazy do 0,001. NASA liczy teoriami VSOP87 i ELP-2000/82.
Zaćmienia niecentralne 2014-04-29, 2043-04-09, 2043-10-03 – rodzaj z listy
Meeusa (s. 382), wielkości z NASA.

### Lokalne okoliczności zaćmień Słońca

| element | plik | źródło |
|---|---|---|
| Obserwator: ρ sin φ′, ρ cos φ′ ze szerokości geodezyjnej i wysokości (spłaszczenie jak wyżej) | `lib/src/events/eclipses.dart` | J. Meeus, Astronomical Algorithms, 2nd ed. (1998), rozdz. 11 |
| Obserwator na płaszczyźnie podstawowej (ξ, η, ζ): rzut położenia w układzie prawdziwego równika daty (obrót o GAST + λ) na osie płaszczyzny; promienie stożków na wysokości obserwatora L = l − ζ·tg f; odległość od osi m = √(u² + v²), u = x − ξ, v = y − η | `lib/src/events/eclipses.dart` | metoda elementów Bessela: Explanatory Supplement to the Astronomical Ephemeris (1961), rozdz. 9; tu z wektorów zamiast wielomianów |
| Kontakty: I, IV – m = L₁, II, III – m = \|L₂\| (bisekcja do 1e-8 doby); maksimum – minimum m (złoty podział) w ±0,2 doby od największego zaćmienia | `lib/src/events/eclipses.dart` | jak wyżej; metody numeryczne |
| Wielkość fazy (L₁ − m)/(L₁ + L₂); stosunek średnic (L₁ − L₂)/(L₁ + L₂); zakrycie – pole części wspólnej dwóch kół przy odległości środków 2m/(L₁ + L₂) w promieniach Słońca | `lib/src/events/eclipses.dart` | Explanatory Supplement (1961), rozdz. 9; pole części wspólnej kół – geometria elementarna |
| Kąt pozycyjny P = atan2(u, v), od północy przez wschód | `lib/src/events/eclipses.dart` | Explanatory Supplement (1961), rozdz. 9; konwencja potwierdzona obrazkiem USNO (niżej) |
| Wysokość i azymut Słońca (bez refrakcji); widoczne, gdy środek wyżej niż −50′ | `lib/src/events/eclipses.dart` | trygonometria sferyczna (Meeus, rozdz. 13); próg jak dla wschodów Słońca |
| Księżyc jako kula (k jak wyżej), bez profilu brzegu; ruch bieguna pominięty | – | uproszczenie jak w kanonie NASA; kontakty II i III mogą różnić się od obserwowanych o 1–2 s |

Dane testowe: elementy Bessela NASA (F. Espenak, NASA GSFC; strony SEgoogle,
np. https://eclipse.gsfc.nasa.gov/SEgoogle/SEgoogle2001/SE2024Apr08Tgoogle.html,
pobrane 2026-11-02) dla zaćmień 2023-10-14, 2024-04-08 i 2026-08-12;
kontakty liczone z nich w teście niezależną, podręcznikową metodą, przy ΔT
NASA (70,5–71,4 s). Zgodność w 8 miejscach: maksimum ok. +0,5 s (różnica
efemeryd), I kontakt +0,8…+2,6 s, IV −0,8…0 s (nasz promień Słońca 695 700 km
wobec ok. 696 000 km u NASA – mniejszy półcień), II i III do 2 s, wielkość
fazy do 0,0004, kąty P do ok. 2°. Skrypt NASA SEcirc.js (X. Jubier) – nie
używany ani nie kopiowany.

Dodatkowo: wynik USNO dla Torreón (8.04.2024; archiwum strony
aa.usno.navy.mil/data/docs/Eclipse2024.php z 2016 r. w
webarchive.library.unt.edu, obrazek LocalTorreon.png) odtwarzamy przy
ΔT ≈ 76–77 s (prognoza ΔT z 2016 r., nieznana) – do 1–2 s; USNO podaje
dłuższą fazę całkowitą i większą wielkość (1,019169), bo używa jednego
k = 0,2725076 także dla cienia.

### Kontakty i widoczność zaćmień Księżyca

| element | plik | źródło |
|---|---|---|
| Kontakty P1, P4: d = Rp + s☾; U1, U4: d = Rᵤ + s☾; U2, U3: d = Rᵤ − s☾ (d – odległość środka Księżyca od punktu przeciwległego Słońcu, R – promienie cienia z powiększeniem jak wyżej, s☾ – promień tarczy Księżyca); bisekcja do 1e-8 doby w ±0,25 doby od maksimum | `lib/src/events/eclipses.dart` | definicje kontaktów: Explanatory Supplement (1961), rozdz. 9; F. Espenak, karty LEplot NASA |
| Wysokość topocentryczna Księżyca: h − p, sin p = ρ·sin π·cos h | `lib/src/events/eclipses.dart` | J. Meeus, Astronomical Algorithms, rozdz. 40 (paralaksa w wysokości) |
| Księżyc widoczny, gdy środek wyżej niż −34′ − s☾ (górny brzeg nad horyzontem przy standardowej refrakcji) | `lib/src/events/eclipses.dart` | jak dla wschodów (refrakcja 34′) |

Dane testowe: karty NASA LEplot (F. Espenak, NASA GSFC,
https://eclipse.gsfc.nasa.gov/LEplot/LEplot2001/, pobrane 2026-11-02;
obrazy w PDF, odczytane ręcznie) dla 2022-11-08, 2024-03-25, 2024-09-18,
2025-03-14, 2025-09-07: kontakty w UT do pełnej sekundy, ΔT z różnicy TD − UT
maksimum. Zgodność do 3,3 s (najczęściej do 2 s); faza całkowita u nas o 3–5 s
dłuższa. Widoczność 14.03.2025: Chicago (cała), Nowe Delhi (nic) – zgodnie
z mapą na karcie NASA; Warszawa – zgodnie z naszym czasem zachodu Księżyca;
paralaksa zgodna z π z karty NASA.

## Współrzędne horyzontalne

| element | plik | źródło |
|---|---|---|
| Obserwator: ρ sin φ′, ρ cos φ′ ze szerokości geodezyjnej i wysokości; położenie w układzie prawdziwego równika daty przez lokalny prawdziwy czas gwiazdowy | `lib/src/reduction/horizontal.dart` | J. Meeus, Astronomical Algorithms, 2nd ed. (1998), rozdz. 11 |
| Paralaksa: wektor topocentryczny = pozorny wektor geocentryczny − położenie obserwatora (dokładnie, także odchylenie promienia od pionu); aberracja dobowa (≤ 0,32″) pominięta | `lib/src/reduction/horizontal.dart` | geometria wektorowa; por. Meeus, rozdz. 40 |
| Wysokość i azymut (od północy przez wschód) z kąta godzinnego, deklinacji i szerokości geodezyjnej | `lib/src/reduction/horizontal.dart` | trygonometria sferyczna, Meeus, rozdz. 13 |
| Refrakcja: R = 1,02′/tg(h + 10,3/(h + 5,11)) + 0,0019279′ (wzór Sæmundssona dla wysokości geometrycznej, z poprawką zerującą w zenicie), × (P/1010)·(283/(273 + T)); poniżej −1° wartość z −1° | `lib/src/reduction/horizontal.dart` | Meeus, rozdz. 16, wzór (16.4) i mnożnik ciśnienia i temperatury (s. 106–107); przy horyzoncie refrakcja waha się o ok. 0,3° (Schaefer i Liller, za Meeusem) |

Dane testowe: `test/reduction/horizons_topocentric.csv` – NASA JPL Horizons
(DE441, pobrane 2026-11-02), Warszawa 52,2297° N, 21,0122° E, 0,1 km,
Księżyc, Słońce, Wenus, Mars, Jowisz co 6 h przez 2 doby, z refrakcją
(model Horizons) i bez. Zgodność do 0,7″ w azymucie i 0,4″ w wysokości
(bez refrakcji), 0,5″ i 0,3″ z refrakcją nad horyzontem; reszta – aberracja
dobowa i ΔT/UT1. Refrakcja: przykład 16.a Meeusa (24,618′ + poprawka
zenitalna).

## Licencje danych

Stan sprawdzony 2026-11-01. Kod pakietu jest własny; poniżej – dane
cudze, które pakiet zawiera albo pobiera. Przed publikacją i sprzedażą
DO SPRAWDZENIA przez prawnika (zwłaszcza pozycje oznaczone „ryzyko”).

| dane | w repozytorium | warunki |
|---|---|---|
| ΔT od 1973, USNO (`deltat.data`) | tak | dane rządu USA – public domain |
| ΔT −720…1973, tabela S15.2020 (`Table-S15.2020.txt` i współczynniki w `delta_t_data.dart`) | tak | CC BY 4.0 – materiały dodatkowe artykułu na figshare (doi:10.6084/m9.figshare.13885863.v2; sprawdzone 2026-11-01, plik identyczny). Sam artykuł (Proc. R. Soc. A 477, 2021) jest „All rights reserved” – korzystamy tylko z tabeli, nie z tekstu. Wymagane uznanie autorstwa |
| Nutacja IAU 2000A i równanie równonocy, tabele 5.3a, 5.3b i 5.2e IERS (`data/iers/`, `nutation_data.dart`) | tak | IERS Conventions (2010), IERS TN 36, © Verlag des Bundesamts für Kartographie und Geodäsie (2010); brak jawnej licencji na tabele. Współczynniki to model przyjęty przez IAU (rezolucje 2000 B1.6 i 2006 B1), powszechnie redystrybuowany (np. w bibliotece ERFA na licencji BSD); niskie ryzyko, wymagane cytowanie |
| Efemerydy JPL DE440/DE440s/DE441/DE442, testpo.440/441/442 | nie (pobiera `tool/download_jpl.dart`) | JPL nie podaje licencji ani warunków; JPL prowadzi Caltech, więc nie są to automatycznie dzieła rządu USA. JPL prosi o cytowanie (Park i in. 2021). Aplikacja, która dołącza pliki, powinna mieć pisemne potwierdzenie z JPL SSD (kontakt na stronie https://ssd.jpl.nasa.gov/planets/eph_export.html) |
| JPL Horizons (`test/reduction/horizons_reference.csv`, `horizons_topocentric.csv`, `tool/build_small_bodies.dart`) | tylko małe dane testowe | jak wyżej – bez formalnej licencji; cytowanie usługi |
| Gwiazdy: SIMBAD (`data/stars/jasne_gwiazdy.csv`) | tak | warunki CDS (https://cds.unistra.fr/legals/): zbiory danych z informacją publiczną na Licence Ouverte, ODbL albo CC-BY; obowiązkowe cytowanie „CDS/SIMBAD” i podziękowanie. Zakaz użytku komercyjnego bez zgody dotyczy logotypów CDS/SIMBAD, nie danych. Wartości z Hipparcosa (van Leeuwen 2007) i WDS (USNO) – bez Gaia |
| Przykłady z J. Meeus, Astronomical Algorithms; wartości z NASA/JPL Horizons | tylko w testach | pojedyncze wartości liczbowe jako dane kontrolne, z cytowaniem; tekstu książki nie kopiujemy |
| Kanon zaćmień NASA (Espenak, Meeus) i kontakty z kart LEplot (Espenak), wartości w `test/events/eclipses_test.dart`; elementy Bessela NASA (Espenak) w `test/events/local_eclipse_test.dart` | tylko w testach | dzieło NASA GSFC – public domain; podziękowanie: „Eclipse Predictions by Fred Espenak, NASA's GSFC” |

Gaia (ESA): dane na licencji CC BY-NC 3.0 IGO; użycie komercyjne wymaga
wcześniejszej zgody ESA (data.licences@esa.int,
https://www.cosmos.esa.int/web/esdc/terms-and-conditions). Dlatego
w tym pakiecie nie ma wartości z Gaia.
