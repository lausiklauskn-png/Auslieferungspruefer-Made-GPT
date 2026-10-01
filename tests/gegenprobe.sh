#!/usr/bin/env bash
# Gegenprobe: wird jeder Wächter auch WIRKLICH rot?
#
# Ein Test, der grün ist, weil er nichts prüft, ist schlimmer als kein Test — er
# erzeugt Vertrauen ohne Deckung. Diese Datei baut die Fehler nacheinander
# absichtlich wieder ein und verlangt, dass der Smoke jedes Mal umfällt.
#
#   bash tests/gegenprobe.sh
#
# Alle Änderungen werden danach zurückgenommen; das Arbeitsverzeichnis bleibt
# so, wie es war.

set -u
cd "$(dirname "$0")/.."

gruen=0
rot=0; tot=0

sichern() { cp "$1" "/tmp/gp_$(echo "$1" | tr / _).bak"; }
zurueck() { cp "/tmp/gp_$(echo "$1" | tr / _).bak" "$1"; }

# ⚠ ABBRUCH-SICHERUNG. Am 2026-08-09 wurde dieser Lauf mittendrin abgebrochen —
# und liess die eingebaute Sabotage in assets/studio.js STEHEN. Der Smoke war
# danach rot, und es sah aus, als sei der Code kaputt; kaputt war nur die
# Aufraeum-Zeile, die nie drankam. Ein Werkzeug, das absichtlich Fehler einbaut,
# muss sie auch dann zurueckbauen, wenn es stirbt.
AKTUELL=""
ALLE_AKTUELL=""
aufraeumen() {
  if [ -n "$AKTUELL" ]; then
    zurueck "$AKTUELL"
    echo "  ⟲ abgebrochen — $AKTUELL wiederhergestellt"
    AKTUELL=""
  fi
  if [ -n "$ALLE_AKTUELL" ]; then
    for d in $ALLE_AKTUELL; do zurueck "$d"; done
    echo "  ⟲ abgebrochen — $ALLE_AKTUELL wiederhergestellt"
    ALLE_AKTUELL=""
  fi
}
trap aufraeumen INT TERM EXIT

# Manche Fehler lassen sich nicht mit einem `sed` einbauen — eine vertauschte
# Reihenfolge zweier Abschnitte zum Beispiel. Dafuer gibt es diese zweite
# Fassung: sie nimmt einen beliebigen Befehl statt eines sed-Ausdrucks.

# ⚠ DER EIGENE SMOKE-AUFRUF HAT SEIT DEM 2026-09-11 EINE FRIST — und der Grund
# ist derselbe, den diese Sitzung im Smoke behoben hat. Ein Fall, der die Frist
# am Kindprozess ausbaut (Fall „ohne Frist haengt der Laeufer"), laesst
# `node tests/smoke_pruefer.mjs` NIE zurueckkehren. Ohne die Frist hier haette dieser
# eine Fall den ganzen Lauf zum Stehen gebracht, und am Ende stuende keine Zahl
# da — Kimhubs sechste Art, wie eine Gegenprobe nichts misst.
# GEMESSEN 2026-09-11: ein voller Smoke-Lauf braucht 10 s. 300 s sind das
# Dreissigfache; eine Maschine muesste dreissigmal langsamer sein, damit ein
# gesunder Lauf hier faellt. `timeout` meldet 124 — also nicht null, also „rot",
# und genau das ist fuer einen haengenden Laeufer richtig.
FRIST=300

# ⚠ DERSELBE DRITTE AUSGANG WIE BEI `probe`, und hier war er noch noetiger: der
# Python-Block wirft zwar „ANKER NICHT GEFUNDEN", aber `eval` schluckt das, und
# der Smoke lief trotzdem. Fuenf Faelle meldeten sich am 2026-09-14 als „BLIND",
# obwohl ihr Anker mit dem A18-Umzug schlicht weggezogen war.
# ══ ÜBERNOMMEN AUS PWA TOOLPOINT (2026-09-26) ════════════════════════════════
# Diese Datei ist eine KOPIE von PWA-Toolpoint/tests/gegenprobe.sh, gemessen
# gegen tests/smoke_pruefer.mjs statt gegen tests/smoke.mjs. Gefahren werden
# NUR die Fälle, die eine Datei DES PRÜFERS sabotieren. Alle übrigen gehören
# zum Marktplatz; sie werden gezählt und in der Schlusszeile genannt, nicht
# stillschweigend weggelassen.
#
# ⚠ Ein Fall, der hier BLIND meldet, kann in PWA Toolpoint von smoke.mjs
# gefangen werden — dessen Text-Wächter sind nicht mitgekommen. „Blind" heißt
# hier also: in DIESEM Depot bewacht ihn niemand.
#
# ⚠ SIE SABOTIERT DEN ARBEITSBAUM. Lauf in einer Kopie:
#   cp -a . ../ap-kopie && cd ../ap-kopie && bash tests/gegenprobe.sh
marktplatz=0
nur_pruefer() {                 # nur_pruefer <Datei ...> — 0, wenn alle zum Prüfer gehören
  local d
  for d in "$@"; do
    case "$d" in
      auslieferungspruefer.html|start.html|index.html|assets/start.css|assets/sprache.js|assets/pruefer*|assets/i18n-pruefer.js|assets/config/pruefer-netz.js|werkzeuge/*|vendor/pdfjs/*) ;;
      *) return 1 ;;
    esac
    [ -f "$d" ] || return 1
  done
  return 0
}
probe_befehl() {                # probe_befehl <Beschreibung> <Datei> <Befehl>
  local was="$1" datei="$2" befehl="$3"
  nur_pruefer "$datei" || { marktplatz=$((marktplatz + 1)); return; }
  faellt_aus "$was" && return
  sichern "$datei"
  AKTUELL="$datei"
  local vorher; vorher=$(cat "$datei")
  eval "$befehl"
  if [ "$vorher" = "$(cat "$datei")" ]; then
    echo "  ⚠ ANKER TOT: $was — der Befehl aendert nichts, der Fall misst NICHTS"
    tot=$((tot + 1))
    zurueck "$datei"; AKTUELL=""; return
  fi
  if timeout "$FRIST" node tests/alle.mjs >/dev/null 2>&1; then
    echo "  ✗ BLIND: $was — der Smoke blieb grün, obwohl der Fehler drin war"
    rot=$((rot + 1))
  else
    echo "  ✓ schlägt an: $was"
    gruen=$((gruen + 1))
  fi
  zurueck "$datei"
  AKTUELL=""
}

# ⚠ UND EINE SABOTAGE, DIE MEHRERE DATEIEN BRAUCHT, MUSS AUCH MEHRERE
# ZURUECKBAUEN. `probe_befehl` sichert genau EINE; wer damit fuenf Seiten
# anfasst, laesst vier veraendert stehen — und der naechste Fall misst dann eine
# Ausgangslage, die niemandem gehoert. (Der erste Anlauf dieser Sitzung wollte
# das mit einem `git checkout --` daneben loesen: das haette bei jedem Lauf
# ungesicherte Arbeit weggeworfen.)
probe_mehr() {                  # probe_mehr <Beschreibung> "<Datei ...>" <Befehl>
  local was="$1" dateien="$2" befehl="$3" d
  nur_pruefer $dateien || { marktplatz=$((marktplatz + 1)); return; }
  faellt_aus "$was" && return
  for d in $dateien; do sichern "$d"; done
  ALLE_AKTUELL="$dateien"
  eval "$befehl"
  if timeout "$FRIST" node tests/alle.mjs >/dev/null 2>&1; then
    echo "  ✗ BLIND: $was — der Smoke blieb grün, obwohl der Fehler drin war"
    rot=$((rot + 1))
  else
    echo "  ✓ schlägt an: $was"
    gruen=$((gruen + 1))
  fi
  for d in $dateien; do zurueck "$d"; done
  ALLE_AKTUELL=""
}

# ⚠ EIN TOTER ANKER IST KEIN BLINDER WAECHTER, und `probe` konnte die beiden
# nicht auseinanderhalten: aendert der sed-Ausdruck NICHTS, bleibt der Smoke
# selbstverstaendlich gruen — gemeldet wurde trotzdem „BLIND". Gemessen am
# 2026-09-14: von 38 gemeldeten blinden Faellen waren mehrere in Wahrheit tote
# Anker aus frueheren Umbauten (die Beschreibung des Pruefers wurde am
# 2026-09-10 neu geschrieben, der Anker zeigte weiter auf den alten Satz).
#
# Das ist die teurere Verwechslung: ein blinder Waechter heisst „bau einen
# Waechter", ein toter Anker heisst „zieh den Fall nach". Wer das eine fuer das
# andere haelt, sucht am falschen Ende — oder, schlimmer, glaubt an eine
# Deckung, die es nie gab.
# ⚠ NUR_FALL LAESST FAELLE AUS — und sagt es in der Schlusszeile.
# `NUR_FALL="WARTUNG:" bash tests/gegenprobe.sh` faehrt nur die Faelle, deren
# Beschreibung den Text enthaelt. Ein voller Lauf dauert hier eine gute Stunde
# (jeder Fall ist ein ganzer Smoke-Lauf); wer einen neuen Waechter baut, will
# ihn in Minuten sehen, nicht morgen.
#
# Die Zahl der ausgelassenen Faelle steht deshalb am Ende. Ein gefilterter Lauf,
# der aussieht wie ein voller, waere genau die Sorte Auskunft ohne Deckung,
# gegen die diese Datei gebaut ist — und der Ausgangszustand oben wird trotzdem
# geprueft, sonst misst auch ein gefilterter Lauf Unsinn.
NUR_FALL="${NUR_FALL-}"
uebersprungen=0
faellt_aus() {                  # faellt_aus <Beschreibung>
  [ -n "$NUR_FALL" ] || return 1
  case "$1" in (*"$NUR_FALL"*) return 1 ;; esac
  uebersprungen=$((uebersprungen + 1))
  return 0
}

probe() {                       # probe <Beschreibung> <Datei> <sed-Ausdruck>
  local was="$1" datei="$2" ausdruck="$3"
  nur_pruefer "$datei" || { marktplatz=$((marktplatz + 1)); return; }
  faellt_aus "$was" && return
  sichern "$datei"
  AKTUELL="$datei"
  local vorher; vorher=$(cat "$datei")
  sed -i "$ausdruck" "$datei"
  if [ "$vorher" = "$(cat "$datei")" ]; then
    echo "  ⚠ ANKER TOT: $was — der Ausdruck aendert nichts, der Fall misst NICHTS"
    tot=$((tot + 1))
    zurueck "$datei"; AKTUELL=""; return
  fi
  if timeout "$FRIST" node tests/alle.mjs >/dev/null 2>&1; then
    echo "  ✗ BLIND: $was — der Smoke blieb grün, obwohl der Fehler drin war"
    rot=$((rot + 1))
  else
    echo "  ✓ schlägt an: $was"
    gruen=$((gruen + 1))
  fi
  zurueck "$datei"
  AKTUELL=""
}

# ⚠ EINE PROBE DARF NIE AN EINER VERSIONSNUMMER HAENGEN.
# Am 2026-08-09 sind drei Proben DREIMAL blind geworden, immer aus demselben
# Grund: sie zielten auf `?v=2`, dann `?v=3`, waehrend die Dateien schon bei
# `?v=4` standen. Ein sed, das nichts findet, aendert nichts — und der Smoke
# bleibt gruen, was wie eine bestandene Pruefung aussieht.
# Darum: auf STABILE Anker zielen (`</body>`, `</head>`, einen Feldnamen) oder
# die Zahl mit `[0-9]*` offen lassen. Nie auf die Version selbst.
echo "── Gegenprobe: jeder Fehler muss den Smoke umwerfen ──"

# Der Ausgangszustand muss grün sein, sonst misst die Gegenprobe Unsinn.
if ! timeout "$FRIST" node tests/alle.mjs >/dev/null 2>&1; then
  echo "  ✗ ABBRUCH: der Smoke ist schon vor der Gegenprobe rot."
  exit 1
fi
echo "  ✓ Ausgangszustand grün"

probe "Preis auf der Seite (Stufe 1 verletzt)" \
      index.html 's|<h1>Apps finden|<h1>Ab 5 € — Apps finden|'

probe "Platzreserve der Lampen entfernt (Siegel-Sprung)" \
      assets/style.css 's|min-height: 34px; align-items: center;|align-items: center;|'

# Die alte Probe („Reserve entfernt") ist am 2026-08-09 hinfällig geworden: die
# Reserve war HIER der Sprung und ist bewusst weg. Eine Probe, die einen Fehler
# einbaut, den es nicht mehr geben kann, bleibt grün und sieht aus wie ein
# blinder Wächter — sie war einer. An ihre Stelle treten die zwei Fehler, die
# in der neuen Bauweise möglich sind.
probe "Platzreserve wieder eingebaut (wäre jetzt der Sprung)" \
      assets/style.css 's|^\.listings {|.listings:not(.gefuellt) { min-height: 70vh; }\n.listings {|'

# Frueher zielte diese Probe auf `PT_LISTINGS = []` — seit die 14 Apps drin
# stehen, traf sie nichts mehr und sah dabei wie eine bestandene Pruefung aus.
# Dieselbe Falle wie am Vormittag: eine Probe veraltet mit dem Bau.
probe "statische Liste nicht mit listings.js nachgezogen" \
      assets/config/listings.js 's|"label": "Kimseek"|"label": "Kimseek GEAENDERT"|'

probe "Liste wird beim Laden doch wieder gezeichnet" \
      assets/app.js 's|  function start() {|  function start() {\n    zeichne(null);|'

probe "SBKIM-Modul wieder blockierend in die Seite gehängt" \
      index.html 's|</body>|<script src="sbkim/04_match.js"></script></body>|'

probe "SBKIM-Modul in den Installations-Vorrat gelegt" \
      sw.js 's|  "manifest.json",|  "sbkim/04_match.js",\n  "manifest.json",|'

probe "ribbonText entfernt (Wappen-Band bliebe leer)" \
      assets/sbkim-init.js 's|ribbonText: "PWA TOOLPOINT"|ribbonText: ""|'

probe "Beschreibung im Kopf entfernt (Auffindbarkeit)" \
      index.html 's|<meta name="description"|<meta name="beschreibung-weg"|'

probe "Sitemap zeigt auf eine Seite, die es nicht gibt" \
      sitemap.xml 's|<loc>https://pwa-toolpoint.de/impressum.html</loc>|<loc>https://pwa-toolpoint.de/gibtsnicht.html</loc>|'

probe "Knotenkarte in die Sitemap aufgenommen (versteckt ist sie dann nicht mehr)" \
      sitemap.xml 's|</urlset>|<url><loc>https://pwa-toolpoint.de/knotenkarte.html</loc></url></urlset>|'

probe "Feld ohne erreichbare Beschriftung" \
      index.html 's|<label class="field" for="fApp">|<label class="field">|'

probe "Reload beim ersten Besuch wieder eingebaut" \
      index.html "s|navigator.serviceWorker.register('sw.js').catch(function () {});|navigator.serviceWorker.addEventListener('controllerchange', function () { location.reload(); });|"

probe "byte-1:1-Modul von Hand geändert (Drift)" \
      sbkim/04_match.js '1s|^|// hier hat jemand die Kopie angefasst\n|'

probe "Cache-Version nicht mitgezogen" \
      sw.js 's|pwa-toolpoint-v[0-9]*|pwa-toolpoint-v99|'

# Der Anker ist seit dem Umbau vom 2026-08-12 das Fakten-Band, nicht mehr die
# einzelne Zeile. Eine Probe veraltet mit dem Bau — genau das ist hier passiert.
probe "Messwerte hinter den Klick geschoben (sollen offen bleiben)" \
      assets/karte.js 's|<div class="fakten">. + messwerteHtml(e, { ohneDatum: true })|<div class="fakten">.|'

probe "Themen-Knopf wieder ein <span> statt <button>" \
      index.html 's|<button class="thema-knopf" id="themaKnopf" type="button">|<span class="thema-knopf" id="themaKnopf">|'

probe "Aktualisieren laedt ohne geaenderte Adresse (Cache bliebe stehen)" \
      assets/thema.js 's|location.replace(location.pathname + "?frisch=" + Date.now());|location.reload();|'

probe "app.js baut die Karte wieder selbst (zwei Fassungen)" \
      assets/app.js 's|window.PTKarte.karteHtml(e)|"<div>eigene Fassung</div>"|'

probe "fremdes Skript eingebunden (echte Fremd-Abhaengigkeit)" \
      index.html 's|</body>|<script src="https://cdn.example.org/x.js"></script></body>|'

probe "Zaehlpixel eingebaut" \
      index.html 's|</head>|<script src="https://www.google-analytics.com/analytics.js"></script></head>|'

probe "Langdruck durch einen normalen Klick ersetzt" \
      assets/app.js 's|marke.addEventListener("pointerdown", function (ev) {|marke.addEventListener("klickfalsch", function (ev) {|'

probe "fester Betrag in der Kaffeekasse (waere ein Preis)" \
      assets/config/kaffeekasse.js 's|paypal.me/familyprojekt|paypal.me/familyprojekt/1|'

probe "Bot-Falle anders benannt als beim Empfaenger" \
      index.html 's|name="fp_hp_url"|name="webseite"|'

probe "Kaffeekasse auch an fremden Eintraegen" \
      assets/karte.js 's|if (k.nurEigene \&\& !e.own) return "";||'

probe "Einreich-Endpunkt vom Importeur geleert (der Fehler von heute)" \
      assets/config/listings.js 's|window.PT_SUBMIT_ENDPOINT = "https://.*"|window.PT_SUBMIT_ENDPOINT = ""|'

probe "eigene Messung im naechtlichen Lauf (zweite Wahrheit)" \
      .github/workflows/messwerte-taeglich.yml 's|      - name: Messwerte holen|      - name: Lighthouse selbst laufen lassen|'

probe "Lauf committet ohne zu pruefen" \
      .github/workflows/messwerte-taeglich.yml 's|run: node tests/smoke_pruefer.mjs|run: echo uebersprungen|'

probe "Quelle von der Zahl entfernt" \
      assets/karte.js 's|(m.quelle ? " · " + esc(quellenName(m.quelle)) : "")|""|'

probe "SVG als Bild wieder erlaubt" \
      assets/app.js 's|!/\\.svg|!/\\.KEINSVG|'

probe "Pflichtfeld Kontakt entfernt" \
      index.html 's|<input id="ebMail" type="email" required|<input id="ebMail" type="email"|'

probe "Eintrag geht bei Fehlschlag verloren" \
      assets/app.js 's|Kopier dir das hier und schick es mir:|Fehler.|g'

probe "Geraete-Knopf wieder eingebaut (der Widerspruch)" \
      index.html 's|<div class="bildsteuer">|<div class="bildsteuer"><button type="button" id="ebBildWaehlen">Bild vom Gerät wählen</button>|'

probe "Bildfeld verschweigt wieder, dass nur ein Link geht" \
      index.html 's|hochladen kannst du hier nichts|oder wähl eins vom Gerät|'

probe "der alte Text „Noch keine Einträge\" wieder da (steht unter 14 Eintraegen)" \
      index.html 's|Kein Eintrag passt zu dieser Suche|Noch keine Einträge, der Marktplatz ist gerade erst entstanden|'

probe "Leer-Kasten wieder sichtbar beim Laden" \
      index.html 's|id="leer" hidden|id="leer"|'

probe "der Fund der Woche ist leer (wuerde erst per Skript kommen)" \
      index.html 's|<div class="fund-bild">|<div class="fund-weg">|'

probe "die Wochen-Wahl wieder gewuerfelt (jeder Lauf ein Commit)" \
      assets/karte.js 's|return wochenNummer(datum) % anzahl;|return Math.floor(Math.random() * anzahl);|'

probe "der Knopf kann denselben Eintrag nochmal ziehen" \
      assets/app.js 's|while (n === jetzt);|while (false);|'

probe "Fund ohne Bild-Pflicht (Schaufenster ohne Bild)" \
      assets/karte.js 's|return e \&\& e.img \&\& !istGesperrt(e);|return !!e;|'

probe "nur noch .btn bewegt sich (Klaus wollte alle)" \
      assets/app.js 's|var VERFOLGT = ".*";|var VERFOLGT = ".btn";|'

probe "Bewegung nicht mehr abschaltbar" \
      assets/style.css 's|\.btn, \.thema-knopf, \.relais-pille, nav\.top a, \.fund-bild { transform: none; }||'

probe "Bild der Discovery ohne feste Maße" \
      assets/style.css 's|width: 112px; height: 112px; flex-shrink: 0;|flex-shrink: 0;|'

# ---- Studio -----------------------------------------------------------------
probe "Studio fest in die Seite gehaengt (jeder Besucher laedt es mit)" \
      index.html 's|</body>|<script src="assets/studio.js"></script></body>|'

probe "das Ziel reist NICHT mit (Commit ginge ins falsche Repo)" \
      assets/studio.js 's|koerper.ziel = ZIEL;||'

# ⚠ Diese Probe war am 2026-08-10 einen Lauf lang BLIND: sie zielte auf
# `QUEUE = offen;`, und seit die Meldungen abgetrennt werden, heisst die Zeile
# `QUEUE = offen.filter(…)`. Ein sed, das nichts findet, aendert nichts — und
# der gruene Smoke sah aus wie eine bestandene Pruefung. Dieselbe Falle wie bei
# den Versionsnummern, nur an einem anderen Anker.
probe "Warteschlange wieder hart nach Herkunft gefiltert (Wahl weg)" \
      assets/studio.js 's|QUEUE = offen.filter(function (it) { return it.zweck !== "meldung"; })|QUEUE = offen.filter(function (it) { return it.ziel === ZIEL; })|'

probe "Herkunft nicht mehr an der Karte sichtbar" \
      assets/studio.js 's|class="studio-her|class="weg-damit|g'

probe "eine App kann nicht mehr in BEIDEN Maerkten bleiben" \
      assets/studio.js 's|it._beide ? "geprueft" : "freigegeben"|"freigegeben"|'

probe "aus einer Vorlage gebaut statt aus der echten Datei (Endpunkt weg)" \
      assets/studio.js 's|if (k == null \|\| f == null) return null;|k = k \|\| ""; f = f \|\| "";|'

probe "Studio-Syntax kaputt (deutsches Anfuehrungszeichen)" \
      assets/studio.js '1s|^|var x = "erst „Veröffentlichen" macht;\n|'

probe "Messwerte gehen beim Veroeffentlichen verloren" \
      assets/studio.js 's|if (e.messung \&\& typeof e.messung === "object") o.messung = e.messung;||'

probe "SVG als Bild wieder erlaubt (Studio)" \
      assets/studio.js 's|!/\\.svg|!/\\.KEINSVG|'

probe "Einsendung abgehakt, BEVOR der Commit durch ist" \
      assets/studio.js 's|    it._uebernommen = true;|    ruf("setstatus", { id: it.id, status: "freigegeben" });\n    it._uebernommen = true;|'

probe "fremder Speicher-Praefix (Kollision auf geteilter Adresse)" \
      assets/studio.js 's|ptstudio_srv_key|fpstudio_srv_key|'

probe "\"nichts da\" behauptet, bevor gefragt wurde" \
      assets/studio.js 's|var gefragt = false;|var gefragt = true;|'

probe "Nachzieh-Lauf committet alles (Endlos-Schleife)" \
      .github/workflows/statische-liste.yml 's|git add index.html|git add -A|'

probe "Nachzieh-Lauf prueft nicht mehr" \
      .github/workflows/statische-liste.yml 's|run: node tests/smoke_pruefer.mjs|run: echo uebersprungen|'

# ---- Suche wie in FP: Mikrofon, Ladebalken, Naehe-Zahl, Siegel --------------
probe "Mikrofon aus dem Suchfeld entfernt" \
      index.html 's|id="sucheMic"|id="weg"|'

probe "Mikrofon verschwindet statt abgeschaltet zu werden (Sprung)" \
      assets/app.js 's|      knopf.disabled = true;|      knopf.remove();|'

probe "Mikrofon sendet von selbst ab (Missverstaendnis nicht korrigierbar)" \
      assets/app.js 's|        feld.focus();|        feld.form.requestSubmit();|'

probe "Ladebalken wieder nur Text" \
      assets/app.js 's|ptbar-fill|nur-text|g'

probe "Prozent nicht mehr geklemmt (Balken kann ueberlaufen)" \
      assets/app.js 's|Math.max(0, Math.min(100, Math.round(prozent)))|Math.round(prozent)|'

probe "Beschriftung als HTML statt textContent (Inject-Weg)" \
      assets/app.js 's|lbl.textContent = beschriftung;|lbl.innerHTML = beschriftung;|'

probe "Bedeutungs-Suche wieder mit Schwelle (Eintraege verschwinden lautlos)" \
      assets/app.js 's|await window.SbkimEmbedding.init();|await window.SbkimMatch.queryLocal(frage, 20);|'

probe "die Naehe-Zahl landet nicht mehr an der Karte" \
      assets/app.js 's|e._naehe = best;||'

probe "alte Naehe-Zahl bleibt nach einer Wortsuche stehen" \
      assets/app.js 's|listings.forEach(function (e) { delete e._naehe; });||'

probe "die Karte zeigt die Naehe nicht mehr" \
      assets/karte.js 's|          naeheHtml(e) +||'

probe "die Zahl wird als Uebereinstimmung ausgegeben (sie ist eine Rangfolge)" \
      assets/karte.js 's|">Nähe <b>|">Übereinstimmung <b>|'

probe "Siegel ohne Groesse (war 0 Pixel breit)" \
      assets/style.css 's|width: 28px; height: 28px; flex-shrink: 0; cursor: pointer;|cursor: pointer;|'

probe "Siegel-SVG fuellt seinen Platz nicht mehr" \
      assets/style.css 's|#sbkim-siegel-badge svg { width: 100%; height: 100%; display: block; }||'


# ---- Gleiche Art, eine Karte (Klaus 2026-09-30) -----------------------------
probe "GRUPPE: ohne Wirt wird wieder nach dem Satz gruppiert (2x Metadaten = zwei Karten)" \
      assets/pruefer-ui.js 's#(wirt .. "");#(wirt || x.satz);#'

probe "GRUPPE: der Satz jeder Stelle verschwindet aus der Sammelkarte" \
      assets/pruefer-ui.js 's#if (vieleSaetze) stelle#if (false) stelle#'

probe "GRUPPE: versteckte Wirte fallen auf eine Karte (Wirt nicht mehr erkannt)" \
      assets/pruefer-ui.js 's#lädt von (\[A-Za-z0-9._:-\]+) \\(#NIE (x)#'


# ---- Die Marke ---------------------------------------------------------------
probe "Kopf-Marke wieder ein leeres Farbquadrat" \
      assets/style.css 's|  background: url("../icons/marke-96.png") center / cover no-repeat;||'

probe "Kopf-Marke ohne feste Masse (Sprung beim Nachladen)" \
      assets/style.css 's|  width: 30px; height: 30px; border-radius: 9px; flex-shrink: 0;|  border-radius: 9px;|'

probe "maskable zeigt wieder auf das randfuellende Bild (Wellen abgeschnitten)" \
      manifest.json 's|icons/maskable-512.png|icons/icon-512.png|'


# Der Abschnitt wird WIRKLICH wieder nach oben geschoben — ein sed haette hier
# nur den Anker des Waechters kaputtgemacht, und das haette rot ausgesehen,
# ohne die Reihenfolge zu pruefen.
probe_befehl "Discovery wieder zwischen Suche und Treffer (schiebt die Ergebnisse weg)" \
      index.html 'python3 - <<"EOF"
s = open("index.html", encoding="utf-8").read()
a = s.index("  <section class=\"wrap\" id=\"fund\">")
b = s.index("</section>", a) + len("</section>\n")
block = s[a:b]
s = s[:a] + s[b:]
anker = "  <section class=\"wrap\">\n    <h2>Einträge</h2>"
s = s.replace(anker, block + "\n" + anker, 1)
open("index.html", "w", encoding="utf-8").write(s)
EOF'


probe "CLAUDE.md verweist nicht mehr auf den Uebergabe-Brief (er wird nie gelesen)" \
      CLAUDE.md 's|BRIEF_naechste-sitzung.md|BRIEF_gibtsnicht.md|g'

# ⚠ Auf den Wortlaut zielen, den der Smoke wirklich sucht — NICHT auf die ganze
# Überschrift. Sie hieß einmal „## Fallen, …" und heißt inzwischen „## Die vier
# Fallen, …"; die alte Fassung dieser Probe fand deshalb nichts mehr, änderte
# nichts und sah wie eine bestandene Prüfung aus (blind aufgefallen 2026-08-15).
probe "der Brief verschweigt die Fallen" \
      docs/sessions/BRIEF_naechste-sitzung.md 's|Fallen, die diese Sitzung Zeit gekostet|Sonstiges|'

probe "der Brief verschweigt, was Klaus selbst tun muss" \
      docs/sessions/BRIEF_naechste-sitzung.md 's|## Was Klaus noch selbst tun muss|## Anhang|'


probe "Knoepfe quetschen den Text wieder (das Rutschen von heute)" \
      assets/style.css 's|.studio-tun { flex: 1 0 100%;|.studio-tun { flex-shrink: 0;|'


# ---- Melden ----------------------------------------------------------------
# Jeder dieser Fehler nimmt dem Markt die Sorgfaltspflicht bei fremden Apps.
# Und jeder einzelne saehe im Browser aus wie „geht schon": der Knopf ist da,
# er oeffnet sich, nur ankommen wuerde nichts.
probe "Melde-Knopf ganz aus der Karte entfernt" \
      assets/karte.js 's|          meldenHtml(e) +||'

probe "Melden verliert die Kennung (Empfaenger antwortet 400)" \
      assets/karte.js 's|data-melden-id=|data-nix-id=|'

probe "Melden wird ohne Skript zum toten Knopf (leerer href)" \
      assets/karte.js 's|class="btn slim ghost melden" href="#auftrag"|class="btn slim ghost melden" href="#"|'

probe "Zweck beim Senden umbenannt (Empfaenger nimmt es als Eintrag)" \
      assets/app.js 's|zweck: "meldung"|zweck: "hinweis"|'

probe "Meldungs-Feld umbenannt (Ablehnung sieht aus wie Netzfehler)" \
      assets/app.js 's|          grund_text: grundText,|          grundtext: grundText,|'

probe "Bot-Falle im Melder entfernt" \
      assets/app.js 's|id="meldeHp"|id="meldeOffen"|'

probe "Melder verliert den weichen Rueckfall (die Meldung geht verloren)" \
      assets/app.js 's|Der Meldeweg ist noch nicht eingerichtet|Fehler|'

probe "Melder ist kein natives dialog mehr (keine Fokusfalle, keine Escape-Taste)" \
      assets/app.js 's|d.showModal();|d.setAttribute("open", "open");|'

probe "Melde-Zugang wird beim Start nicht mehr verdrahtet" \
      assets/app.js 's|^    meldeZugang();||'

probe "Zuhoerer haengt an einer Karte statt am Behaelter (nach der Suche tot)" \
      assets/app.js 's|var liste = \$("liste");|var liste = document.querySelector(".listing");|'

probe "Melde-Dialog verliert sein Aussehen" \
      assets/style.css 's|^\.melde-dlg {|.melde-dlg-alt {|'

probe "statische Liste traegt den Melde-Knopf nicht mehr" \
      index.html 's|data-melden="1"|data-melden-weg="1"|g'

probe "Meldung geht bei Fehlschlag verloren" \
      assets/app.js 's|Kopier dir das hier:|Fehler.|g'


# ---- Der Weg raus fuer den Anbieter ----------------------------------------
# Ohne diese vier ist ein Eintrag zu einer fremden App nicht mehr vertretbar:
# er entsteht ohne Nachfrage und muesste sich mit einem Klick wieder aufloesen.
probe "der eigene Meldegrund fehlt ganz — der Besitzer muss sich unter Sonstiges melden" \
      assets/app.js '/{ wert: "eigen"/d'

# Nicht geloescht, sondern nach UNTEN geschoben: so bleibt die Existenz-Pruefung
# gruen und nur der Reihenfolge-Waechter faellt. Genau das trennt ihn von einer
# blanken indexOf-Kette, die bei −1 still gruen bliebe.
probe_befehl "der eigene Meldegrund rutscht ans Listenende" \
      assets/app.js \
      'sed -i -e "/{ wert: \"eigen\"/d" -e "s|    { wert: \"sonstig\",  text: \"Etwas anderes.\" }|    { wert: \"sonstig\",  text: \"Etwas anderes.\" },\n    { wert: \"eigen\",    text: \"Das ist meine App.\" }|" assets/app.js'

probe "der Haken liegt vorausgewaehlt auf dem Eigentuemer-Grund — ein Klick-Ausrutscher waere ein Loeschauftrag" \
      assets/app.js 's|MELDE_STANDARD = "kaputt"|MELDE_STANDARD = "eigen"|'

probe "der Radio-Knopf hoert nicht mehr auf den Standard" \
      assets/app.js 's|g.wert === MELDE_STANDARD ? " checked"|"" ? " checked"|'

probe "die Zusage ohne Rueckfrage und ohne Frist faellt weg" \
      assets/app.js 's|<b>ohne Rückfrage und ohne Frist</b>|so bald wie möglich|'

probe "die Zusage verliert ihr Aussehen und geht als Kleingedrucktes unter" \
      assets/style.css 's|^\.melde-zusage {|.melde-zusage-alt {|'


# ---- Bild: Pflicht bei eigenen, freiwillig bei fremden ----------------------
# Die Lockerung kann in BEIDE Richtungen kippen, und beide Richtungen sind
# still: zu streng haelt jede fremde App draussen, zu lasch laesst ein eigenes
# Bild weg oder ein untaugliches herein.
probe "die Bild-Pflicht gilt wieder fuer alle (kein Fremd-Eintrag mehr moeglich)" \
      assets/studio.js 's|    if (e.own) {|    if (true) {|'

probe "auch eigene Eintraege duerfen ohne Bild bleiben" \
      assets/studio.js 's|    if (e.own) {|    if (false) {|'

probe "ein fremdes Bild wird gar nicht mehr geprueft (SVG und http gingen durch)" \
      assets/studio.js 's|} else if (e.img \&\& !sicheresBild(e.img)) {|} else if (false) {|'

probe "die harte Bild-Sperre in der Uebernahme kehrt zurueck" \
      assets/studio.js 's|    var bild = sicheresBild(it.img);|    if (!sicheresBild(it.img)) { meldung("Ohne brauchbares Bild wird das nicht übernommen.", false); return; }\n    var bild = sicheresBild(it.img);|'

probe "ein untaugliches Bild faellt still weg (niemand erfaehrt warum)" \
      assets/studio.js 's|Übernommen ohne Bild — der Bild-Link taugte nicht (https, kein SVG). Jetzt noch auf Veröffentlichen drücken.|Übernommen — jetzt noch auf Veröffentlichen drücken.|'

probe "die Karte zeichnet ohne Bild gar nichts mehr (Layout-Sprung)" \
      assets/karte.js 's|: '"'"'<span class="img"></span>'"'"')|: "")|'

probe "ein Eintrag ohne Bild wird doch Fund der Woche (leeres Schaufenster)" \
      assets/karte.js 's|return e \&\& e.img \&\& !istGesperrt(e);|return e \&\& !istGesperrt(e);|'

probe "der Kopf von listings.js sagt weiter Bild-PFLICHT (Datei luegt ueber sich)" \
      assets/config/listings.js 's|PFLICHT für eigene Einträge|PFLICHT für alle Einträge|'


# ---- Woher die Zahlen kommen (C1) ------------------------------------------
# Der Markt steht auf einem Versprechen: die Zahlen sind gemessen, nicht
# behauptet. Jeder Fehler hier nimmt dem Versprechen seinen Beleg — und alle
# sind still: die Zahl steht weiter da, nur nachpruefen kann sie niemand mehr.
probe "der Knopf wird gar nicht mehr eingesetzt" \
      assets/karte.js 's|          bewertungHtml(e) +||'

probe "der Knopf wird ohne Skript zum toten Knopf (leerer href)" \
      assets/karte.js 's|class="btn slim ghost bewertung" href="#pruefung"|class="btn slim ghost bewertung" href="#"|'

# Nicht geloescht, sondern ins Summary verschoben: so bleibt die Existenz-
# Pruefung gruen und nur der Reihenfolge-Waechter faellt.
probe_befehl "der Knopf rutscht ins Summary (klappt beim Antippen die Karte um)" \
      assets/karte.js \
      'sed -i -e "/^          bewertungHtml(e) +$/d" -e "s|          wacheHtml(e) +|          wacheHtml(e) +\\n          bewertungHtml(e) +|" assets/karte.js'

probe "statische Liste traegt den Knopf nicht mehr" \
      index.html 's|data-bewert="1"|data-bewert-weg="1"|g'

probe "app.js fuehrt doch eine zweite Erklaer-Liste (laeuft von karte.js weg)" \
      assets/app.js 's|var bewertOeffner = null;|var MESS_ERKLAERT = { leistung: "irgendwas" };\nvar bewertOeffner = null;|'

probe "eine der vier Zahlen verliert ihre Erklaerung" \
      assets/karte.js 's|    bedienbarkeit: "Ob die Seite auch mit Tastatur|    bedienbarkeitWEG: "Ob die Seite auch mit Tastatur|'

probe "der Link zum Selber-Nachmessen faellt weg (Beleg futsch)" \
      assets/app.js 's|https://pagespeed.web.dev/analysis?url=|https://example.org/?|'

probe "die Adresse wird roh angehaengt statt verpackt" \
      assets/app.js 's|encodeURIComponent(u)|u|'

# Nur INNERHALB von pagespeedLink sabotieren — das Muster steht dreimal in der
# Datei, und genau deshalb war der Waechter dazu erst zu schwach.
probe "auch http-Adressen bekommen einen Mess-Link" \
      assets/app.js '/function pagespeedLink/,/^  }/ s|\^https:|^http:|'

probe "der Mess-Link vererbt eine Empfehlung (kein nofollow)" \
      assets/app.js 's|rel="nofollow noopener noreferrer"|rel="noopener noreferrer"|'

probe "die Grenze der Aussage faellt weg (100 laese sich wie ein Siegel)" \
      assets/app.js 's|nichts über die Vertrauenswürdigkeit|alles über die Güte|'

# sed arbeitet ZEILENWEISE — ein Muster mit \n trifft nie. Beide Dialoge tragen
# dieselbe Zeile, also wird ueber den Funktions-Bereich adressiert.
probe "das Fenster ist kein natives dialog mehr (keine Fokusfalle, kein Escape)" \
      assets/app.js '/function bewertOeffnen/,/^  function /  s|d.showModal();|d.setAttribute("open","open");|'

probe "der Zuhoerer des Fensters haengt an einer Karte statt am Behaelter" \
      assets/app.js 's|closest("\[data-bewert\]")|closest(".listing")|'

probe "das Fenster wird beim Start nicht mehr verdrahtet" \
      assets/app.js 's|^    bewertZugang();||'

probe "das Fenster verliert sein Aussehen" \
      assets/style.css 's|^\.bewert-dlg {|.bewert-dlg-alt {|'


# ---- Laeuft der Code ueberhaupt? -------------------------------------------
# Der teuerste Fehler ueberhaupt: ein deutsches Anfuehrungszeichen INNERHALB
# einer doppelt gesetzten Zeichenkette. Es schliesst die Zeichenkette, die
# Datei ist tot, die Seite bliebe leer — und jeder Textmuster-Waechter meldet
# trotzdem gruen, denn die Woerter stehen ja da.
probe "kaputte Zeichenkette in app.js (Seite bliebe leer)" \
      assets/app.js 's|var bewertOeffner = null;|var x = "hier „bricht" es";\nvar bewertOeffner = null;|'

probe "kaputte Klammer in karte.js" \
      assets/karte.js 's|  function karteHtml(e) {|  function karteHtml(e) { (|'


# ---- Gepruefte Eigenschaften statt Sterne ----------------------------------
# Klaus hatte nach Sternen gefragt; geworden sind es Tatsachen. Jeder Fehler
# hier macht aus einer Tatsache wieder eine Behauptung — und keiner faellt auf,
# denn das Haekchen steht weiter da.
probe "das Pruef-Werkzeug verliert seinen Abbruch-Schutz (Konfiguration futsch)" \
      tools/eigenschaften-pruefen.mjs 's|nicht gefunden — Abbruch, statt die Konfiguration zu verlieren.|Hinweis.|'

# Nicht den Kommentar entfernen, sondern die TAT: statt weiterzugehen wird der
# Befund geleert — genau das nimmt einer erreichbar-schwachen App ihre Haekchen.
probe "ein Ausfall nimmt der App ihre Haekchen weg" \
      tools/eigenschaften-pruefen.mjs 's|if (!neu) { unerreichbar++;|if (!neu) { e.eigenschaften = null; geaendert++; unerreichbar++;|'

probe "das Werkzeug holt auch FREMDE Skripte (genau das, was wir bemaengeln)" \
      tools/eigenschaften-pruefen.mjs 's|    if (ziel.origin !== new URL(basis).origin) continue;   // fremde Herkunft: nicht holen||'

probe "kein Deckel mehr auf der Zahl geholter Skripte" \
      tools/eigenschaften-pruefen.mjs 's|    if (aus.length >= MAX_SKRIPTE) break;||'

probe "das Werkzeug fasst ploetzlich auch die Messwerte an" \
      tools/eigenschaften-pruefen.mjs 's|    e.eigenschaften = neu;|    e.eigenschaften = neu; e.messung = neu;|'

probe "die Rechnung wird ans Netz gebunden (hier nicht mehr pruefbar)" \
      tools/eigenschaften-pruefen.mjs 's|^export function pruefe(|function pruefe(|'

probe "ein Service Worker ohne Fetch-Zuhoerer bekommt trotzdem das Offline-Haekchen" \
      tools/eigenschaften-pruefen.mjs 's|export function swHatFetch(swQuelle) {|export function swHatFetch(swQuelle) { return true;|'

probe "ein Manifest ohne App-Anzeigeart gilt wieder als installierbar" \
      tools/eigenschaften-pruefen.mjs "s|const APP_ANZEIGE = \['standalone', 'fullscreen', 'minimal-ui'\];|const APP_ANZEIGE = ['standalone', 'fullscreen', 'minimal-ui', 'browser'];|"

probe "der Zaehldienst-Sucher liest den ganzen Text (Datenschutz-Seite schlaegt an)" \
      tools/eigenschaften-pruefen.mjs 's|const heuhaufen = skriptTeile(html).concat(weitereQuellen).join|const heuhaufen = [String(html)].concat(weitereQuellen).join|'

probe "die Karte zeigt die Eigenschaften nicht mehr" \
      assets/karte.js 's|messdatumHtml(e) + eigenschaftenHtml(e)|messdatumHtml(e)|'

probe "auch unerfuellte Eigenschaften werden angezeigt (oeffentliches Urteil)" \
      assets/karte.js 's|      if (g\[k\] !== true) return;|      if (g[k] === undefined) return;|'

probe "ohne Befund faellt die Karte um statt still zu bleiben" \
      assets/karte.js 's|    if (!g) return "";|    if (!g) { g = {}; }|'

probe "das Fenster verschweigt, was ein Haekchen NICHT beweist" \
      assets/app.js 's|gefunden, nicht ausgeschlossen|sicher keiner|'

probe "das Fenster behauptet doch etwas ueber den Nutzen" \
      assets/app.js 's|sagen nichts über den Nutzen|sagen alles über den Nutzen|'

probe "Sterne an der Karte (die Entscheidung wird zurueckgedreht)" \
      assets/karte.js 's|  function eigenschaftenHtml(e) {|  function sterne(e) { return "★★★★☆"; }\n  function eigenschaftenHtml(e) {|'

probe "die Eigenschaften verlieren ihr Aussehen" \
      assets/style.css 's|^\.eigenschaften {|.eigenschaften-alt {|'


# ---- Festes 2x2-Raster und das Wegkippen ----------------------------------
# Klaus' Befunde: die Container sind zu gross, die Messwerte stehen auf jeder
# Karte anders, und die alte Walze verzerrte durchgehend. Jeder Fehler hier
# bringt eins davon zurueck — und keiner sieht nach Fehler aus.
# ⚠ Diese Probe war am 2026-08-13 BLIND: sie zielte auf die alte Zeile
# `grid-template-columns: 1fr 1fr; gap: 4px; margin: 0;`, die beim Umbau in zwei
# Zeilen zerfallen ist. Ein sed, das nichts findet, aendert nichts — und der
# Smoke bleibt gruen. Dritter Fall derselben Falle; sie steht im Kopf dieser
# Datei. Jetzt auf den Anfang der Regel, der stabil ist.
# ---- Die Beschriftung der Haekchen (Klaus 2026-08-14) ---------------------
# „Die Zeichen sind irrefuehrend … sag immer, was man damit machen kann."
# Diese Proben halten die Worte fest. Ohne sie lief die Umbenennung durch einen
# gruenen Smoke — es gab keinen einzigen Waechter darauf.
probe "die erklaerungsbeduerftigen Zeichen kehren zurueck" \
      assets/karte.js 's|    installierbar: { text: "installierbar" },|    installierbar: { zeichen: "⤓", text: "installierbar" },|'

probe "das Offline-Wort faellt zurueck auf „offline vorbereitet\"" \
      assets/karte.js 's|    offline: { text: "offlinefähig",|    offline: { text: "offline vorbereitet",|'

# ⚠ Erste Fassung war BLIND: sie loeschte eine Zeile, die der Waechter gar
# nicht prueft — „einzelne Funktionen" steht eine Zeile darueber, „nimmt ihrem
# Hersteller die Auskunft" eine darunter, beide ueberlebten. Eine Probe muss die
# Stelle treffen, an der der Waechter HINSIEHT, nicht irgendeine daneben.
probe "die Erklaerung nimmt dem Hersteller wieder die Auskunft ab" \
      assets/app.js 's|      "dieser Markt verlinkt sie, er nimmt ihrem Hersteller die Auskunft " +|      "geprüft und bestätigt. " +|'

# ---- Das Schaufenster-Feld appUrl (Klaus 2026-08-13, Weg 2) ---------------
# Steht vor der App eine Landing-Page, wird die APP gemessen und geprueft, der
# Besucher aber auf die Landing-Page geschickt. Jeder Fehler hier bringt genau
# den Bruch zurueck, wegen dem das Feld gebaut wurde.
# ⚠ TRENNER: das Muster enthaelt `||` — mit `s|…|…|` bricht sed mit
# „unknown option to `s'" ab, aendert nichts, und der Smoke bliebe gruen.
# Beim Einzeltest aufgefallen, bevor die Probe je gelaufen ist.
probe "der Pruefer nimmt wieder das Schaufenster statt der App" \
      tools/eigenschaften-pruefen.mjs "s@const url = String(e.appUrl || e.url || '').trim();@const url = String(e.url || '').trim();@"

probe "der Nachmess-Knopf fuehrt zur Landing-Page (misst andere Zahlen)" \
      assets/app.js 's|    var link = pagespeedLink(gemesseneAdresse);|    var link = pagespeedLink(e.url);|'

probe "das Fenster verschweigt, dass zwei Adressen im Spiel sind" \
      assets/app.js 's|    var eigeneSeite = e.appUrl \&\& e.appUrl !== e.url;|    var eigeneSeite = false;|'

probe "das appUrl-Feld geht beim Kopieren ganz verloren (so kam der Bruch)" \
      assets/config/listings.js '/^    "appUrl": /d'

# ---- Das Studio verschluckt ein Feld (Klaus-Befund 2026-08-15) ------------
# `normEintrag` ist eine Positivliste. Zwei Studio-Laeufe haben `appUrl` und
# saemtliche `eigenschaften` aus listings.js entfernt, weil beide Felder nach
# der Funktion entstanden sind. Es fiel niemandem auf — die Karten sahen nur
# ein bisschen leerer aus.
probe "das Studio wirft die Eigenschaften wieder weg" \
      assets/studio.js 's|    if (e.eigenschaften \&\& typeof e.eigenschaften === "object") o.eigenschaften = e.eigenschaften;||'

probe "das Studio wirft appUrl wieder weg" \
      assets/studio.js 's|    if (e.appUrl) o.appUrl = String(e.appUrl).trim();||'

probe "das Studio wirft sogar die Messung weg" \
      assets/studio.js 's|    if (e.messung \&\& typeof e.messung === "object") o.messung = e.messung;||'

# ---- Das Symbol im Manifest (Klaus' Tablet, 2026-08-14) -------------------
# Der Browser bot „Verknuepfung erstellen" statt „Installieren" — Chrome nimmt
# fuer die Installation nur PNG ab 192 px, und beide Tresore trugen ein SVG.
# Ohne diese Regel schriebe der Pruefer „installierbar" an Apps, die der Browser
# ablehnt.
probe "irgendein Symbol reicht wieder (falsches „installierbar\")" \
      tools/eigenschaften-pruefen.mjs 's|  const symbole = Array.isArray(manifest.icons) \&\& manifest.icons.some(istPngAb192);|  const symbole = Array.isArray(manifest.icons) \&\& manifest.icons.length > 0;|'

probe "auch ein winziges PNG zaehlt wieder" \
      tools/eigenschaften-pruefen.mjs 's|    return Number.isFinite(n) \&\& n >= 192;|    return Number.isFinite(n);|'

# ---- Der blinde Fleck des Eigenschaften-Pruefers (erster echter Lauf, 2026-08-13)
# Einzeldatei-Apps tragen ihr Manifest INLINE als `data:`-Adresse, in einfachen
# Anfuehrungszeichen (innen stehen doppelte). Wer die Klammer nicht auf ihre
# eigene zurueckbezieht, liest eine abgeschnittene Adresse und meldet „kein
# Manifest" — ein Mangel des Pruefers, der wie ein Mangel der App aussieht.
probe_befehl "die Klammer muss nicht mehr zu ihrer eigenen passen (Adresse bricht ab)" \
      tools/eigenschaften-pruefen.mjs \
      'python3 - <<"EOF"
import pathlib
p = pathlib.Path("tools/eigenschaften-pruefen.mjs")
t = p.read_text()
alt = """  const h = /\\bhref\\s*=\\s*([\"\x27])([\\s\\S]*?)\\1/i.exec(m[0]);
  return h ? h[2] : null;"""
neu = """  const h = /\\bhref\\s*=\\s*[\"\x27]([^\"\x27]+)[\"\x27]/i.exec(m[0]);
  return h ? h[1] : null;"""
assert t.count(alt) == 1, "Anker fehlt"
p.write_text(t.replace(alt, neu))
EOF'

probe "Inline-Manifeste werden nicht mehr gelesen" \
      tools/eigenschaften-pruefen.mjs 's|^export function manifestAusDataUri(adr) {|export function manifestAusDataUriX(adr) {|'

probe "die Messwerte fliessen wieder frei um (jede Karte sieht anders aus)" \
      assets/style.css 's|^  display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);$|  display: flex; flex-wrap: wrap;|'

probe "Datum und Haekchen belegen wieder zwei Reihen" \
      assets/karte.js 's|<p class="fakten-fuss">|<p class="fakten-alt">|'

probe "die Fuss-Zeile verliert ihr Aussehen" \
      assets/style.css 's|^\.listing \.fakten-fuss {|.listing .fakten-fuss-alt {|'

probe "der Fund der Woche verliert sein Datum" \
      assets/karte.js 's|    if (m.datum \&\& !ohneDatum) teile.push(messdatumHtml(e));||'

probe "die Beschreibung wird gekuerzt statt geklemmt (Text weg fuer Suchmaschinen)" \
      assets/karte.js 's|.slice(0, 220)|.slice(0, 80)|'

probe "die Klemme faellt weg (Karten werden wieder lang)" \
      assets/style.css 's|-webkit-line-clamp: 2;|-webkit-line-clamp: 99;|'

# ---- Der Umbruch in der grossen Ansicht (Klaus 2026-08-13) ----------------
# „Gute Praxis" stand zweizeilig, aber NUR auf Karten mit dreistelliger
# Auffindbarkeit. Ein blankes `1fr` schrumpft nicht unter seinen Inhalt: die
# Spalte mit „Auffindbarkeit 100" nahm sich 120 der 210 px.
probe "eine Spalte kann sich wieder Platz vom Nachbarn nehmen (Umbruch)" \
      assets/style.css 's|  display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);|  display: grid; grid-template-columns: 1fr 1fr;|'

probe "das Zahlen-Band steht wieder in der schmalen Textspalte" \
      assets/style.css 's|^\.listing \.fakten, \.listing \.mehr { flex: 1 0 100%; }||'

probe "die Kopfzeile bricht nicht mehr um (Band bliebe neben dem Symbol)" \
      assets/style.css 's|^  flex-wrap: wrap;$||'

probe_befehl "das Zahlen-Band wandert im Markup zurueck in .kopf" \
      assets/karte.js \
      'python3 - <<"EOF"
import pathlib
p = pathlib.Path("assets/karte.js")
t = p.read_text()
# die schliessende Klammer von .kopf hinter das Band schieben
raus = "          naeheHtml(e) +\n        \"</span>\" +\n"
rein = "          naeheHtml(e) +\n"
t = t.replace(raus, rein, 1)
marke = "        \x27<span class=\"wort-zu\">Weniger zeigen</span></span>\x27 +\n"
t = t.replace(marke, marke + "        \"</span>\" +\n", 1)
p.write_text(t)
EOF'

# Der Maus-Effekt nach family-projects Mass. Vorher war er ein Drittel so
# stark, und der Kommentar daneben behauptete das Gegenteil.
probe "der Maus-Effekt wird wieder auf ein Drittel geschwaecht" \
      assets/app.js 's|? 5.5 : 9;|? 1.9 : 3.1;|'

probe "beim Verlassen bleibt der Schimmer kleben" \
      assets/app.js 's|\["--mx", "--my", "--rx", "--ry"\].forEach|["--rx", "--ry"].forEach|'

# Das Wegkippen. Diese Proben sichern, dass es eine SCHWELLE bleibt und keine
# Dauer-Verzerrung wird — und dass niemand versehentlich Inhalt unsichtbar macht.
probe "die alte Walze kehrt zurueck (Dauer-Verzerrung)" \
      assets/style.css '1s|^|.listing { animation: walze linear both; animation-timeline: view(); }\n@keyframes walze { from { opacity: .5 } }\n|'

probe "das Scharnier oben wandert in die Mitte (kein fallender Domino mehr)" \
      assets/style.css 's|transform-origin: 50% 100%; }|transform-origin: 50% 50%; }|'

# ---- Der untere Rand (Klaus' zweiter Blick 2026-08-13) ---------------------
# „es muesste theoretisch ja unten zu sehen sein, wie die hochkommen."
probe "der untere Rand kippt gar nicht mehr (nur noch oben, wie vorher)" \
      assets/style.css 's|^\.listing\.kipp-rein { --kipp: -78deg; transform-origin: 50% 0; }|.listing.kipp-rein-alt { --kipp: -78deg; transform-origin: 50% 0; }|'

probe "das Scharnier unten sitzt an der falschen Kante (Karte faellt nach vorn)" \
      assets/style.css 's|--kipp: -78deg; transform-origin: 50% 0; }|--kipp: -78deg; transform-origin: 50% 100%; }|'

probe "der untere Rand wird gar nicht erst geprueft" \
      assets/app.js 's|        k.el.classList.toggle("kipp-rein", kommtRein);||'

probe "eine hohe Karte traegt beide Klassen (Zufall entscheidet)" \
      assets/app.js 's|        var kommtRein = zuWenig \&\& !wandertRaus \&\& unten > bildHoehe;|        var kommtRein = zuWenig \&\& unten > bildHoehe;|'

probe "das Wegkippen ist so kurz wie der Maus-Wackler (kaum zu sehen)" \
      assets/style.css 's|transition: transform .42s cubic-bezier(.2, .7, .3, 1)|transition: transform .18s cubic-bezier(.2, .7, .3, 1)|'

probe "der Kipp-Winkel steckt nicht mehr im Transform der Karte" \
      assets/style.css 's|             rotateX(var(--kipp, 0deg))||'

# Die Rueckkopplung, die am 2026-08-13 das Flackern gemacht hat: ein
# IntersectionObserver misst die Karte SO, WIE SIE GEKIPPT IST. Diese Probe
# holt ihn zurueck — der Waechter muss das sehen.
probe "ein IntersectionObserver misst wieder die gedrehte Karte (flackert)" \
      assets/app.js 's|^    sammeln();|    new IntersectionObserver(function () {}); sammeln();|'

probe "die Lage wird nicht mehr aus Layout-Werten geholt" \
      assets/app.js 's|function obenImDokument(el) {|function lageHolen(el) {|'

probe "der Scroll-Zuhoerer misst bei JEDEM Schritt neu (ruckelt)" \
      assets/app.js 's|      if (window.requestAnimationFrame) window.requestAnimationFrame(pruefen);|      if (window.requestAnimationFrame) pruefen();|'

probe "der Scroll-Zuhoerer bremst das Scrollen (nicht mehr passiv)" \
      assets/app.js 's|    window.addEventListener("scroll", anstossen, { passive: true });|    window.addEventListener("scroll", anstossen);|'

probe "nach einem Groessenwechsel stimmen die Lagen nicht mehr" \
      assets/app.js 's|    window.addEventListener("resize", sammeln, { passive: true });|    window.addEventListener("resize", function () {}, { passive: true });|'

probe "ein aufgeklappter Block verschiebt die Lagen unbemerkt" \
      assets/app.js 's|    liste.addEventListener("toggle", sammeln, true);||'

probe "die Schwelle wandert (kippt zu frueh oder zu spaet)" \
      assets/app.js 's|  var KIPP_SCHWELLE = 0.5;|  var KIPP_SCHWELLE = 1 / 3;|'

probe "auf dem Handy setzt es wieder zu spaet ein (Klaus Befund kehrt zurueck)" \
      assets/app.js 's|  var KIPP_SCHWELLE_KURZ = 2 / 3;|  var KIPP_SCHWELLE_KURZ = 0.5;|'

probe "die kurze Bildhoehe wird gar nicht mehr beachtet" \
      assets/app.js 's|      var schwelle = bildHoehe < KIPP_KURZES_BILD ? KIPP_SCHWELLE_KURZ : KIPP_SCHWELLE;|      var schwelle = KIPP_SCHWELLE;|'

probe "der obere Rand vergisst, dass die Karte hinauswandert" \
      assets/app.js 's|        var wandertRaus = zuWenig \&\& oben < deckel;|        var wandertRaus = zuWenig;|'

# ---- Der verdeckte Kopf (Klaus 2026-08-13, Handy) -------------------------
# Gemessen: der klebende Kopf nimmt auf dem Handy 145 von 640 px. Wer wieder
# gegen das FENSTER rechnet statt gegen das sichtbare Band, laesst den Effekt
# oben hinter dem Kopf ablaufen — er passiert, aber niemand sieht ihn.
probe "gerechnet wird wieder gegen das Fenster statt gegen das sichtbare Band" \
      assets/app.js 's|        var sichtbar = Math.min(unten, bildHoehe) - Math.max(oben, deckel);|        var sichtbar = Math.min(unten, bildHoehe) - Math.max(oben, 0);|'

probe "der Deckel wird gar nicht mehr gemessen (immer 0)" \
      assets/app.js 's|      deckel = deckelOben();|      deckel = 0;|'

probe "auch ein weggescrollter Kopf zaehlt als Deckel" \
      assets/app.js 's|    return r.top <= 1 \&\& r.bottom > 0 ? r.bottom : 0;|    return r.bottom;|'

probe "ein NICHT klebender Kopf zaehlt trotzdem als Deckel" \
      assets/app.js 's|    if (pos !== "sticky" \&\& pos !== "fixed") return 0;||'

probe "eine bildfuellende Karte kippt weg (Bildschirm waere leer)" \
      assets/app.js 's|      var zuWenig = anteil < schwelle \&\& !fuelltAlles;|      var zuWenig = anteil < schwelle;|'

probe "neue Karten nach einer Suche melden sich nicht mehr nach" \
      assets/app.js 's|      new MutationObserver(sammeln).observe(liste, { childList: true });||'

# Zwei Riegel gegen „weniger Bewegung" — beide muessen anschlagen.
# sed arbeitet ZEILENWEISE — ein Muster mit \n trifft nie (eigener Fehler,
# heute zum zweiten Mal). Also ueber den Funktions-Bereich adressieren: die
# Medien-Abfrage passt dann auf nichts, der Ausstieg faellt weg.
probe "der Ausloeser ignoriert die Bewegungs-Einstellung" \
      assets/app.js '/function kippBeimScrollen/,/^  }/ s|prefers-reduced-motion: reduce|gibt-es-nicht|'

probe "der zweite Riegel im CSS faellt weg (Inhalt koennte unsichtbar bleiben)" \
      assets/style.css 's|    --kipp: 0deg; opacity: 1; pointer-events: auto; transition: none;|    --kipp: 0deg;|'

probe "eine weggekippte Karte faengt wieder Klicks" \
      assets/style.css 's|  pointer-events: none;||'

probe "der zweite Riegel gilt nur noch fuer den oberen Rand" \
      assets/style.css '/@media (prefers-reduced-motion/,/^}/ { s|^  \.listing\.kipp-weg,$|  .listing.kipp-weg {|; /^  \.listing\.kipp-rein {$/d; }'

# ---- Und die zwei Waechter, die durch den zweiten Dialog blind WAREN --------
# Vor dem 2026-08-12 pruefte der Melder-Waechter ein blankes `showModal()` gegen
# die ganze Datei, und sein Zuhoerer-Waechter ein blankes addEventListener. Mit
# einem zweiten Dialog waeren beide gruen geblieben, obwohl der MELDER kaputt
# ist. Diese zwei Proben beweisen, dass sie es jetzt nicht mehr sind.
probe "der MELDER verliert showModal, das Bewertungs-Fenster behaelt es" \
      assets/app.js '/function meldeOeffnen/,/^  function /  s|d.showModal();|d.setAttribute("open","open");|'

probe "der Zuhoerer des MELDERS stirbt, der des Fensters lebt weiter" \
      assets/app.js 's|closest("\[data-melden\]")|closest(".gibtsnicht")|'


# ---- Eingetragen, nicht abgestimmt -----------------------------------------
# Ohne diesen Satz sieht ein Eintrag, den niemand abgesprochen hat, aus wie ein
# Partner. Jeder Fehler hier ist still: die Karte bleibt heil, sie behauptet nur
# etwas anderes, als wahr ist.
probe "der Fremd-Hinweis wird gar nicht mehr eingesetzt" \
      assets/karte.js 's|          fremdHinweisHtml(e) +||'

# Nicht geloescht, sondern hinter den Klick geschoben: so bleibt die Existenz-
# Pruefung gruen und nur der Reihenfolge-Waechter faellt.
probe_befehl "der Fremd-Hinweis rutscht hinter den Klick (bis dahin unsichtbar)" \
      assets/karte.js \
      'sed -i -e "/^          fremdHinweisHtml(e) +$/d" -e "/<div class=.mehrteil.>. +/a         fremdHinweisHtml(e) +" assets/karte.js'

probe "auch eigene Apps tragen den Fremd-Hinweis (Klaus warnt vor sich selbst)" \
      assets/karte.js 's|if (e \&\& e.own === true) return "";|if (false) return "";|'

probe "der Wortlaut des Fremd-Hinweises faellt weg" \
      assets/karte.js 's|Eingetragen, nicht abgestimmt.|Hinweis.|'

probe "der Fremd-Hinweis verliert sein Aussehen" \
      assets/style.css 's|^\.listing \.fremd-hinweis {|.listing .fremd-hinweis-alt {|'

# Der teuerste Fehler: ein fremder Eintrag kommt dazu, aber niemand laesst
# `node tools/statische-listen.mjs` laufen. Dann steht der Hinweis erst nach der
# ersten Suche da — und die Besucher, die nur lesen, sehen ihn nie.
probe "ein Eintrag wird fremd, ohne dass die statische Liste nachgezogen wird" \
      assets/config/listings.js '0,/"own": true/s|"own": true|"own": false|'


# ---- Meldungen haben einen eigenen Platz im Studio --------------------------
# Jeder dieser Fehler wirft die Meldungen zurueck in den Einreichungs-Stapel,
# wo sie als kaputte Eintraege aussehen — oder er nimmt ihnen genau das, was
# eine Meldung ueberhaupt lesbar macht.
probe "Meldungs-Block ganz entfernt" \
      assets/studio.js 's|<h3>Meldungen |<h3>Weg |'

probe "Meldungen landen wieder im Einreichungs-Stapel" \
      assets/studio.js 's|it.zweck === "meldung"|false|'

probe "Einreichungen holen die Meldungen zurueck" \
      assets/studio.js 's|it.zweck !== "meldung"|true|'

probe "Meldungen rutschen unter die Einreichungen" \
      assets/studio.js 's|"<h3>Meldungen |"<h3>zzMeldungen |'

probe "der Grund der Meldung faellt weg" \
      assets/studio.js 's|it.grund_text \|\| |it.nixda \|\| |'

probe "der Wortlaut des Melders faellt weg" \
      assets/studio.js 's|studio-hinweis-melder|studio-egal|g'

probe "rechtswidrige Meldungen stechen nicht mehr heraus" \
      assets/studio.js 's|it.grund === "recht"|false|'

probe "… und die Hervorhebung faellt aus dem Stylesheet" \
      assets/style.css 's|^\.studio-meldung-zeile\.ist-ernst|.studio-egal-ist-ernst|'

probe "Meldung laesst sich nicht mehr erledigen" \
      assets/studio.js 's|data-merledigt|data-egal1|g'

probe "… und nicht mehr bestaetigen (nur noch abhaken)" \
      assets/studio.js 's|data-mbestaetigt|data-egal2|g'

probe "eine alte Server-Datei wird verschwiegen" \
      assets/studio.js 's|schickt noch kein <code>zweck</code>-Feld mit|ist in Ordnung|'

probe "… oder ihr Fehlen wird nur behauptet statt festgestellt" \
      assets/studio.js 's|!serverKenntZweck && QUEUE.length|true|'

probe "die gemeldete Seite ist nicht mehr erreichbar" \
      assets/studio.js 's|function gemeldeterEintrag|function unbenutzt|'

probe "ein geloeschter Eintrag wird stillschweigend verlinkt" \
      assets/studio.js 's|nicht (mehr) in der Liste|egal|'


# ---- Rechtstexte -----------------------------------------------------------
# Seit dem 2026-08-10 laeuft die Seite oeffentlich. Damit dreht sich die Gefahr
# um: nicht die Anschrift IM Repo ist das Problem, sondern eine oeffentliche
# Seite OHNE ladungsfaehige Anschrift. Der Waechter ist mitgedreht — diese
# Proben belegen, dass er in der neuen Richtung wirklich zubeisst.
probe "Impressum faellt auf einen Platzhalter zurueck" \
      impressum.html 's|Klaus Nitzsche<br>|[NAME]<br>|'

probe "Impressum verliert die Anschrift" \
      impressum.html 's|21077 Hamburg|irgendwo|'

probe "Impressum verliert die Kontakt-Adresse" \
      impressum.html 's|info@family-projekt.de|niemand|g'

probe "Impressum verliert den Paragrafen-Bezug" \
      impressum.html 's|§ 5 DDG|Angaben|'

probe "Impressum verliert den inhaltlich Verantwortlichen" \
      impressum.html 's|§ 18 Abs. 2 MStV|die Seite|'

probe "Impressum verliert die Haftung fuer fremde Apps" \
      impressum.html 's|<h2>Haftung für fremde Apps</h2>|<h2>Sonstiges</h2>|'

probe "… und den Melde-Weg dazu (Absage ohne Abhilfe)" \
      impressum.html 's|unverzüglich entfernt|spaeter angesehen|'

probe "die AGB-Begruendung verschwindet (sieht aus wie vergessen)" \
      impressum.html 's|<h2>Keine AGB</h2>|<h2>Weiteres</h2>|'

probe "Datenschutz verschweigt den Hoster" \
      datenschutz.html 's|GitHub|Irgendwer|g'

probe "Datenschutz verschweigt den Anbieter des Sprachmodells" \
      datenschutz.html 's|Hugging Face|einem Anbieter|'

probe "Datenschutz behauptet ein eigenes Relais (kopiert statt geprueft)" \
      datenschutz.html 's|damus|eigenes|g'

probe "Datenschutz verschweigt den Weg der Formulare" \
      datenschutz.html 's|Warteschlangen-Datei|Ablage|'

probe "Datenschutz verschweigt, dass Melden ohne Ausweis geht" \
      datenschutz.html 's|ohne sich auszuweisen|mit Angabe der E-Mail|'

probe "Datenschutz verschweigt den IP-Kuerzel" \
      datenschutz.html 's|nicht rückrechenbarer Kennwert|Merkmal|'

# NEGATIV-Richtung: die Anschrift darf NUR in den Rechtstexten stehen.
probe "die Anschrift sickert auf die Startseite" \
      index.html 's|</main>|<p>Klaus Nitzsche, info@family-projekt.de</p></main>|'

probe "Schutz gegen den stillen Verlust entfernt (Empfaenger wirft zu fruehe Meldungen weg)" \
      assets/app.js 's|var offen = 1600 - (Date.now() - GELADEN);|var offen = 0;|'

probe "Brief zeigt nicht mehr auf den Geld-Beschluss (er wird nie gefunden)" \
      docs/sessions/BRIEF_naechste-sitzung.md 's|GELD-ENTSCHEIDUNGEN.md|GELD-GIBTSNICHT.md|g'

probe "Geld-Beschluss verschweigt die Stufe (liest sich wie ein Angebot)" \
      docs/GELD-ENTSCHEIDUNGEN.md 's|Stufe 1|Abschnitt A|g'


# ── Die Ampel des Wächters (Schritt 3, 2026-08-11) ──────────────────────────
# Jede dieser Sabotagen ist ein Weg, auf dem eine Sperre still nicht mehr
# sperrt. Wenn eine davon den Smoke NICHT umwirft, bewacht er die Sperre nicht.

probe "gesperrter Eintrag behaelt seinen Link (Sperre sperrt nichts mehr)" \
      assets/karte.js 's|(e.url \&\& !gesperrt|(e.url|'

probe "das Band verschwindet von der Karte (Sperre ohne Begruendung)" \
      assets/karte.js 's|^          wacheHtml(e) +$||'

probe "der Grund wird ungeprueft ins Markup gelegt (fremder Text, kein esc)" \
      assets/karte.js 's|esc(String(w.grund))|String(w.grund)|'

probe "gesperrter Eintrag darf wieder Fund der Woche werden" \
      assets/karte.js 's|return e \&\& e.img \&\& !istGesperrt(e);|return e \&\& e.img;|'

probe "die Rangfolge wird umgedreht (aus Loesen wird Sperren)" \
      assets/studio.js 's|var WACHE_RANG = { gruen: 0, gelb: 2, rot: 3 };|var WACHE_RANG = { gruen: 3, gelb: 2, rot: 0 };|'

probe "gruen bekommt denselben Rang wie nichts (Freigeben aus dem Browser)" \
      assets/studio.js 's|var WACHE_RANG = { gruen: 0, gelb: 2, rot: 3 };|var WACHE_RANG = { gruen: 1, gelb: 2, rot: 3 };|'

probe "ein unbekanntes Wort gilt ploetzlich als gueltig" \
      assets/studio.js 's|hasOwnProperty.call(WACHE_RANG, a) ? WACHE_RANG\[a\] : -1|hasOwnProperty.call(WACHE_RANG, a) ? WACHE_RANG[a] : 3|'

probe "das Studio schickt die Ampel nicht mehr an den Server" \
      assets/studio.js 's|ruf("commit_wache"|ruf("commit_nichts"|'

probe "die Ampel wird wieder nachgeladen statt eingebacken (Layout-Sprung)" \
      assets/app.js 's|var GELADEN = Date.now();|var GELADEN = Date.now(); fetch("assets/config/wache-hand.json");|'

probe_befehl "die Seite verliert den Ampel-Block (PT_WACHE ist nie gesetzt)" \
      index.html "sed -i 's|<script>window.PT_WACHE = |<script>window.PT_KEINE_WACHE = |' index.html"

probe "der Bau-Lauf hoert nicht mehr auf die Ampel (Sperre wird nie sichtbar)" \
      .github/workflows/statische-liste.yml 's|      - .assets/config/wache-hand.json.||'

probe_befehl "index.html traegt eine Sperre, die es im Handschalter nicht gibt" \
      index.html "sed -i 's|<script>window.PT_WACHE = {}|<script>window.PT_WACHE = {\"markt-rezeptbuch\":{\"ampel\":\"rot\",\"grund\":\"x\",\"seit\":\"2026-08-11\"}}|' index.html"

probe_befehl "der Handschalter verliert seine Erklaerung (niemand weiss, wie er wirkt)" \
      assets/config/wache-hand.json "printf '{}\n' > assets/config/wache-hand.json"

# ── SCHRITT 4: der Schalter und das gerechnete Gelb (2026-08-12) ─────────────
# Jede dieser Luecken macht die Automatik entweder blind oder uebergriffig.
# Faellt der Smoke bei einer davon nicht um, bewacht er den Schalter nicht.

probe "das gerechnete Band wird nie gezeichnet (Automatik ohne Wirkung)" \
      assets/karte.js 's|return autoGelbHtml(e);|return "";|'

probe "der Schalter wird ignoriert — die Automatik laeuft immer" \
      assets/karte.js 's|if (!autoAn()) return null;||'

probe "die Schwelle faellt weg (schon eine schlechte Nacht gibt Gelb)" \
      assets/karte.js 's|if (tief < autoNaechte()) return null;||'

probe "die Hand gewinnt nicht mehr (die Rechnung uebergeht die Freigabe)" \
      assets/karte.js 's|if (hand === "rot" \|\| hand === "gelb" \|\| hand === "gruen") return null;||'

# ⚠ DIESER ANKER WAR TOT, UND ZWAR SCHON AUF origin/main (gefunden 2026-09-21).
#   Er suchte `if (e.ampel !== 'rot' && … ) continue;` — diese Form steht im Code
#   seit langem nicht mehr, dort heisst es `const hatAmpel = e.ampel === 'rot' || …`.
#   Der Fall aenderte also NICHTS und meldete sich trotzdem als bestanden: die
#   erste der Arten, wie eine Gegenprobe nichts misst. Gefunden hat ihn nicht der
#   Lauf, sondern das Nachzaehlen beim Umbau.
#   Die Datei ist seit dem 2026-09-21 tools/lib/markt-lesen.mjs.
probe "gruen faellt wieder aus der Seite (Hand-Freigabe wirkungslos)" \
      tools/lib/markt-lesen.mjs "s|\|\| e.ampel === 'gruen'||"

probe "der Schalter wird nicht eingebacken (die Seite weiss nichts von ihm)" \
      tools/statische-listen.mjs "s|; window.PT_AUTOMATIK = ' + auto + '||"

probe "das Studio nimmt wieder die feste Zahl statt der eingestellten" \
      assets/studio.js 's|function schwelleNaechte() { return autoZahl("naechte", SCHWELLE_NAECHTE, 1, 30); }|function schwelleNaechte() { return SCHWELLE_NAECHTE; }|'

# HIER STAND VORHER: eine Probe, die `"an": false` auf `true` drehte und
# verlangte, dass der Smoke umfällt („Schritt 4 sagt: anfangs aus").
#
# Die ist am 2026-08-14 ersatzlos entfallen, und zwar mit Absicht: der Smoke
# darf da gar nicht mehr umfallen. `an: true` ist kein Fehler, sondern Klaus'
# Entscheidung — bei seinem ersten echten Lauf schrieb das Studio genau das in
# die Datei, `main` wurde rot, und weil der Nachzieh-Lauf VOR dem Committen
# prüft, kam der Schalter nie auf der Seite an. Ein Wächter, der das Feature
# verhindert, das er bewacht.
#
# Die Zusage „anfangs aus" gilt weiter — nur an der richtigen Stelle: im Code,
# der die Datei liest („ohne Schalter gilt: aus", „Unsinn im Schalter wirkt
# nicht"). Was in der Datei bleibt, ist die FORM. Also drei Proben dafür:
probe_befehl "der Schalter traegt statt ja/nein ein Wort" \
      assets/config/wache-hand.json "sed -i 's|\"an\": true|\"an\": \"ja\"|; s|\"an\": false|\"an\": \"ja\"|' assets/config/wache-hand.json"

probe_befehl "die Naechte-Zahl faellt unter den erlaubten Bereich" \
      assets/config/wache-hand.json "sed -i 's|\"naechte\": 3|\"naechte\": 0|' assets/config/wache-hand.json"

probe_befehl "die Meldungs-Zahl schiesst ueber den erlaubten Bereich" \
      assets/config/wache-hand.json "sed -i 's|\"meldungen\": 4|\"meldungen\": 999|' assets/config/wache-hand.json"

probe_befehl "die Grenze in der Datei laeuft dem naechtlichen Lauf davon" \
      assets/config/wache-hand.json "sed -i 's|\"grenze\": 50|\"grenze\": 60|' assets/config/wache-hand.json"

# ── Die Zeitachse (Klaus 2026-08-15) ───────────────────────────────────────
# Die Liste ist nach dem Anfangsdatum sortiert und zeigt es an jeder Karte.
# Sechs Wege, auf denen das leise kaputtgehen kann — jeder bekommt seine Probe.
# Kein Datum ist hier ein Anker: gezielt wird auf `"seit"` und auf `[0-9-]*`,
# nie auf einen konkreten Wert (sonst wird die Probe blind, sobald sich ein
# Eintrag ändert — derselbe Fehler wie damals mit `?v=2`).
probe_befehl "an einem Eintrag fehlt das Anfangsdatum" \
      assets/config/listings.js \
      "sed -i '0,/\"seit\": \"[0-9-]*\",/{/\"seit\": \"[0-9-]*\",/d}' assets/config/listings.js"

probe_befehl "die Reihenfolge stimmt nicht mehr mit den Daten ueberein" \
      assets/config/listings.js \
      "sed -i '0,/\"seit\": \"[0-9-]*\"/s//\"seit\": \"2099-01-01\"/' assets/config/listings.js"

# ⚠ Zielt auf den AUFRUF, nicht auf seine Nachbarschaft. Die erste Fassung
# suchte `seitHtml(e) + messdatumHtml(e)` — bis am 2026-08-21 `sichttestHtml(e)`
# DAZWISCHEN kam. Der sed fand nichts mehr, änderte nichts, und der Smoke blieb
# grün: die Falle aus dem Kopf dieser Datei, ausgelöst durch ein eingefügtes
# Feld. Wer etwas in eine Kette schiebt, sieht die Gegenproben durch, die auf
# die Nachbarschaft zeigen.
probe_befehl "die Karte zeigt das Anfangsdatum nicht mehr" \
      assets/karte.js \
      "sed -i 's|seitHtml(e) + ||' assets/karte.js"

probe_befehl "die Monatsnamen sind weg (aus dem Datum wuerde eine Zahl)" \
      assets/karte.js "sed -i 's|var MONATE_DE = \[|var MONATE_UNBENUTZT = [|' assets/karte.js"

probe_befehl "ein fehlendes Datum reisst die Karte auf" \
      assets/karte.js "sed -i 's|if (!m) return \"\";|if (!m) return String(s);|' assets/karte.js"

probe_befehl "die statische Liste ist nach dem Eintragen nicht neu geschrieben" \
      index.html "sed -i 's|class=\"seit\"|class=\"seit-alt\"|g' index.html"

# ── Der Markt-Abgleich (Klaus 2026-08-15) ──────────────────────────────────
# Das Werkzeug steht und fällt mit EINER Unterscheidung: unterschiedliche
# Frische (harmlos) gegen echten Widerspruch (gleiches Datum, andere Zahlen).
# Verwechselt es die, meldet es entweder dauernd etwas oder nie — beides macht
# es wertlos. Also wird genau diese Unterscheidung sabotiert.
probe_befehl "der Abgleich haelt jeden Unterschied fuer einen Widerspruch" \
      tools/markt-abgleich.mjs \
      "sed -i 's|if (dHier \&\& dDort \&\& dHier === dDort) {|if (true) {|' tools/markt-abgleich.mjs"

probe_befehl "der Abgleich haelt einen Widerspruch fuer blosse Frische" \
      tools/markt-abgleich.mjs \
      "sed -i \"s|return { art: 'widerspruch', datum: dHier };|return { art: 'frische', neuer: 'family' };|\" tools/markt-abgleich.mjs"

probe_befehl "die Feld-Uebersetzung verrutscht (praxis/gute_praxis)" \
      tools/markt-abgleich.mjs \
      "sed -i \"s|\\['praxis', 'gute_praxis'\\]|['praxis', 'praxis']|\" tools/markt-abgleich.mjs"

probe_befehl "die neuere Seite wird falsch herum benannt" \
      tools/markt-abgleich.mjs \
      "sed -i \"s|(dHier > dDort ? 'toolpoint' : 'family')|(dHier > dDort ? 'family' : 'toolpoint')|\" tools/markt-abgleich.mjs"

probe_befehl "ein fehlender Eintrag gilt als Befund" \
      tools/markt-abgleich.mjs \
      "sed -i 's|if (!hier .. !dort) return null;|if (!hier \&\& !dort) return null;|' tools/markt-abgleich.mjs"

probe_befehl "der Abgleich faengt an zu schreiben" \
      tools/markt-abgleich.mjs \
      "sed -i \"s|import { readFileSync, existsSync } from 'node:fs';|import { readFileSync, existsSync, writeFileSync } from 'node:fs';|\" tools/markt-abgleich.mjs"

probe_befehl "der Abgleich laeuft schon beim blossen Import los" \
      tools/markt-abgleich.mjs "sed -i 's|AUFGERUFEN|IMMER_LOS|g' tools/markt-abgleich.mjs"

# ── Auslieferungsprüfer ──────────────────────────────────────────────────────
#
# Die Prüf-Logik hat zwei Fassungen (Python in Kimhub, JavaScript hier), und die
# wichtigste Zusicherung ist, dass sie DASSELBE sagen. Ein Wächter dafür ist
# leicht blind: er vergleicht zwei Listen und ist zufrieden, wenn beide leer
# sind. Darum bauen die Fälle hier echte Unterschiede ein.
#
# Auf STABILE Anker gezielt, nie auf eine Versionsnummer — siehe die Warnung oben.

probe "der Prüfer meldet ein Bild ohne Beschreibung nicht mehr" \
      assets/pruefer.js \
      's|tag === "img" \&\& !Object|tag === "IMG-GIBTS-NICHT" \&\& !Object|'

probe "ein <a href=\"https://…\"> gilt plötzlich als fremde Ladung (27 von 58 Fehlalarmen kehren zurück)" \
      assets/pruefer.js \
      's|"link", "base", "image", "use"|"link", "base", "image", "use", "a"|'

# ⚠ ANKER NACHGEZOGEN 2026-08-23. Der Fall darueber zielte auf
# `["link", "base"]` — die Liste hat seitdem `image` und `use` dazubekommen,
# `sed` fand nichts und aenderte nichts, und der Smoke blieb zu Recht gruen.
# Der Fall meldete sich als BLIND. Wer eine Zeile aendert, auf die eine
# Gegenprobe zielt, zieht sie mit. (Zum zweiten Mal an einem Tag, in zwei
# verschiedenen Repos.)

probe "svg image/use holen wieder unbemerkt von fremd" \
      assets/pruefer.js \
      's|"link", "base", "image", "use"|"link", "base"|'

probe "background und ping werden wieder uebersehen" \
      assets/pruefer.js \
      's|"background", "ping"|"gibtsnicht1", "gibtsnicht2"|'

probe "der Klartext-Satz vor der Kennung faellt weg" \
      assets/pruefer-ui.js \
      's|li.appendChild(t("p", "pr-kopf", k.kopf));||'

probe "der Selbsttest loescht wieder ohne Rueckfrage" \
      assets/pruefer-ui.js \
      's|if (quelle.value.trim() \&\& !window.confirm(|if (false \&\& !window.confirm(|'

# ⚠ ANKER NACHGEZOGEN (2026-09-26): die Zeile `if (mitreihe) mitreihe.hidden =
# false;` gibt es seit dem Umbau auf `mitreiheZeigen()` nicht mehr — der Fall
# war ein toter Anker, kein blinder Waechter. Sabotiert wird der Aufruf nach
# einer Pruefung; er steht genau einmal in der Datei.
probe "es gibt wieder nichts zum Mitnehmen" \
      assets/pruefer-ui.js \
      's|    mitreiheZeigen(true);||'

# ⚠ HIER STAND EINE SABOTAGE, DIE DAS FALSCHE TAUSCHTE: sie aenderte das
# `type`-Attribut, und die ADRESSE blieb das eigene Zeichen. Der Waechter
# prueft die Adresse — also fiel nichts um, zu Recht. Sabotiert wird, was
# bewacht wird.
probe "das Werkzeug traegt wieder das Icon des Marktplatzes" \
      auslieferungspruefer.html \
      's|href="data:image/svg+xml,%3Csvg|href="assets/icon-192.png?v=39" data-alt="%3Csvg|'

probe "die Fülltext-Suche greift ohne Wortgrenze (tbd meldet wieder tbDark)" \
      assets/pruefer.js \
      's|maskiere(w) + "(?!|maskiere(w) + "(?:|'

probe "die Erlaubt-Liste wirkt gar nicht mehr (das Feld wäre eine Attrappe)" \
      assets/pruefer.js \
      's|if (kennung === "FREMDE-ADRESSE") {|if (false) {|'

probe "eine Teil-Übereinstimmung reicht der Erlaubt-Liste (seite.de deckt fremde-seite.de)" \
      assets/pruefer.js \
      's|wirt.slice(-(erlaubt\[i\].length + 1)) === "." + erlaubt\[i\]|wirt.indexOf(erlaubt[i]) !== -1|'

probe "der Scanner fängt Kommentare nicht mehr als Ganzes (auskommentiertes Markup zählt als echt)" \
      assets/pruefer.js \
      's|<(!--\[\\s\\S\]\*?--\||<(|'

probe "die Seite lädt die Prüf-Logik nicht mehr (der Knopf wäre tot)" \
      auslieferungspruefer.html \
      's|<script src="assets/pruefer.js|<script src="assets/pruefer-FEHLT.js|'

probe "die Seite kommt ohne Sprachangabe (ihr eigener Prüfer würde sie anklagen)" \
      auslieferungspruefer.html \
      's|^<html lang="de">|<html>|'

probe "der Eintrag verliert sein Bild (bei eigenen Einträgen ist es Pflicht)" \
      assets/config/listings.js \
      's|"img": "assets/pruefer-karte.png",||'

probe "der neue Eintrag rutscht in der Zeitachse nach vorn" \
      assets/config/listings.js \
      's|"seit": "2026-08-20"|"seit": "2026-01-01"|'

probe "die eigene Probe wird aus dem Läufer genommen (sie liefe nur noch, wer sie kennt)" \
      tests/smoke.mjs \
      's|./smoke_pruefer.mjs|./smoke_pruefer-GIBTS-NICHT.mjs|'

# ── Die eigene Frist am Kindprozess (2026-09-11) ─────────────────────────────
#
# Vorher stand im Läufer „eigene Probe grün: nein", sobald das Kind mit einem
# Fehler endete — auch dann, wenn es an seiner EIGENEN Uhr gestorben war. Eine
# Zeile, die nach einem Befund aussieht und eine Zeitüberschreitung ist.
# Jeder Riegel dagegen bekommt hier seinen Fehler.

# Der dritte Ausgang faellt weg: eine Zeitueberschreitung waere wieder ein Befund.
probe "die Zeitüberschreitung wird wieder als Befund gemeldet" \
      tests/kindprozess.mjs \
      "s|return { art: 'frist', zeile, dauerMs, fristMs,|return { art: 'rot', zeile, dauerMs, fristMs,|"

# Die Gegenrichtung, und sie ist die gefaehrlichere: ein Mechanismus, der ALLES
# als „nicht abgeschlossen" einstuft, bestuende die erste Pruefung glaenzend und
# verschluckte jeden echten Befund.
probe "jeder Fehlschlag gilt als nicht-abgeschlossen (ein echter Befund verschwindet)" \
      tests/kindprozess.mjs \
      "s|  return { art: 'rot', zeile, dauerMs, fristMs,\$|  return { art: 'frist', zeile, dauerMs, fristMs,|"

# Die Reihenfolge: zuerst die Schlusszeile des Kindes, dann die Uhr. Ohne sie
# spraeche ein Pruefling, dessen Befundtext das Wort „Timeout" traegt, sich
# selbst frei.
probe "der echte Befund wird nicht mehr ZUERST gelesen" \
      tests/kindprozess.mjs \
      "s|if (treffer \&\& Number(treffer\[2\]) > 0) {|if (false) {|"

# Und der Weg vom Befund zur Zeile: wer hier `ok(…,false)` einsetzt, hat die
# rote Zeile zurueck, die nichts bedeutet.
# ⚠ Dieser Fall zielt auf die VERDRAHTUNG, und der Waechter dazu liest den
# Quelltext, statt ihn zu fahren — die Grenze steht im Waechter selbst benannt.
probe "die Frist-Zeile wird wieder als rote Zeile gemeldet" \
      tests/smoke.mjs \
      "s|if (r.art === 'frist') {|if (false) {|"

# Eine dritte Spalte, die nur bei Bedarf erscheint, liest niemand.
probe "die dritte Spalte fällt aus der Schlusszeile" \
      tests/kindprozess.mjs \
      "s| · \${offen} nicht abgeschlossen||"

# ⚠ UND DIE FRIST SELBST. Ohne sie kehrt `node tests/smoke_pruefer.mjs` bei einem
# haengenden Kind NIE zurueck — der Fall wird deshalb von der Frist des
# Gegenprobe-Laeufers gefangen (124), nicht von einem Waechter. Das ist der
# Grund, aus dem `$FRIST` oben steht.
probe "die Frist am Kindprozess wird ausgebaut (der Läufer hängt)" \
      tests/kindprozess.mjs \
      "s|timeout: fristMs, maxBuffer: 64e6|maxBuffer: 64e6|"

# ── Der Sprach-Waehler reserviert seine Breite (2026-09-11) ──────────────────
#
# Er steht leer in der Seite; `app.js` fuellt ihn. Leer 36 px, gefuellt 176 px —
# und „Suchen" rutschte dadurch auf eine eigene Zeile. Das war die GANZE CLS der
# Startseite (0,062). `max-width` reserviert NICHTS; genau so stand es vorher.
probe "der Sprach-Wähler reserviert seine Breite nicht mehr (CLS kehrt zurück)" \
      assets/style.css \
      's|  width: 11rem; max-width: 11rem; align-self|  max-width: 11rem; align-self|'

# ── Die Suchzeile steht auf einer Linie (Klaus 2026-09-14) ───────────────────
#
# Er hat es am Tablet gesehen: der Waehler trug `height: 40px`, waehrend Feld und
# „Suchen" aus ihrem Innenabstand 53,6 px hoch werden. In einer Flex-Zeile
# richten sich alle drei OBEN aus — die Unterkante lag 13,6 px hoeher.
#
# ⚠ DIESER FALL BAUT DEN URSPRUENGLICHEN FEHLER WORTWOERTLICH WIEDER EIN. Ein
# Wert, der die Hoehe festnagelt, hebelt `align-self: stretch` aus; genau das war
# der Zustand vor der Reparatur.
probe "der Sprach-Wähler bekommt wieder eine feste Höhe (er steht höher als der Suchen-Knopf)" \
      assets/style.css \
      's|align-self: stretch; min-height: 44px;|height: 40px;|'

# Und die zweite Haelfte: „buendig" allein waere auch dann erfuellt, wenn alle
# drei flach waeren. Die Mindesthoehe greift NUR bei 300 px, wo der Waehler allein
# in seiner Reihe steht und ihn nichts mehr streckt — bei 1280 und 380 nimmt er
# ohnehin die Hoehe der Zeile. Ohne die dritte Breite in der Probe waere dieser
# Fall nicht zu fangen; er ist der Beleg, dass sie dort wirklich gebraucht wird.
probe "die Fingerbreite des Sprach-Wählers wird abgesenkt" \
      assets/style.css \
      's|align-self: stretch; min-height: 44px;|align-self: stretch; min-height: 20px;|'

# ── Jede ?v= traegt dieselbe Nummer (Befund 2026-09-14) ─────────────────────
#
# Beim Bump auf v48 kam heraus: die Seiten holten alles mit `?v=47`, `sw.js`
# legte alles mit `?v=45` ab, impressum und datenschutz standen bei `?v=19`.
# Fuer den Browser sind das verschiedene Dateien — der Offline-Vorrat hielt keine
# einzige Adresse, die eine Seite anfragt. Die alte Pruefung sah nur `style.css`
# in `index.html` und war dabei die ganze Zeit gruen.
# ⚠ KEINE FESTE NUMMER IM AUSDRUCK — die Warnung dazu steht oben in dieser
# Datei, und der erste Anlauf dieser Faelle ist prompt hineingelaufen. Gezielt
# wird auf `?v=[0-9]*`, gesetzt wird `?v=1`: das weicht von jeder kuenftigen
# Cache-Version ab, ohne auf die heutige zu zeigen.
probe "eine Seite bleibt auf einer alten ?v= zurück" \
      auslieferungspruefer.html \
      's|assets/thema\.js?v=[0-9]*|assets/thema.js?v=1|'

probe "der Offline-Vorrat legt eine alte ?v= ab" \
      sw.js \
      's|"assets/app\.js?v=[0-9]*"|"assets/app.js?v=1"|'

# ⚠ UND EIN SKRIPT TRAEGT AUCH EINE ADRESSE (Befund 2026-09-16).
# `assets/app.js` haengt `assets/studio.js?v=…` erst auf langen Druck in die
# Seite. Die Pruefung sah bis dahin nur die fuenf HTML-Seiten und den Vorrat —
# dieses eine ?v= stand deshalb seit Monaten auf einer eigenen Nummer (gemessen:
# 16, waehrend die Seiten auf 50 und die Cache-Version auf 55 stand), ohne dass
# irgendetwas rot wurde. DIESER FALL WAERE VOR DEM 2026-09-16 NICHT GEFANGEN
# WORDEN; er ist der Beleg, dass die Traegerliste wirklich GEFUNDEN wird.
probe "ein Skript haengt eine alte ?v= in die Seite" \
      assets/app.js \
      's|assets/studio\.js?v=[0-9]*|assets/studio.js?v=1|'

# Die Gegenrichtung zur gefundenen Liste: findet sie nur noch Seiten und keine
# Skripte mehr, ist der Waechter wieder der Waechter am Einzelfall, von dem er
# herkommt — und das saehe man an keiner roten Zeile.
probe "die Trägerliste findet keine Skripte mehr" \
      tests/smoke.mjs \
      "s|\.\.\.jsUnter('assets')\.sort()|...[]|"

# ⚠ UND EINE SEITE IM UNTERVERZEICHNIS ZAEHLTE NICHT MIT (Befund 2026-09-21).
# Der Skript-Teil der Traegerliste stieg seit jeher hinab, der Seiten-Teil las
# nur die Wurzel (`readdirSync(ROOT)`). `schulung/…Schulung.html` lief deshalb
# durch keinen Versions-Waechter.
# Von Hand nachgestellt, in BEIDE Richtungen: mit der alten Zeile blieb der
# Smoke bei derselben Sabotage gruen (989/989, Rueckgabewert 0), mit der neuen
# faellt genau diese Zusicherung und nennt die Fundstelle.
# ⚠ DER FALL SETZT DIE NUMMER ERST HINEIN, und das ist kein Umweg: die
# Schulungsseite traegt heute GAR KEINE `?v=`-Adresse. Ein Fall, der nur die
# Traegerliste beschneidet, aendert an dieser Datei also nichts und waere
# blind — nicht weil der Waechter schwach ist, sondern weil es nichts zu
# finden gibt. Mit den Detailseiten unter `apps/` gibt es das.
probe_befehl "eine Seite im Unterverzeichnis hängt auf einer alten ?v= zurück" \
      schulung/EU_AI_Act_Art4_KI_Schulung.html \
      "sed -i '0,/<title>/s||<link rel=\"stylesheet\" href=\"assets/style.css?v=1\">\\n<title>|' schulung/EU_AI_Act_Art4_KI_Schulung.html"

# Die Gegenrichtung: stuenden gar keine Nummern mehr da, waere der Waechter
# oben gruen, weil seine LISTE LEER ist — von seinem Fehlen nicht zu
# unterscheiden.
#
# ⚠ ZWEI RIEGEL DECKEN EINANDER, ALSO WERDEN BEIDE ZUGLEICH SABOTIERT. Der
# erste Anlauf nahm die Nummern nur aus `index.html` — dann fiel die AELTERE
# Pruefung („Cache-Version und ?v= der Schale passen zusammen", die genau diese
# Datei ansieht), und der Fall galt als gefangen, ohne ueber den Zaehler etwas
# zu sagen. Gefangen aus dem falschen Grund. Jetzt verlieren ALLE fuenf Seiten
# ihre Nummern; beide roten Zeilen stehen danach da, und die mit dem Namen
# dieser Zusicherung ist dabei.
# ══ Ein fehlendes Komma in der Modul-Kette (Befund 2026-09-14 auf main) ══════
#
# Zwei Array-Literale nebeneinander liest JavaScript als INDEX-ZUGRIFF; die
# Liste endet auf `undefined`, und die Kette stirbt am letzten Glied. `node
# --check` schweigt, denn gueltig ist es. Gemessen im Browser: kein Siegel, kein
# Verbinden-Fenster — auf dem Marktplatz wie beim Pruefer.
probe "in der Kette des Marktplatzes fehlt ein Komma" \
      assets/sbkim-init.js \
      's|"assets/siegel-inhalt.js"\],|"assets/siegel-inhalt.js"]|'

probe "in der Kette des Prüfers fehlt ein Komma" \
      assets/pruefer-sbkim-init.js \
      's|"assets/pruefer-siegel-inhalt.js"\],|"assets/pruefer-siegel-inhalt.js"]|'

# Die Gegenrichtung: waere die Kette LEER, waere der Waechter oben zufrieden —
# er findet dann nichts, was ohne Komma dasteht, und meldet Ruhe.
#
# ⚠ DER ERSTE ANLAUF WAR BLIND. Er benannte die Pfade um (`assets/…` →
# `WEG-assets/…`); ein umbenanntes Paar ist aber immer noch ein Paar, und
# gezaehlt werden Paare. Die Sabotage aenderte etwas und mass nichts — Kimhubs
# siebte Art. Jetzt wird die Kette wirklich geleert.
#
# ⚠ BENANNTE DOPPELUNG: bei einer leeren Kette fallen SIEBEN Zeilen, denn die
# aelteren Waechter auf die Pflicht-Module und die Reihenfolge greifen auch.
# Die Zeile mit dem Namen DIESER Zusicherung ist dabei — von Hand nachgestellt
# und gesehen: „jedes Kettenglied ist ein Paar aus Typ und Pfad (0)".
probe_befehl "die Kette des Marktplatzes verliert ihre Glieder" \
      assets/sbkim-init.js \
      "python3 -c \"
import io,re
p='assets/sbkim-init.js'
s=io.open(p,encoding='utf-8').read()
s=re.sub(r'var KANON = \\[[\\s\\S]*?\\n  \\];', 'var KANON = [\\n  ];', s, count=1)
io.open(p,'w',encoding='utf-8').write(s)
\""

# ══ Sprache DE/EN und der Riegel gegen den Auto-Uebersetzer (Klaus 2026-09-14) ══
#
# Uebernommen aus family-project (PR #294 und #296 desselben Tages). Die
# Begruendungen stehen in `assets/sprache.js`; hier stehen die Faelle.

# ⚠ DER ERSTE ANLAUF WAR BLIND, und zwar aus einem Grund, der in Kimhubs
# Verfassung dreimal steht: er benannte die Marke `PT-SPRACHRIEGEL` in
# `PT-SPRACHRIEGEL-AUS` um, und der Waechter suchte den ANFANG dieses Namens —
# also fand er ihn weiter. Sabotiert wird jetzt der Schluessel selbst.
probe "der Sprachriegel verschwindet aus einer Seite" \
      knotenkarte.html \
      's|toolpoint_lang_wahl|toolpoint_lang_wahl_aus|g'

# ⚠ DER TEUERSTE FALL: der Riegel haengt an der SPRACHE statt an der WAHL.
# Dann waere JEDER Besucher sofort gesperrt — auch der, der nie etwas gewaehlt
# hat, und genau fuer den bleibt Googles Uebersetzer an. Der Schaden waere
# unsichtbar: die Seite saehe fuer Klaus voellig richtig aus.
probe "der Riegel greift schon ohne Wahl (jeder wird gesperrt)" \
      index.html \
      's|toolpoint_lang_wahl")!=="1"|toolpoint_lang_wahl")==="1"|'

probe "das Wörterbuch wird erst NACH der Sprach-Datei geladen" \
      index.html \
      's|<script src="assets/i18n-index.js|<script src="assets/sprache.js|; s|<script src="assets/sprache.js?v=\([0-9]*\)"></script>\n<script src="assets/thema|<script src="assets/i18n-index.js?v=\1"></script>\n<script src="assets/thema|'

probe "ein Schlüssel fehlt im englischen Wörterbuch" \
      assets/i18n-knotenkarte.js \
      's|"kk_e4_t": "Still the shared room",||'

# ⚠ BEFUND 2026-09-18: „Impressum &amp; Datenschutz" stand WÖRTLICH in der
# Fußzeile des Prüfers. `data-i18n` setzt textContent, und das deutet keine
# Entität. Beide Sprachen einzeln — der englische Eintrag war richtig, der
# deutsche nicht; ein Fall, der nur eine Sprache trifft, misst nur diese.
probe "Entität im deutschen Wörterbuch-Eintrag der Fußzeile (der Fehler vom 2026-09-18)" \
      assets/i18n-pruefer.js \
      's|"pr_fuss_recht": "Impressum & Datenschutz"|"pr_fuss_recht": "Impressum \&amp; Datenschutz"|'

probe "Entität im englischen Wörterbuch-Eintrag der Fußzeile" \
      assets/i18n-pruefer.js \
      's|"pr_fuss_recht": "Imprint & Privacy"|"pr_fuss_recht": "Imprint \&amp; Privacy"|'

probe "ein Betrag steht im englischen Text" \
      assets/i18n-index.js \
      's|"ix_eb_bed1": "<strong>Free of charge.</strong> Listing costs nothing."|"ix_eb_bed1": "<strong>Free of charge.</strong> Listing costs 5 € per month."|'

probe "ein Eintrag verliert seinen englischen Text" \
      assets/config/listings.js \
      's|"text_en": "The open blueprint|"text_en_aus": "The open blueprint|'

# ⚠ DER DEUTSCHE TEXT IST DER SUCH-KORPUS. Wer ihn durch den englischen ersetzt,
# aendert unbemerkt, WAS GEFUNDEN WIRD — die Vektoren werden daraus gerechnet.
probe "der englische Text ersetzt den deutschen, statt daneben zu stehen" \
      assets/karte.js \
      's|return String(e.text \|\| "");|return String(e.text_en \|\| e.text \|\| "");|'

# ⚠ KEINE BACKTICKS IN DER BESCHREIBUNG. Beim ersten Lauf stand hier
# "`white-space: pre-line` kehrt zurueck" — die Shell hat den Inhalt als BEFEHL
# ausgefuehrt ("white-space:: command not found") und den Namen des Falls
# verstuemmelt. Der Fall lief trotzdem; sein Name in der Ausgabe war es nicht.
probe "die Regel pre-line kehrt an .hinweis zurück (feste Absätze brechen wieder)" \
      assets/style.css \
      's|.hinweis { color: var(--muted); font-size: .88rem; }|.hinweis { color: var(--muted); font-size: .88rem; white-space: pre-line; }|'

probe "eine Meldestelle fällt aus der pre-line-Liste" \
      assets/style.css \
      's|#suchNotiz, #notiz, #ebNotiz|#notiz, #ebNotiz|'

# Die drei Faelle unten fallen an WAECHTERN IM BROWSER — sie sind der Beleg
# dafuer, dass das Umschalten wirklich arbeitet und nicht nur im Quelltext steht.
probe "die Einträge werden beim Umschalten nicht neu gezeichnet" \
      assets/app.js \
      's|window.addEventListener("pt:sprache", function () {|window.addEventListener("pt:sprache-aus", function () {|'

probe "der Markenname wird dem Auto-Übersetzer überlassen" \
      assets/sprache.js \
      's|    ".brand",|    ".brand-aus",|'

probe "der Sprachknopf löst keine WAHL aus (der Riegel bliebe aus)" \
      assets/sprache.js \
      's|    try { localStorage.setItem(LS_WAHL, "1"); } catch (_e) {}||'

SEITEN="index.html knotenkarte.html auslieferungspruefer.html impressum.html datenschutz.html"
probe_mehr "die Versionsnummern verschwinden ganz aus allen Seiten" \
      "$SEITEN" \
      "sed -i 's|assets/\([A-Za-z0-9./_-]*\)?v=[0-9]*|assets/\1|g' $SEITEN"

# Die Gegenrichtung: stuende eine Option fest in der Seite, waere der Waechter
# oben von seinem Fehlen nicht zu unterscheiden.
# ⚠ EIN ATTRIBUT EINZUFUEGEN AENDERT NICHTS AN DEM, WAS DER WAECHTER SIEHT —
# beim ersten Nachstellen rutschte genau das durch (Kimhubs siebte Art). Der
# Waechter fragt, ob das `select` LEER ist; also muss eine Option hinein.
probe "eine Option steht fest im leeren Sprach-Wähler" \
      index.html \
      's|title="In welcher Sprache du sprichst"></select>|title="In welcher Sprache du sprichst"><option value="de-DE">Deutsch</option></select>|'

# ── Was am 2026-08-23 dazugekommen ist ──────────────────────────────────────
#
# Klaus' drei Bildschirmfotos („das Design sieht wirklich schrecklich aus"),
# der umbenannte Knopf, die drei neuen Eingänge und die zweite Meinung des
# Browsers. Jeder Wächter dazu bekommt hier seinen Fehler — sonst ist er nur
# ein grüner Haken.

# ⚠ DIESER FALL WAR BEIM ERSTEN LAUF BLIND, und der Grund ist lehrreich:
# er schob `display:grid` VOR die Zeile `display: block;` — und die spätere
# Deklaration gewinnt. Die Sabotage stand in der Datei und wirkte nicht.
# Sabotiert wird die WIRKSAME Zeile, nicht eine in ihrer Nachbarschaft.
probe "das Drei-Spalten-Raster kehrt in die Fundkarte zurück (Klaus' Bildschirmfotos)" \
      auslieferungspruefer.html \
      's|^  display: block;$|  display:grid; grid-template-columns:auto auto 1fr;|'

# ⚠ DIESER FALL IST DER GRUND FÜR DEN GANZEN BLOCK. Die kaputte Fassung war
# einen Monat lang im Depot, alle Proben waren grün, und aufgefallen ist es
# erst, weil ein Mensch hingesehen hat. Ein Wächter, der Lage misst statt
# CSS-Regeln zu lesen, fängt auch die nächste Variante davon.

probe "eine spätere Regel drückt den Klartext-Satz wieder auf Fliesstext-Größe" \
      auslieferungspruefer.html \
      's|^main.wrap > p, .pr-grenzen li|main.wrap p, .pr-grenzen li|'

probe "der Knopf heisst wieder Selbsttest — Klaus: das sagt mehr darueber aus, wie schlecht die App ist" \
      auslieferungspruefer.html \
      's|>Test-Seite laden</button>|>Selbsttest</button>|'

probe "die Test-Seite meldet sich nicht mehr als absichtlich fehlerhaft" \
      assets/pruefer-ui.js \
      's|und sie ist mit Absicht fehlerhaft. |&ENTFERNT_|; s|Das ist die mitgelieferte Test-Seite, und sie ist mit Absicht fehlerhaft. |Bestanden. |'

probe "die zweite Meinung des Browsers wird nicht mehr angezeigt" \
      assets/pruefer-ui.js \
      's|treffer = treffer.concat(zweite.treffer);||'

probe "der leere Kommentar wird nicht mehr erkannt (die schlimmste Umgehung kehrt zurück)" \
      assets/pruefer-browser.js \
      's|var leer = /<!--+>/g|var leer = /GIBTESNICHTIMTEXT/g|'

probe "meta-refresh und srcdoc bleiben wieder unbemerkt" \
      assets/pruefer-browser.js \
      's|if (!/\^refresh\$/i.test|if (!/GIBTESNICHT/i.test|; s|iframe\[srcdoc\]|iframe[srcdoc-gibtesnicht]|'

probe "die versteckten Wirte werden nicht mehr gemeldet" \
      assets/pruefer-browser.js \
      's|if (vomTextleser\[wirt\]) return;|return;|'

probe "die IBAN wird ohne Prüfziffer geglaubt (jede Bestellnummer wäre eine Kontonummer)" \
      assets/pruefer-formate.js \
      's|return rest === 1;|return true;|'

probe "die Impressum-Freistellung nimmt auch Schlüssel mit (eine Hintertür mit Dateinamen)" \
      assets/pruefer-formate.js \
      's|if (frei \&\& mu.k === "PERSONENBEZUG") continue;|if (frei) continue;|'

probe "die Freistellung geht über den WERT statt über den Pfad (jede Kopie schwiege mit)" \
      assets/pruefer-formate.js \
      's|var frei = istFreigestellt(pfad);|var frei = true;|'

probe "die Beleg-Felder werden nicht mehr gesucht — die 75 Rechnungen gingen wieder durch" \
      assets/pruefer-formate.js \
      's|GELD_FELD.test(zeile) \|\| BELEG_FELD.test(zeile) \|\| GELD_WERT.test(zeile)|false|'

probe "der Schlüssel in einem JSON-Feld wird wieder übersehen (das schliessende Anführungszeichen fehlt)" \
      assets/pruefer-formate.js \
      's|passwort\|password\|passwd)\\b\["'"'"'\]?\\s\*\[:=\]|passwort\|password\|passwd)\\b\\s*[:=]|'

probe "der gepackte PDF-Strom wird wieder unlesbar (Metadaten im ObjStm bleiben verborgen)" \
      assets/pruefer-formate.js \
      's|var bytes = ohneEndzeile(roheBytes);|var bytes = roheBytes;|'

probe "ein PDF ohne %PDF- gilt wieder als sauber statt als Fremdformat" \
      assets/pruefer-formate.js \
      's|if (roh.slice(0, 5) !== "%PDF-") {|if (false) {|'

probe "frühere Speicherstände im PDF werden nicht mehr gemeldet (Geschwärztes bleibt lesbar)" \
      assets/pruefer-formate.js \
      's|if (eofs > 1) {|if (false) {|'

# ⚠ PDFZK: Klaus' Word-PDF (2026-09-29): „þÿMicrosoft®", „MicrosoftÂ®" und
# „2 davon NICHT lesbar". Jeder Fall stellt einen der Fehler von damals wieder her.
# ⚠ Der erste Fall nimmt ZWEI Riegel: `>>` vor stream und das Weitersuchen hinter
# endstream decken einander. Nur einer weg war BLIND (gemessen 2026-09-29).
probe "PDFZK: das stream in endstream zählt wieder als Strom (Scheinströme, NICHT lesbar)" \
      assets/pruefer-formate.js \
      's#sre = />>\\s\*stream(?:\\r\\n|\\n|\\r)/g#sre = /stream\\r?\\n?/g#; s#sre.lastIndex = ende + 9;#sre.lastIndex = ende;#'

probe "PDFZK: der Filter wird wieder beim Nachbarn abgelesen" \
      assets/pruefer-formate.js \
      's#if (!filter || filter\[1\] !== "FlateDecode") continue;#if (!/\\/FlateDecode/.test(roh.slice(Math.max(0, sm.index - 400), sm.index))) continue;#'

probe "PDFZK: UTF-16 mit FE FF wird wieder als Latin-1 gelesen (þÿ)" \
      assets/pruefer-formate.js \
      's#if (b.length >= 2 \&\& b\[0\] === 0xFE \&\& b\[1\] === 0xFF) {#if (false) {#'

probe "PDFZK: XMP wird wieder als Latin-1 gelesen (Â®)" \
      assets/pruefer-formate.js \
      's#ohneEntities(utf8(bytesAus(#ohneEntities((#'

probe "PDFZK: Hex-Zeichenketten werden nicht mehr gelesen" \
      assets/pruefer-formate.js \
      's#return h \&\& text\[rest + 1\] !== "<" ? hexZk(h\[1\]) : null;#return null;#'

probe "PDFZK: Oktal-Escapes werden nicht mehr aufgelöst" \
      assets/pruefer-formate.js \
      's#aus += String.fromCharCode(parseInt(okt, 8) \& 255);#aus += okt;#'

probe "PDFZK: ein kaputter Strom reisst den Lauf wieder mit (unbehandelte Ablehnung)" \
      assets/pruefer-formate.js \
      's#w.write(bytes).catch(function () {}); w.close().catch(function () {});#w.write(bytes); w.close();#'

# ⚠ ANKER NACHGEZOGEN AM 2026-09-08. Er zeigte auf
# `if (ziel.origin !== location.origin) {` — die Zeile heisst seit einem Umbau
# `var fremd = ziel.origin !== location.origin;`. Der Fall aenderte also NICHTS
# und meldete sich als BLIND, waehrend der Waechter tadellos war. Gefunden im
# ersten vollen Lauf seit langem. **Wer eine Zeile aendert, auf die ein Fall
# zeigt, zieht den Fall mit** — die Regel steht in Kimhubs Verfassung, und sie
# gilt hier genauso.
probe "eine fremde Adresse wird doch geholt (der Prüfer petzt beim Prüfen)" \
      assets/pruefer-ui.js \
      's|var fremd = ziel.origin !== location.origin;|var fremd = false;|'

# ⚠ AUCH DIESER WAR BLIND: das Muster trug ein `\n`, und `sed` arbeitet
# ZEILENWEISE — es trifft nie. Steht als Falle schon im Kopf dieser Datei und
# hat trotzdem wieder zugeschlagen. Eine Zeile, ein Muster.
probe "ein Reiterwechsel lässt das Ergebnis des vorigen Eingangs stehen" \
      assets/pruefer-ui.js \
      's|      zeigeEingang(a);|      zeigeEingang(a); return;|'

# ⚠ DIE VERSIONSNUMMER IST HIER OFFEN, und das ist die Lehre aus dem Kopf dieser
# Datei — buchstaeblich: der Anker stand auf `?v=40`, die Datei laengst bei `?v=41`
# und heute bei `?v=43`. Ein `sed`, das nichts findet, aendert nichts, und der
# Smoke bleibt gruen: der Fall meldete sich als BLIND, obwohl der Waechter greift.
# **Zum vierten Mal dieselbe Falle in dieser Datei** — deshalb jetzt `[0-9]*`.
probe "die neuen Eingänge fehlen im Offline-Vorrat (offline wären es tote Reiter)" \
      sw.js \
      's|"assets/pruefer-formate.js?v=[0-9]*",||'

probe "die Test-Datei des Text-Eingangs verschwindet" \
      auslieferungspruefer.html \
      's|id="textBeispielKnopf"|id="textBeispielKnopf-GIBTS-NICHT"|'

# ── Klaus' zweiter Durchgang am 2026-08-23 (Abend) ──────────────────────────
#
# Er hat die Fassung am Tablet ausprobiert und den Bericht seiner eigenen
# Startseite geschickt: 34 Funde, davon 25 zweimal dieselbe Tatsache und 4 die
# eigene Domain. Dazu drei Sprach-Befunde. Jeder Wächter dazu bekommt hier
# seinen Fehler.

probe "gleiche Wirte bekommen wieder je eine eigene Karte (25 Karten fuer 2 Tatsachen)" \
      assets/pruefer-ui.js \
      's|var wirt = NACH_WIRT.indexOf(x.kennung) !== -1 ? wirtAus(x.satz) : null;|var wirt = null;|'

probe "die Zusammenfassung verschweigt die Stellen und nennt nur die Sachen" \
      assets/pruefer-ui.js \
      's|" an " + stellenZahl + " Stellen");|");|'

probe "der Wirt steht nicht mehr an der Karte (man sieht nicht, wen es betrifft)" \
      assets/pruefer-ui.js \
      's|w.setAttribute("data-wirt", g.wirt);|;|'

probe "der eigene Wirt wird nicht mehr vorbelegt (die eigene Domain gilt wieder als fremd)" \
      assets/pruefer-ui.js \
      's|erlaubt.value = location.host;|;|'

probe "ein fremder Abruf wird wieder pauschal abgelehnt statt versucht" \
      assets/pruefer-ui.js \
      's|var fremd = ziel.origin !== location.origin;|var fremd = ziel.origin !== location.origin; if (fremd) return;|'

probe "der gescheiterte Abruf sagt nicht mehr, dass die Sperre vom Browser kommt" \
      assets/pruefer-ui.js \
      's|"Sperre des Browsers, keine Entscheidung dieses Werkzeugs: " +|"" +|'

probe "der Konjunktiv kehrt in die Abruf-Meldung zurueck" \
      assets/pruefer-ui.js \
      's|satz = "Der Browser lässt diese Seite nicht lesen.|satz = "Der fremde Rechner erführe deine Adresse.|'

probe "die Beispiel-Adressen verschwinden (auf dem Tablet muss man abtippen)" \
      auslieferungspruefer.html \
      's|class="pr-bsp"|class="pr-bsp-GIBTS-NICHT"|g'

probe "Markup in einem <script> zaehlt wieder als Markup (Phantom-Funde kehren zurueck)" \
      assets/pruefer.js \
      's|if (tag === "script") {|if (false) {|'

probe "der Skript-Sprung steht wieder zu frueh (ein fremdes <script src> faellt heraus)" \
      assets/pruefer.js \
      's|      if (tag === "html") {|      if (tag === "script") { re.lastIndex = text.length; continue; }\n      if (tag === "html") {|'

probe "gewoehnliches Deutsch gilt wieder als Fuelltext" \
      assets/pruefer.js \
      's|"ihre firma",|"ihre firma", "dein name", "deine adresse",|'

probe "der Aufklapper wird wieder ein Flex-Container (die Leerzeichen fallen weg)" \
      auslieferungspruefer.html \
      's|^.pr-grenzen summary { cursor: pointer; font-weight: 600;$|.pr-grenzen summary { cursor: pointer; font-weight: 600; display:flex; align-items:center;|'


# ── Sichttest: die Regel vom 2026-08-21 ─────────────────────────────────────
#
# Sie ist der Grund, warum es diesen Block gibt: an dem Tag ging eine App ins
# Regal, die Klaus nie gesehen hatte, und ALLE Proben waren grün. Ein Wächter,
# der das künftig verhindern soll, muss selbst überprüft sein.

probe "ein eigener Eintrag verliert seinen Sichttest-Vermerk" \
      assets/config/listings.js \
      '0,/"sichttest": "vor-der-regel",/s///'

probe "ein erfundener Wert rutscht als Sichttest durch" \
      assets/config/listings.js \
      '0,/"sichttest": "vor-der-regel"/s//"sichttest": "schon-ok"/'

probe "„vor-der-regel\" wird rückwirkend auf etwas Neues gelegt" \
      assets/config/listings.js \
      's|"sichttest": "ausstehend"|"sichttest": "vor-der-regel"|'

probe "ein Sichttest liegt vor der Entstehung der App" \
      assets/config/listings.js \
      '0,/"sichttest": "vor-der-regel"/s//"sichttest": "2020-01-01"/'

probe "der wartende Sichttest kommt auf der Karte nicht mehr an" \
      assets/karte.js \
      's|sichttestHtml(e)||'

# Der Waechter dahinter liest die Positivliste `normEintrag` und fragt, ob JEDES
# Feld aus listings.js darin VORKOMMT. Er faengt damit das Vergessen — den Fall,
# der am 2026-08-15 `appUrl` und alle `eigenschaften` geloescht hat. Ein
# `if (false)` faengt er NICHT, denn das Wort steht dann immer noch da. Diese
# Grenze ist hier benannt statt umgangen: der Fall zielt auf das echte
# Entfernen, weil nur das der Fehler ist, den es in der Praxis gibt.
probe "das Studio wirft den Sichttest beim Veröffentlichen weg" \
      assets/studio.js \
      's|if (e.sichttest) o.sichttest = String(e.sichttest).trim();||'

# ══ DER LEUCHT-RAND STATT DES STANDARDSCHATTENS (Klaus 2026-09-08) ════════
#
# Sein Befund: „nicht mit dem Standardschatten … So sieht auch die Seite von
# anderen PWA-Shops aus, nämlich standardmäßig KI-generiert … Also mit dem
# kleinen schmalen Rand drum, der leuchtet, wenn die Maus draufgeht … dieser
# Schatten hinter dem Container weg."

probe "die Glas-Karte holt sich den Standardschatten zurück" \
      assets/style.css \
      's|  box-shadow: 0 2px 10px rgba(0, 0, 0, .18);|  box-shadow: var(--shadow);|'

probe "beim Anheben kommt der Schatten wieder mit" \
      assets/style.css \
      's|.listing:hover { --lift: -3px; box-shadow: var(--glow); }|.listing:hover { --lift: -3px; box-shadow: var(--shadow), var(--glow); }|'

probe "die Karte verliert jede Tiefe" \
      assets/style.css \
      's|  box-shadow: 0 2px 10px rgba(0, 0, 0, .18);|  box-shadow: none;|'

probe "der Rand wird gar nicht erst gezeichnet" \
      assets/style.css \
      's|  padding: 1.4px; background: var(--rand);|  padding: 1.4px;|'

# ⚠ OHNE DIE MASKE FUELLT DER VERLAUF DIE GANZE KARTE, statt nur den Ring
# stehen zu lassen — aus dem schmalen Rand wird eine bunte Flaeche. Das ist
# der Kern der Konstruktion, nicht eine Feinheit.
probe "die Maske faellt weg, der Rand wird zur Flaeche" \
      assets/style.css \
      's|  -webkit-mask-composite: xor;|  -webkit-mask-composite: source-over;|'

probe "der Ring wird so breit, dass er kein Rand mehr ist" \
      assets/style.css \
      's|  padding: 1.4px; background: var(--rand);|  padding: 9px; background: var(--rand);|'

probe "der Rand leuchtet bei Hover nicht mehr auf" \
      assets/style.css \
      's|  opacity: 1; animation: rand-dreht 14s linear infinite;|  animation: rand-dreht 14s linear infinite;|'

# ⚠ EIN RAND, DER ERST BEI HOVER ERSCHEINT, laesst die Karte im Ruhezustand
# genauso nackt wie vorher — und genau das war die Beanstandung.
probe "der Rand ist ruhend unsichtbar" \
      assets/style.css \
      's|  pointer-events: none; opacity: .42; transition: opacity .22s;|  pointer-events: none; opacity: 0; transition: opacity .22s;|'

# ⚠ DIE DREHUNG IST EINE LEISTUNGS-ZUSAGE: 28 Karten, und ein dauerhaft
# rotierender `conic-gradient` je Karte waeren 28 Dauerlasten.
probe "die Drehung laeuft dauernd statt nur bei Hover" \
      assets/style.css \
      's|  pointer-events: none; opacity: .42; transition: opacity .22s;|  pointer-events: none; opacity: .42; animation: rand-dreht 14s linear infinite; transition: opacity .22s;|'

probe "--rot ist nicht mehr als Winkel angemeldet — die Drehung springt" \
      assets/style.css \
      's|@property --rot { syntax: "<angle>"; initial-value: 0deg; inherits: false; }||'

probe "wer weniger Bewegung will, bekommt die Drehung trotzdem" \
      assets/style.css \
      's|  .glass:hover::before, .glass:focus-within::before { animation: none; }||'

probe "ein Thema verliert seinen eigenen Rand-Verlauf" \
      assets/style.css \
      "s|            #ff8a3d, #c58cff, #38d6d6, #ff8a3d, #ffb27a, #ff8a3d);|            #ff8a3d);|"

# ══ DER FESTE PLATZ FÜR DIE MYCEL-BLASE (Klaus 2026-09-08) ════════════════
#
# „Setz sie bitte an eine feste Stelle in der Navileiste oben … denn es taucht
#  immer wieder auf, dass diese Mycelkarte irgendwo was abdeckt."

probe "die Kopfleiste bietet keinen Platz mehr an (die Blase bleibt in der Ecke)" \
      index.html \
      's|<span class="mycel-platz" data-sbkim-mycel-platz></span>||'

# ⚠ IN `nav.top` BEKAEME DIE BLASE DIE NEIGUNG DER LINKS MIT — einen Effekt,
# der ihr eigenes Ziehen stoert. Der Fall verschiebt den Platz genau dorthin.
# ⚠ `sed` LIEST ZEILENWEISE und kann `\n` im SUCHMUSTER nicht treffen. Der Fall
# stand mit einem mehrzeiligen Muster da, aenderte nie etwas und meldete sich als
# BLIND — der Waechter war die ganze Zeit in Ordnung. Ein `sed`, das nichts
# findet, sieht aus wie eine bestandene Pruefung. Deshalb `probe_befehl`.
probe_befehl "der Platz rutscht in nav.top (die Blase bekommt die Link-Neigung)" \
      index.html \
      'python3 - <<PY
import pathlib
p = pathlib.Path("index.html"); s = p.read_text(encoding="utf-8")
platz = "    <span class=\\"mycel-platz\\" data-sbkim-mycel-platz></span>\\n"
nav = "    <nav class=\\"top\\">"
assert platz in s and nav in s
s = s.replace(platz, "", 1)
s = s.replace(nav, nav.rstrip() + platz.strip(), 1)
p.write_text(s, encoding="utf-8")
PY'

probe "die Modul-Kopie kennt den Platz nicht mehr" \
      sbkim/23_rendezvous_ui.js \
      's|var ANKER_WAHL = "\[data-sbkim-mycel-platz\]";|var ANKER_WAHL = "[data-gibt-es-nicht]";|'

probe "der Weg zurueck in die Leiste faellt aus der Kopie" \
      sbkim/23_rendezvous_ui.js \
      's|dockBtn.setAttribute("data-sbkim-andocken", "");||'

# ══ DER AUSLIEFERUNGSPRÜFER ALS EIGENER KNOTEN (Klaus 2026-09-08) ══════════
#
# „Beide Tools, Company und das Ausliefer-Tool, sollen als eigenständige Knoten
# agieren … mit Zelle und auch dem Siegel."
#
# ⚠ JEDER FALL HIER IST EINZELN VON HAND NACHGESTELLT, und die rote Zeile trägt
# jeweils den Namen SEINER Zusicherung — nicht den eines Werkzeugs. Zwei Fälle
# brauchten dafür `probe_befehl`: eine vertauschte Reihenfolge lässt sich mit
# einem `sed` nicht einbauen, und ein `sed`, das nichts findet, ändert nichts —
# der Smoke bliebe grün, was wie eine bestandene Prüfung aussieht.

probe "ein Pflicht-Modul faellt aus der Pruefer-Kette" \
      assets/pruefer-sbkim-init.js \
      '/"sbkim\/07_apoptose.js"/d'

probe "Modul 17 faellt aus der Pruefer-Kette" \
      assets/pruefer-sbkim-init.js \
      '/"sbkim\/17_floating_widget.js"/d'

# ⚠ FALLE 1 aus Sages LEHREN § 4 — und sie zaehlt hier doppelt: seit dem
# 2026-09-08 stehen ZWEI Knoten auf dieser Adresse.
probe "die Schublade faellt aus dem Kopf des Pruefers" \
      auslieferungspruefer.html \
      's|<script>window.SBKIM_DB_SUFFIX = "auslieferungspruefer";</script>||'

probe "der Pruefer nimmt die Schublade des Marktplatzes" \
      auslieferungspruefer.html \
      's|window.SBKIM_DB_SUFFIX = "auslieferungspruefer"|window.SBKIM_DB_SUFFIX = "toolpoint"|'

probe "die Schublade faellt aus dem Kopf des Marktplatzes" \
      index.html \
      's|<script>window.SBKIM_DB_SUFFIX = "pwatoolpoint";</script>||'

probe "der Suffix in der Pruefer-Konfig laeuft vom Kopf auseinander" \
      assets/config/pruefer-netz.js \
      's|dbSuffix: "auslieferungspruefer"|dbSuffix: "pruefer"|'

# ⚠ FALLE 2 — als klassisches Skript laeuft 05b NIE, und dann leuchtet das
# Siegel, waehrend der Raum tot ist. Der Fall wird DOPPELT gefangen: vom Waechter
# auf das Paar `["module", …]` und von der Browser-Probe, die den echten
# SyntaxError sieht. Zwei Wege zu demselben Befund sind hier kein Luxus — der
# erste sagt, WAS falsch ist, der zweite, dass es wirklich bricht.
probe "Modul 05b laeuft als klassisches Skript" \
      assets/pruefer-sbkim-init.js \
      's|\["module", "sbkim/05b_nostr_relay.js"\]|["",       "sbkim/05b_nostr_relay.js"]|'

# ⚠ FALLE 3 — Modul 17 legt die Anker an, in die sich Waechter und Siegel haengen.
# Als ECHTE Vertauschung, nicht als Loeschung: sonst maesse der Fall dasselbe wie
# „Modul 17 faellt aus der Kette" und die Reihenfolge waere ungeprueft.
probe_befehl "Modul 17 rutscht in der Kette hinter 15 und 16" \
      assets/pruefer-sbkim-init.js \
      'python3 - <<PY
import pathlib
p = pathlib.Path("assets/pruefer-sbkim-init.js"); s = p.read_text(encoding="utf-8")
a = """    ["",       "sbkim/17_floating_widget.js"],
    ["",       "sbkim/07_apoptose.js"],
    ["",       "sbkim/15_membran.js"],
    ["",       "sbkim/16_siegel.js"],
"""
b = """    ["",       "sbkim/07_apoptose.js"],
    ["",       "sbkim/15_membran.js"],
    ["",       "sbkim/16_siegel.js"],
    ["",       "sbkim/17_floating_widget.js"],
"""
p.write_text(s.replace(a, b, 1), encoding="utf-8")
PY'

probe "Modul 17 wird geladen, aber nie gestartet" \
      assets/pruefer-sbkim-init.js \
      's|window.SbkimWidget.init({|window.SbkimWidgetAus \&\& window.SbkimWidgetAus.initAus({|'

# Die Reihenfolge des STARTENS ist dieselbe Zusicherung wie die des Ladens.
probe_befehl "Modul 17 wird NACH der Membran gestartet" \
      assets/pruefer-sbkim-init.js \
      'python3 - <<PY
import pathlib
p = pathlib.Path("assets/pruefer-sbkim-init.js"); s = p.read_text(encoding="utf-8")
i = s.index("      if (window.SbkimWidget && window.SbkimWidget.init) {")
j = s.index("      if (window.SbkimMembrane) {")
k = s.index("      if (window.SbkimSiegel) {")
p.write_text(s[:i] + s[j:k] + s[i:j] + s[k:], encoding="utf-8")
PY'

# Die Ladezeit-Zusicherung: dreizehn <script>-Zeilen im Dokument kosten messbar.
probe "ein Modul haengt blockierend in der Pruefer-Seite" \
      auslieferungspruefer.html \
      's|</body>|<script src="sbkim/04_match.js"></script></body>|'

probe "die Kette laeuft nicht mehr fail-soft" \
      assets/pruefer-sbkim-init.js \
      's|s.onload = s.onerror = function|s.onload = function|'

probe "das Wappen-Band traegt den Namen des Marktplatzes" \
      assets/pruefer-sbkim-init.js \
      's|ribbonText: "AUSLIEFERUNGSPRÜFER"|ribbonText: "PWA TOOLPOINT"|'

# ⚠ DIE BESCHREIBUNG IST KEINE ZIERDE — Modul 03 rechnet daraus den Vektor.
probe_befehl "die Beschreibung schrumpft auf einen Satz" \
      assets/config/pruefer-netz.js \
      'python3 - <<PY
import pathlib
p = pathlib.Path("assets/config/pruefer-netz.js"); s = p.read_text(encoding="utf-8")
i = s.index("  beschreibung:"); j = s.index("  stichworte:")
p.write_text(s[:i] + "  beschreibung: \"Ein Werkzeug fuer Seiten.\",\n\n" + s[j:], encoding="utf-8")
PY'

# ⚠ ANKER NACHGEZOGEN 2026-09-14. Er zeigte auf „Prüft, was eine …" — den Satz
# von vor dem 2026-09-10, als die Beschreibung neu geschrieben wurde. Der Fall
# war seitdem inert und meldete sich als „BLIND", weil `probe` einen toten Anker
# nicht erkennen konnte.
# ⚠ UND DER ERSTE ERSATZ FING AUF EINER FREMDEN ZUSICHERUNG. „Prüfer" ohne
# Umlaut warf zuerst den Waechter „nennt den eigenen Knoten beim Namen" um —
# rot war er, aber er bewies etwas anderes. Sabotiert wird jetzt ein Satz aus
# der MITTE, der keinen anderen Waechter beruehrt; die rote Zeile traegt den
# Namen dieser Zusicherung.
probe "die Beschreibung laeuft zwischen Konfig und Wizard auseinander" \
      assets/pruefer-siegel-inhalt.js \
      's|Er prüft, was eine Internetseite wirk|Er sieht nach, was eine Internetseite wirk|'

# ⚠ ANKER NACHGEZOGEN 2026-09-14 (A18): der Wizard-Code ist aus
# `pruefer-siegel-inhalt.js` ausgezogen; dort steht nur noch die Identitaet.
probe "der Identitaets-Wechsler faellt aus dem Pruefer-Wizard" \
      assets/pruefer-sbkim-andock-wizard.js \
      's|<select id="sbwiz-idsel"|<select id="sbwiz-idsel-aus"|'

# Zwei Fassungen desselben Wizards auf EINER Adresse waeren zwei Generationen.
probe "der Code des Pruefer-Wizards wandert vom Marktplatz ab" \
      assets/pruefer-sbkim-andock-wizard.js \
      's|var lastSpore = null;|var lastSpore = null; var abweichung = 1;|'

probe "das Geraetenamen-Feld wird nicht mehr ins Panel gehaengt" \
      assets/pruefer-sbkim-init.js \
      's|feld.setAttribute("data-sbkim-geraetename", "1");|feld.setAttribute("data-sbkim-alt", "1");|'

# ⚠ FALLE 4 AUF DEM ANDEREN WEG. Die Module stehen absichtlich NICHT im
# Installations-Vorrat (der Waechter darueber verbietet es, weil das mit dem
# ersten Bild konkurriert). Erfuellt wird Falle 4 durch den Vorrat-zuerst-Zweig.
# Faellt `ablegen` dort heraus, ist sie offen — und niemand saehe es, weil eine
# Seite ohne Lampen aussieht wie eine Seite ohne Netz.
probe "ablegen faellt aus dem Vorrat-zuerst-Zweig (Falle 4 offen)" \
      sw.js \
      's|var netz = fetch(req).then(function (res) { return ablegen(req, res); })|var netz = fetch(req).then(function (res) { return res; })|'

probe "der Klebstoff des Pruefers faellt aus dem Installations-Vorrat" \
      sw.js \
      '/"assets\/pruefer-sbkim-init.js?v=/d'

# Zwei Listen derselben Poststellen laufen auseinander.
probe "die Relais werden abgeschrieben statt abgelesen" \
      assets/config/pruefer-netz.js \
      's|return (window.PT_NETZ \&\& window.PT_NETZ.relais) \|\| \[\];|return ["wss://relay.damus.io"];|'

# ══ DIE SEITE SAGT SELBST, WO SIE ZU HAUSE IST (Klaus 2026-09-11) ══════════
#
# Sein Bericht ueber eine GESPEICHERTE Fassung von family-projekt.de meldete
# neun Stellen auf `family-projekt.de` — also die Seite, die sich selbst als
# fremd meldet. `location.host` traegt nur, solange man die Seite prueft, auf
# der man steht.

probe "die eigene Adresse der gepruefen Datei wird nicht mehr erkannt" \
      assets/pruefer-ui.js \
      's|var eigen = eigeneAdresse(text);|var eigen = null;|'

probe "sie wird erkannt, aber STILL — ohne den Satz, dass es geschehen ist" \
      assets/pruefer-ui.js \
      's|hinweise.push("Die Datei nennt sich selbst " + eigen.wirt|hinweise.push("" + ("" \&\& eigen.wirt|'

# ⚠ `cid:` IST KEIN FREMDER RECHNER, sondern ein Verweis IM SELBEN Behaelter —
# Chrome schreibt das beim Herunterladen einer Seite als `.mhtml`, und genau
# diesen Weg nimmt das Tablet. Der Koeder traegt seit dem 2026-09-11 eine
# solche Zeile; ohne `cid` in HARMLOS sind es ZWEI fremde Adressen statt einer,
# und „jede Befundart genau einmal" faellt um.
probe "cid: gilt wieder als fremder Rechner" \
      assets/pruefer.js \
      's|"javascript", "cid"\]|"javascript"]|'

# ══ DER KNOTEN IM ECHTEN BROWSER ═══════════════════════════════════════════
#
# Alles darueber ist Text: die Kette nennt die richtigen Dateien, die Reihenfolge
# stimmt, die Dateien liegen da. Ob daraus im Browser ein Knoten wird, sagt keine
# Textsuche — `tests/smoke_pruefer.mjs` startet dafuer einen echten Chromium.

probe "die Kette laedt gar nichts mehr" \
      assets/pruefer-sbkim-init.js \
      's|s.src = KANON\[i\]\[1\];|s.src = "";|'

probe "das Verbinden-Fenster wird nie gemountet — die Kennung ist unerreichbar" \
      assets/pruefer-sbkim-init.js \
      's|window.SbkimRendezvousUI.init({ nodeName: anzeigeName(), dbSuffix: NETZ.dbSuffix });|void 0;|'

# ⚠ ZWEI BROWSER-WAECHTER HABEN KEINEN EIGENEN FALL, und das ist gemessen, nicht
# uebersehen:
#
#   „die App oeffnet ihre EIGENE Schublade" — gefangen vom Fall „der Pruefer nimmt
#   die Schublade des Marktplatzes" weiter oben (nachgestellt: die rote Zeile
#   nennt `sbkim_toolpoint`). Ein zweiter Fall auf demselben Weg messte nicht
#   doppelt, er kostete nur doppelt.
#
#   „der geteilte Topf `sbkim` bleibt zu" — ihn zu OEFFNEN ist mit einem Eingriff
#   nicht zu erreichen, und der Grund ist eine gute Nachricht: die Schublade ist
#   ZWEIFACH geschuetzt. Der Wert im <head> setzt den Vorgabe-Namen von Modul 01,
#   und `init({dbSuffix})` zeigt zusaetzlich dorthin. NACHGESTELLT: laesst man
#   `init()` absichtlich `toolpoint` oeffnen, WEIST MODUL 01 DAS AB (der
#   Vorgabe-Name aus dem Kopf steht schon), `starten()` faengt den Fehler, und die
#   Schublade bleibt die richtige. Der Waechter ist damit eine MESSUNG des
#   Befundes vom 2026-08-16, kein Riegel mit eigenem Fall — und dass er nicht zu
#   kippen ist, ist selbst das Ergebnis.

probe_befehl "netz.js steht hinter pruefer-netz.js — der Relais-Leser liest ins Leere" \
      auslieferungspruefer.html \
      'python3 - <<PY
import pathlib, re
# WARNUNG: DIE VERSIONSNUMMER BLEIBT OFFEN. Diese Zeilen standen einmal fest
# auf ?v=43 — und wurden mit dem Bump auf v44 (2026-09-09) blind: das
# Vertauschen fand nichts mehr, aenderte nichts, und der gruene Smoke sah aus
# wie eine bestandene Pruefung. Genau davor warnt der Kopf dieser Datei, und es
# ist trotzdem wieder passiert. Jetzt wird die Reihenfolge GESUCHT statt
# getippt.
p = pathlib.Path("auslieferungspruefer.html"); s = p.read_text(encoding="utf-8")
muster = r"( *<script src=.assets/config/netz\.js[^>]*></script>\n)( *<script src=.assets/config/pruefer-netz\.js[^>]*></script>\n)"
m = re.search(muster, s)
if not m: raise SystemExit("ANKER NICHT GEFUNDEN")
p.write_text(s.replace(m.group(0), m.group(2) + m.group(1), 1), encoding="utf-8")
PY'

# ── Die abgelegte Spore (2026-09-09) ─────────────────────────────────────────
# Die erste echte Spore kam an dem Tag, an dem zwei Knoten auf einer Adresse
# standen — und sie war auf der FALSCHEN Seite erzeugt. Die vier Faelle unten
# saegen genau an dem, was die Waechter messen: die Haelfte des Schluessels,
# den Namen des Knotens, seinen Endpunkt und das Duerfen des Schluessels.
probe "ein privater Schluessel ist in die Spore gerutscht" \
      sbkim/spore.json \
      's/"kty": *"OKP"/"d": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "kty": "OKP"/'

probe "die Spore gehoert dem Pruefer, liegt aber am Platz des Marktplatzes" \
      sbkim/spore.json \
      's/"nodeName": *"PWA Toolpoint"/"nodeName": "Auslieferungspruefer"/'

probe "der Endpunkt der Spore zeigt auf die Pruefer-Seite" \
      sbkim/spore.json \
      's#"endpoint": *"https://pwa-toolpoint.de/"#"endpoint": "https://pwa-toolpoint.de/auslieferungspruefer.html"#'

# ⚠ DIESER FALL BRAUCHT python, KEIN sed. `key_ops` steht ueber DREI Zeilen
# ("key_ops": [ / "verify" / ]), und ein sed-Suchmuster mit \n trifft nie etwas —
# der Fall aenderte dann gar nichts und meldete sich als bestanden. Genau so ist
# er beim Schreiben am 2026-09-09 zuerst durchgerutscht: die anderen drei Faelle
# schlugen an, dieser blieb still, und still sieht aus wie gruen.
probe_befehl "der abgelegte Schluessel darf auch signieren, nicht nur pruefen" \
      sbkim/spore.json \
      'python3 - <<PY
import json, pathlib
p = pathlib.Path("sbkim/spore.json")
d = json.loads(p.read_text(encoding="utf-8"))
d["publicKey"]["key_ops"] = ["verify", "sign"]
p.write_text(json.dumps(d, indent=2, ensure_ascii=False), encoding="utf-8")
PY'

# ── Der Mail-Eingang (2026-09-09) ────────────────────────────────────────────
#
# Klaus: „E-Mail-Adressen werden eingepflegt … es wird im Prinzip nur geprüfter
# Inhalt, inklusive der Links … auch Befehle, die an eine KI gehen könnten."
#
# ⚠ ZWEI RICHTUNGEN, IMMER. Bei den drei Maschen (Bankwechsel, Zugangsdaten,
# Druck) ist die gefährlichere Sabotage nicht „meldet nichts mehr", sondern
# „meldet auch mit nur EINEM Anzeichen" — daraus wird die Warnung, die man nicht
# mehr los wird, und die schaltet der Nutzer ab.
#
# Auf STABILE Anker gezielt, nie auf eine Versionsnummer — siehe die Warnung
# ganz oben in dieser Datei.

probe "die Tarnung wird nicht mehr gemeldet (sichtbarer Text ≠ Ziel)" \
      assets/pruefer-mail.js \
      's|if (kern(genannt) === kern(zielWirt)) continue;|if (true) continue;|'

probe "www.x und x gelten wieder als verschiedene Rechner (jeder Link wäre Tarnung)" \
      assets/pruefer-mail.js \
      's|return letzteZwei;|return String(wirt).toLowerCase();|'

probe "der Benutzerteil vor dem @ wird wieder übersehen (der älteste Trick im Buch)" \
      assets/pruefer-mail.js \
      's|if (w.benutzerteil \&\& /\[A-Za-z\]/.test(w.benutzerteil)) {|if (false) {|'

probe "die Kürzel-Liste ist leer — bit.ly verbirgt sein Ziel wieder unbemerkt" \
      assets/pruefer-mail.js \
      's|var KUERZEL = \["bit.ly"|var KUERZEL = ["gibtesnicht-4711.test"|'

probe "das Zählpixel gilt nicht mehr als winzig" \
      assets/pruefer-mail.js \
      's|if (!winzig) continue;|continue;|'

probe "die Endungen, die etwas ausführen, sind vergessen (.exe wäre harmlos)" \
      assets/pruefer-mail.js \
      's|"exe", "scr", "com", "pif"|"gibtsnicht1", "gibtsnicht2", "gibtsnicht3", "gibtsnicht4"|'

probe "die doppelte Endung wird nicht mehr erkannt (rechnung.pdf.exe sähe aus wie eine PDF)" \
      assets/pruefer-mail.js \
      's|var harmlosAussehend = \["pdf",|var harmlosAussehend = ["gibtsnicht",|'

probe "die Nutzlast des Anhangs landet doch im Prüftext (drei Megabyte Schadcode als Text)" \
      assets/pruefer-mail.js \
      's|if (vorabAnhang) {|if (false) {|'

probe "„ignoriere alle vorherigen Anweisungen“ wird nicht mehr gefunden" \
      assets/pruefer-mail.js \
      's|re: /ignorier(?:e\|en\|t)?|re: /GIBTESNICHTIMTEXT4711|'

probe "die Anrede an einen Assistenten wird nicht mehr gefunden" \
      assets/pruefer-mail.js \
      's|(?:claude\|chatgpt\|gpt-?4o?\|copilot\|gemini\|assistant\|assistent)|(?:gibtesnicht4711)|'

probe "versteckter Text wird ab dem ersten Zeichen gemeldet (jede Vorschauzeile feuert)" \
      assets/pruefer-mail.js \
      's|var VERSTECKT_AB = 120;|var VERSTECKT_AB = 0;|'

probe "versteckter Text wird gar nicht mehr gemeldet" \
      assets/pruefer-mail.js \
      's|if (!unsichtbar) continue;|continue;|'

probe "die unsichtbaren Zeichen werden nicht mehr gesucht" \
      assets/pruefer-mail.js \
      's|var UNSICHTBAR = .*|var UNSICHTBAR = /[\\uE000]/;|'

probe "der Bankwechsel wird auch ohne gültige Kontonummer gemeldet" \
      assets/pruefer-mail.js \
      's|      if (ibanDa) {|      if (true) {|'

probe "die Zugangsdaten-Masche meldet schon bei EINEM Anzeichen" \
      assets/pruefer-mail.js \
      's|if (zm \&\& AUFFORDERUNG.test(text) \&\& hatLink) {|if (zm) {|'

probe "die Druck-Masche meldet schon bei EINEM Anzeichen" \
      assets/pruefer-mail.js \
      's|if (fm2 \&\& FOLGE_WORT.test(text)) {|if (fm2) {|'

probe "der Absender wird wieder an der ERSTEN spitzen Klammer gelesen (die Fälschung gilt als Wahrheit)" \
      assets/pruefer-mail.js \
      's|var letzteKlammer = von.lastIndexOf("<");|var letzteKlammer = von.indexOf("<");|'

probe "`dmarc=none` gilt wieder als durchgefallen (auf halbem Netz feuert es)" \
      assets/pruefer-mail.js \
      's|(fail\|softfail\|permerror\|temperror)|(fail\|softfail\|permerror\|temperror\|none)|'

probe "fehlende Kopfzeilen werden verschwiegen (weniger geprüft, aber still)" \
      assets/pruefer-mail.js \
      's|if (!kopfText) {|if (false) {|'

probe "quoted-printable wird nicht mehr entpackt (die umbrochene Adresse bleibt halb)" \
      assets/pruefer-mail.js \
      's|if (kodierung.indexOf("quoted-printable") === 0)|if (false \&\& kodierung.indexOf("quoted-printable") === 0)|'

probe "eine als Anhang weitergeleitete Mail wird wieder beiseitegelegt statt ausgepackt" \
      assets/pruefer-mail.js \
      's|var istMailTeil = .*|var istMailTeil = false;|'

probe "die Weiterleitung im Text wird nicht mehr benannt (geurteilt würde über die falsche Mail)" \
      assets/pruefer-mail.js \
      's|weitergeleitete nachricht\|forwarded message|GIBTESNICHT4711|'

probe "die Schlüssel-Suche fällt still aus, statt sich zu melden" \
      assets/pruefer-mail.js \
      's|hinweise.push("Die Schlüssel-Suche stand nicht zur Verfügung " +|if (false) hinweise.push("Die Schlüssel-Suche stand nicht zur Verfügung " +|'

probe "auch der Personenbezug wird übernommen (jede Mailadresse in jeder Mail feuert)" \
      assets/pruefer-mail.js \
      's|if (x.kennung === "SCHLUESSEL") treffer.push(x);|treffer.push(x);|'

probe "das Modul behauptet eine zweite Fassung, die es nicht gibt" \
      assets/pruefer-mail.js \
      's|zwilling: false|zwilling: true|'

# ⚠ DIESER FALL IST DER TEUERSTE. Ohne die Grenzen im Mailadress-Muster friert
# die Seite bei einer langen HTML-Zeile ein — gemessen 23 s bei 200 000 Zeichen.
probe "das Mailadress-Muster verliert seine Grenzen (die Seite friert bei langer Post ein)" \
      assets/pruefer-formate.js \
      's|\[A-Za-z0-9._%+\\-\]{1,64}@\[A-Za-z0-9.\\-\]{1,255}|[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+|'

probe "der Mail-Reiter fällt aus der Liste der Eingänge (ein Knopf, der nichts tut)" \
      assets/pruefer-ui.js \
      's|"adresse", "mail", "datei"\];|"adresse", "datei"];|'

probe "die Bedienung gibt die EINGABE weiter statt des geprüften Textes (Zeile und Nummer passen nicht mehr)" \
      assets/pruefer-ui.js \
      's|, r.text, |, inhalt, |g'

probe "die Test-Mail meldet sich nicht mehr als absichtlich bösartig" \
      assets/pruefer-ui.js \
      's|und sie ist mit Absicht " +|und sie ist ganz " +|'

probe "der Satz „keine Virenprüfung“ verschwindet von der Seite" \
      auslieferungspruefer.html \
      's|<strong>Das ist keine Virenprüfung.</strong>|<strong>Rundum geprüft.</strong>|'

# ⚠ DIE WOERTERBUCH-HAELFTE (2026-09-26). Die zwei Faelle darueber waren
# blind, weil der Browser-Waechter den Text NACH sprache.js liest. Bewacht
# werden jetzt Datei UND Woerterbuch (tests/smoke_knoten.mjs) — und dazu
# gehoeren diese beiden Faelle, sonst waere die zweite Haelfte eine Behauptung.
probe "WOERTERBUCH: der englische Knopf heisst wieder Selbsttest" \
      assets/i18n-pruefer.js \
      's|"pr_17": "Load the test page",|"pr_17": "Selbsttest",|'

probe "WOERTERBUCH: der englische Eintrag verspricht wieder eine Virenpruefung" \
      assets/i18n-pruefer.js \
      's|<strong>This is not a virus scan.</strong>|<strong>Fully scanned.</strong>|'

probe "der Mail-Eingang fällt aus dem Offline-Vorrat" \
      sw.js \
      's|"assets/pruefer-mail.js?v=|"assets/pruefer-mail-GIBTS-NICHT.js?v=|'

probe "die Seite lädt die Mail-Prüfung nicht mehr (der fünfte Reiter wäre tot)" \
      auslieferungspruefer.html \
      's|<script src="assets/pruefer-mail.js|<script src="assets/pruefer-mail-FEHLT.js|'

# ⚠ UND DER NETZ-WÄCHTER BRAUCHT SEINEN EIGENEN FEHLER. Sonst misst „nichts aus
# dem Netz geholt" vielleicht nur, dass der Zuhörer gar nicht zuhört.
probe_befehl "die Mail-Prüfung holt doch etwas aus dem Netz nach" \
      assets/pruefer-ui.js \
      "sed -i 's|var r = window.PrueferMail.pruefeMail(inhalt);|new Image().src = \"https://zaehler-4711.test/p.gif\"; var r = window.PrueferMail.pruefeMail(inhalt);|' assets/pruefer-ui.js"

# ── Die Spore des Pruefers (2026-09-09) ──────────────────────────────────────
# Dieselben vier Schnitte am zweiten Knoten — plus der eine, den es beim ersten
# nicht geben konnte: dass beide Sporen in Wahrheit DERSELBE Knoten sind.
probe "ein privater Schluessel ist in die Pruefer-Spore gerutscht" \
      sbkim/pruefer-spore.json \
      's/"kty": *"OKP"/"d": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "kty": "OKP"/'

probe "die Pruefer-Spore traegt den Namen des Marktplatzes" \
      sbkim/pruefer-spore.json \
      's/"nodeName": *"Auslieferungsprüfer"/"nodeName": "PWA Toolpoint"/'

probe "der Endpunkt der Pruefer-Spore zeigt auf die Wurzel" \
      sbkim/pruefer-spore.json \
      's#"endpoint": *"https://pwa-toolpoint.de/auslieferungspruefer.html"#"endpoint": "https://pwa-toolpoint.de/"#'

# ⚠ WIE BEIM MARKTPLATZ: `key_ops` steht ueber DREI Zeilen, ein sed mit \n
# traefe nie etwas und der Fall meldete sich still als bestanden.
probe_befehl "der Schluessel des Pruefers darf auch signieren" \
      sbkim/pruefer-spore.json \
      'python3 - <<PY
import json, pathlib
p = pathlib.Path("sbkim/pruefer-spore.json")
d = json.loads(p.read_text(encoding="utf-8"))
d["publicKey"]["key_ops"] = ["verify", "sign"]
p.write_text(json.dumps(d, indent=2, ensure_ascii=False), encoding="utf-8")
PY'

# ⚠ DER FALL, DEN ES BEIM EINEN KNOTEN NICHT GAB. Zwei Dateien, die daliegen,
# sehen nach zwei Knoten aus — auch wenn beide aus demselben Browser-Zustand
# stammen und denselben Schluessel tragen. Ein Waechter auf „beide sind da"
# waere dafuer blind; genau diese Vermischung ist der Grund fuer die eigene
# Schublade im <head>.
probe_befehl "beide Sporen tragen in Wahrheit DENSELBEN Knoten" \
      sbkim/pruefer-spore.json \
      'python3 - <<PY
import json, pathlib
p = pathlib.Path("sbkim/pruefer-spore.json")
m = json.loads(pathlib.Path("sbkim/spore.json").read_text(encoding="utf-8"))
d = json.loads(p.read_text(encoding="utf-8"))
d["id"] = m["id"]
d["publicKey"] = m["publicKey"]
p.write_text(json.dumps(d, indent=2, ensure_ascii=False), encoding="utf-8")
PY'


# ── Umgebrochene Kopfzeilen und die gespeicherte Seite (2026-09-10) ──────────
#
# Gefunden nicht von einer Probe, sondern durch Klaus' Frage, wie man den
# Quelltext einer Seite ausliest. `kopfWert` endete auf `$` mit `m`-Flag — das
# ist das Ende JEDER Zeile. Eine Mail, die ihren Content-Type umbricht (Outlook,
# Thunderbird, und jede von Chrome gespeicherte .mhtml), verlor damit ihre
# `boundary`, wurde nicht zerlegt und meldete STILL gar nichts.
#
# WARNUNG: DIE ERSTEN DREI FAELLE LIEFEN ZUERST MIT `sed` UND TRAFEN NICHTS.
# Der Ausdruck steht in einer einfach gequoteten Shell-Zeichenkette und muss
# durch drei Ebenen von Fluchten — Shell, sed-BRE, JavaScript-Regex. Was dabei
# ankam, passte auf keine Zeile: der Fall aenderte gar nichts und meldete sich
# als BLIND, obwohl der Waechter tadellos war. Mit python gibt es EINE Ebene.
# Dieselbe Lehre wie beim `key_ops`-Fall vom 2026-09-09, nur andersherum.

probe_befehl "der Kopf-Leser hoert wieder am ersten Zeilenumbruch auf (umgebrochene Mails melden nichts)" \
      assets/pruefer-mail.js \
      'python3 - <<PY
import pathlib
bs = chr(92)
p = pathlib.Path("assets/pruefer-mail.js")
z = p.read_text(encoding="utf-8").split(chr(10))
k = [i for i, l in enumerate(z) if "+ maskiere(name) +" in l]
if len(k) != 1: raise SystemExit("ANKER NICHT GEFUNDEN")
z[k[0]] = "    var re = new RegExp(" + chr(34) + "^" + chr(34) + " + maskiere(name) + " + chr(34) + "[ " + bs+bs + "t]*:[ " + bs+bs + "t]*([^" + bs+bs + "n]*)" + chr(34) + ", " + chr(34) + "im" + chr(34) + ");"
p.write_text(chr(10).join(z), encoding="utf-8")
PY'

probe_befehl "der Kopf-Leser greift bis zum Ende des Kopfes (eine fremde Zeile liefert die Grenze)" \
      assets/pruefer-mail.js \
      'python3 - <<PY
import pathlib
bs = chr(92)
p = pathlib.Path("assets/pruefer-mail.js")
z = p.read_text(encoding="utf-8").split(chr(10))
k = [i for i, l in enumerate(z) if "+ maskiere(name) +" in l]
if len(k) != 1: raise SystemExit("ANKER NICHT GEFUNDEN")
z[k[0]] = "    var re = new RegExp(" + chr(34) + "^" + chr(34) + " + maskiere(name) + " + chr(34) + "[ " + bs+bs + "t]*:[ " + bs+bs + "t]*([" + bs+bs + "s" + bs+bs + "S]*)" + chr(34) + ", " + chr(34) + "im" + chr(34) + ");"
p.write_text(chr(10).join(z), encoding="utf-8")
PY'

# WARNUNG: DIESER FALL ZIELTE ZUERST AUF DEN EINTEILIGEN ZWEIG (`text/html` im
# Kopf) — und der wird von einer gewoehnlichen HTML-Datei nie erreicht: die hat
# gar keinen Kopf, `seiteAus` steigt schon davor aus. Der Fall aenderte also
# etwas, nur nicht das, was der Waechter misst — die siebte Art, wie eine
# Sabotage nichts misst. Sabotiert wird jetzt der Riegel, der WIRKLICH traegt.
# WARNUNG: DREI RIEGEL DECKEN DIESE ZUSICHERUNG, und die ersten zwei Anlaeufe
# haben je nur EINEN entfernt — der Fall lief in den naechsten und meldete sich
# als blind, obwohl die Waechter tadellos waren. Zuerst zielte er auf den
# `text/html`-Zweig (den eine Datei ohne Kopf nie erreicht), dann auf den
# Kopf-Riegel (den eine EINZEILIGE Datei nie erreicht, weil der
# Leerzeilen-Riegel davor greift). Sabotiert wird deshalb die ZUSICHERUNG:
# beide Riegel, die eine gewoehnliche HTML-Datei abweisen, fallen zusammen.
# „Zwei Riegel, die einander decken, gehoeren in EINE Gegenprobe."
probe_befehl "eine gewoehnliche HTML-Datei wird als gespeicherte Seite umgedeutet" \
      assets/pruefer-mail.js \
      'python3 - <<PY
import pathlib
p = pathlib.Path("assets/pruefer-mail.js")
z = p.read_text(encoding="utf-8").split(chr(10))
a = [i for i, l in enumerate(z) if "trenner === -1) return null;" in l]
b = [i for i, l in enumerate(z) if "test(typ)) return null;" in l]
if len(a) != 1 or len(b) != 1: raise SystemExit("ANKER NICHT GEFUNDEN")
z[a[0]] = "    if (false) return null;"
z[b[0]] = "      if (false) return null;"
p.write_text(chr(10).join(z), encoding="utf-8")
PY'

probe "eine gespeicherte Seite wird nicht mehr ausgepackt (die .mhtml waere unlesbar)" \
      assets/pruefer-mail.js \
      's|function seiteAus(roh) {|function seiteAus(roh) { if (true) return null;|'

probe "der Seiten-Teil kommt MIT Kopfzeilen und Teil-Markern heraus" \
      assets/pruefer-mail.js \
      's|      if (e.inhalt !== null) return e.inhalt;|      if (e.inhalt !== null) return teil;|'

probe "die Bedienung packt die gespeicherte Seite nicht mehr aus" \
      assets/pruefer-ui.js \
      's|window.PrueferMail.seiteAus(roh) : null;|null : null;|'

probe "die Seite verschweigt, dass sie eine andere Datei geprueft hat als die gewaehlte" \
      assets/pruefer-ui.js \
      's|p.setAttribute("data-ausgepackt", String(seite.length));||'

probe "der HTML-Eingang nimmt keine gespeicherte Seite mehr an" \
      auslieferungspruefer.html \
      's|accept=".html,.htm,.mhtml,.mht,text/html,multipart/related"|accept=".html,.htm,text/html"|'
# ── Der Wochen-Wächter (2026-09-10) ──────────────────────────────────────────
# Zwei Hälften, und sie messen verschiedene Dinge: der ZEITPLAN sorgt dafür,
# dass der Fund der Woche wirklich rotiert; der TOLERANTE VERGLEICH sorgt
# dafür, dass ein ausgefallener Lauf `main` nicht rot macht. Wer nur eine baut,
# hat entweder eine tote Empfehlung oder einen roten Kalender.
#
# ⚠ DIE FÄLLE C–E MÜSSEN GETRENNT BLEIBEN. Ein einziger Fall „der Wächter ist
#   kaputt" wäre von allen drei Fehlern erfüllt, und dann wüsste niemand,
#   welche Zusicherung wirklich bewacht ist.

probe_befehl "der Bau-Lauf hat wieder KEINEN Zeitplan (der Fund rotiert nie, main wird nach Kalender rot)" \
      .github/workflows/statische-liste.yml \
      'python3 - <<PY
import pathlib
p = pathlib.Path(".github/workflows/statische-liste.yml")
z = [l for l in p.read_text(encoding="utf-8").split(chr(10))
     if not l.strip().startswith("schedule:") and "cron:" not in l]
if len(z) == len(p.read_text(encoding="utf-8").split(chr(10))): raise SystemExit("ANKER NICHT GEFUNDEN")
p.write_text(chr(10).join(z), encoding="utf-8")
PY'

probe_befehl "der Zeitplan liegt auf dem falschen Wochentag (er schriebe den Fund der ablaufenden Woche fort)" \
      .github/workflows/statische-liste.yml \
      'python3 - <<PY
import pathlib, re
p = pathlib.Path(".github/workflows/statische-liste.yml")
t = p.read_text(encoding="utf-8")
m = re.search(r"cron: (.)([^\x27\x22]+)\\1", t)
if not m: raise SystemExit("ANKER NICHT GEFUNDEN")
f = m.group(2).split()
if len(f) != 5: raise SystemExit("ANKER NICHT GEFUNDEN")
f[4] = "0" if f[4] != "0" else "1"
p.write_text(t[:m.start()] + "cron: " + m.group(1) + " ".join(f) + m.group(1) + t[m.end():], encoding="utf-8")
PY'

probe_befehl "--pruefen verlangt wieder die Fassung GENAU DIESER Woche (der Kalender-Fehler von vorher)" \
      tools/statische-listen.mjs \
      'python3 - <<PY
import pathlib
p = pathlib.Path("tools/statische-listen.mjs")
z = p.read_text(encoding="utf-8").split(chr(10))
i = [n for n, l in enumerate(z) if "return kandidaten.length ? kandidaten.map" in l]
if len(i) != 1: raise SystemExit("ANKER NICHT GEFUNDEN")
z[i[0]] = "  return kandidaten.length ? [PTKarte.fundHtml(kandidaten[PTKarte.fundIndex(kandidaten.length)]).trim()] : [chr(39)+chr(39)];".replace("chr(39)+chr(39)", "\x27\x27")
p.write_text(chr(10).join(z), encoding="utf-8")
PY'

probe_befehl "--pruefen nimmt JEDEN Fund an (der Waechter misst gar nichts mehr)" \
      tools/statische-listen.mjs \
      'python3 - <<PY
import pathlib
p = pathlib.Path("tools/statische-listen.mjs")
z = p.read_text(encoding="utf-8").split(chr(10))
i = [n for n, l in enumerate(z) if "const fundGueltig = fundFassungen()" in l]
if len(i) != 1: raise SystemExit("ANKER NICHT GEFUNDEN")
z[i[0]] = "  const fundGueltig = true;"
p.write_text(chr(10).join(z), encoding="utf-8")
PY'

# ⚠ DIE ZEILE STEHT ZWEIMAL IN DER DATEI — wortgleich in `fundBauen` und in
#   `fundFassungen`. Ein `sed` traefe die erste und sabotierte damit den Bau
#   statt der Pruefung. Gesucht wird deshalb ab der Funktion, um die es geht.
probe_befehl "ein GESPERRTER Eintrag gilt wieder als gueltiger Fund der Woche" \
      tools/statische-listen.mjs \
      'python3 - <<PY
import pathlib
p = pathlib.Path("tools/statische-listen.mjs")
z = p.read_text(encoding="utf-8").split(chr(10))
f = [n for n, l in enumerate(z) if l.startswith("function fundFassungen(")]
if len(f) != 1: raise SystemExit("ANKER NICHT GEFUNDEN")
i = [n for n in range(f[0], min(f[0] + 6, len(z))) if "PTKarte.fundKandidaten(eintraege())" in z[n]]
if len(i) != 1: raise SystemExit("ANKER NICHT GEFUNDEN")
z[i[0]] = "  const kandidaten = eintraege();"
p.write_text(chr(10).join(z), encoding="utf-8")
PY'

# ── Bedeutungs-Beschreibung und wer im Feld gewinnt (Klaus 2026-09-10) ───────
#
# ⚠ PYTHON STATT sed. Die Beschreibung ist eine sehr lange, JSON-kodierte Zeile
#   mit Umlauten als \uXXXX — ein sed-Ausdruck darauf muesste durch drei
#   Flucht-Ebenen und traefe am Ende nichts. Ein Fall, der nichts aendert, sieht
#   aus wie eine bestandene Pruefung.

probe_befehl "die Beschreibung nennt das SBKIM-Protokoll nicht mehr" \
      assets/siegel-inhalt.js \
      'python3 - <<PY
import pathlib, re
p = pathlib.Path("assets/siegel-inhalt.js")
s = p.read_text(encoding="utf-8")
m = re.search(r"domainDescription: \"((?:[^\"\\\\]|\\\\.)*)\"", s)
if not m: raise SystemExit("ANKER NICHT GEFUNDEN")
neu = m.group(1).replace("SBKIM", "Bedeutungs").replace("Mycel", "Netzwerk")
if neu == m.group(1): raise SystemExit("ANKER NICHT GEFUNDEN")
p.write_text(s[:m.start(1)] + neu + s[m.end(1):], encoding="utf-8")
PY'

probe_befehl "die Beschreibung nennt Sage-Protokol nicht mehr als Herkunft" \
      assets/siegel-inhalt.js \
      'python3 - <<PY
import pathlib, re
p = pathlib.Path("assets/siegel-inhalt.js")
s = p.read_text(encoding="utf-8")
m = re.search(r"domainDescription: \"((?:[^\"\\\\]|\\\\.)*)\"", s)
if not m: raise SystemExit("ANKER NICHT GEFUNDEN")
neu = m.group(1).replace("Sage-Protokol", "der Spezifikation")
if neu == m.group(1): raise SystemExit("ANKER NICHT GEFUNDEN")
p.write_text(s[:m.start(1)] + neu + s[m.end(1):], encoding="utf-8")
PY'

probe_befehl "die Beschreibung faellt auf den alten Funktions-Zweizeiler zurueck" \
      assets/siegel-inhalt.js \
      'python3 - <<PY
import pathlib, re, json
p = pathlib.Path("assets/siegel-inhalt.js")
s = p.read_text(encoding="utf-8")
m = re.search(r"domainDescription: \"((?:[^\"\\\\]|\\\\.)*)\"", s)
if not m: raise SystemExit("ANKER NICHT GEFUNDEN")
alt = "PWA Toolpoint - der offene Marktplatz fuer Progressive Web Apps: Apps finden und eigene eintragen."
p.write_text(s[:m.start()] + "domainDescription: " + json.dumps(alt) + s[m.end():], encoding="utf-8")
PY'

probe_befehl "die Beschreibung verspricht ploetzlich eine Provision" \
      assets/siegel-inhalt.js \
      'python3 - <<PY
import pathlib, re
p = pathlib.Path("assets/siegel-inhalt.js")
s = p.read_text(encoding="utf-8")
m = re.search(r"domainDescription: \"((?:[^\"\\\\]|\\\\.)*)\"", s)
if not m: raise SystemExit("ANKER NICHT GEFUNDEN")
neu = m.group(1).replace("kein Bezahlvorgang, keine Provision, keine Preise",
                         "Eintrag ab 5 Euro im Monat, 10 Prozent Provision")
if neu == m.group(1): raise SystemExit("ANKER NICHT GEFUNDEN")
p.write_text(s[:m.start(1)] + neu + s[m.end(1):], encoding="utf-8")
PY'

probe_befehl "die Stichworte verlieren SBKIM, Mycel und Knoten" \
      assets/siegel-inhalt.js \
      'python3 - <<PY
import pathlib, re, json
p = pathlib.Path("assets/siegel-inhalt.js")
s = p.read_text(encoding="utf-8")
m = re.search(r"domainKeywords: (\[[^\]]*\])", s)
if not m: raise SystemExit("ANKER NICHT GEFUNDEN")
kw = [k for k in json.loads(m.group(1)) if not re.search(r"SBKIM|Mycel|Knoten", k)]
p.write_text(s[:m.start(1)] + json.dumps(kw, ensure_ascii=False) + s[m.end(1):], encoding="utf-8")
PY'

# ⚠ NICHT DIE ERSTE FUNDSTELLE. `ta.value = WIZ.domainDescription` steht
#   ZWEIMAL — als Vorbelegung und im Rueckhol-Knopf. Ein sed traefe die erste
#   und sabotierte damit genau das Richtige; gemeint ist aber der Nachweis,
#   dass der Waechter die VORBELEGUNG misst und nicht irgendeine Zeile.
# ⚠ ANKER NACHGEZOGEN 2026-09-14 (A18): der Wizard-Code ist aus
# `siegel-inhalt.js` ausgezogen, und die Konfiguration heisst dort `c`, nicht
# `WIZ`. Die fuenf Faelle hier meldeten sich als „BLIND" — `probe_befehl` konnte
# einen toten Anker nicht erkennen.
probe_befehl "das Feld zeigt nicht mehr den Vorschlag der App" \
      assets/sbkim-andock-wizard.js \
      'python3 - <<PY
import pathlib
p = pathlib.Path("assets/sbkim-andock-wizard.js")
s = p.read_text(encoding="utf-8")
alt = "ta.value = c.domainDescription || \"\";"
if alt not in s: raise SystemExit("ANKER NICHT GEFUNDEN")
p.write_text(s.replace(alt, "", 1), encoding="utf-8")
PY'

probe_befehl "die gespeicherte Spore ueberschreibt den Vorschlag wieder von selbst" \
      assets/sbkim-andock-wizard.js \
      'python3 - <<PY
import pathlib
p = pathlib.Path("assets/sbkim-andock-wizard.js")
s = p.read_text(encoding="utf-8")
alt = "          if (!abweichend) return;"
if alt not in s: raise SystemExit("ANKER NICHT GEFUNDEN")
p.write_text(s.replace(alt, "          ta.value = eigener; autoGrow(ta);\n          if (!abweichend) return;", 1), encoding="utf-8")
PY'

probe_befehl "die Zeile sagt nicht mehr, WELCHER Text im Feld steht" \
      assets/sbkim-andock-wizard.js \
      'python3 - <<PY
import pathlib
p = pathlib.Path("assets/sbkim-andock-wizard.js")
s = p.read_text(encoding="utf-8")
alt = "herkunft.id = \"sbkim-si-semantik-herkunft\";"
if alt not in s: raise SystemExit("ANKER NICHT GEFUNDEN")
p.write_text(s.replace(alt, "herkunft.id = \"sbkim-si-hinweis\";", 1), encoding="utf-8")
PY'

probe_befehl "der Rueckhol-Knopf wird gebaut, aber nie eingehaengt" \
      assets/sbkim-andock-wizard.js \
      'python3 - <<PY
import pathlib
p = pathlib.Path("assets/sbkim-andock-wizard.js")
s = p.read_text(encoding="utf-8")
alt = "wrap.appendChild(herkunft); wrap.appendChild(zurueck);"
if alt not in s: raise SystemExit("ANKER NICHT GEFUNDEN")
p.write_text(s.replace(alt, "wrap.appendChild(herkunft);", 1), encoding="utf-8")
PY'

probe_befehl "beim PRUEFER ueberschreibt die Spore den Vorschlag wieder" \
      assets/pruefer-sbkim-andock-wizard.js \
      'python3 - <<PY
import pathlib
p = pathlib.Path("assets/pruefer-sbkim-andock-wizard.js")
s = p.read_text(encoding="utf-8")
alt = "          if (!abweichend) return;"
if alt not in s: raise SystemExit("ANKER NICHT GEFUNDEN")
p.write_text(s.replace(alt, "          ta.value = eigener; autoGrow(ta);\n          if (!abweichend) return;", 1), encoding="utf-8")
PY'

probe_befehl "die Beschreibung des Pruefers nennt seinen Namen nicht mehr" \
      assets/pruefer-siegel-inhalt.js \
      'python3 - <<PY
import pathlib
p = pathlib.Path("assets/pruefer-siegel-inhalt.js")
s = p.read_text(encoding="utf-8")
alt = "Der Auslieferungspr\\u00fcfer ist"
if alt not in s: raise SystemExit("ANKER NICHT GEFUNDEN")
p.write_text(s.replace(alt, "Der Pr\\u00fcfer ist", 1), encoding="utf-8")
PY'

# ══ Die Lampen in der Kopfleiste (Klaus 2026-09-14) ═══════════════════════
# Sie stehen als Markup in der Seite, nicht in Modul 17 — die Startseite laedt
# es bewusst nicht. Der Sprach-Haken des Moduls erreicht sie also NICHT.
probe "ein Lampen-Schluessel faellt aus dem Woerterbuch" \
      assets/sprache.js \
      's/      lampe_verkehr: "verkehr",/      lampe_VERTIPPT: "verkehr",/'

# ⚠ UND DER ABLESER SELBST. Seit dem 2026-09-14 liest der Waechter die
# BASIS-Schluessel aus assets/sprache.js, statt sie abzuschreiben. Bricht das
# Ablesen, waere er ohne eigenen Riegel STILL zu streng (alles faellt) oder
# still zu lasch — von Hand nachgestellt: er meldet sich selbst mit
# „nur 0 gefunden", bevor die Folgemeldungen kommen.
probe "der Ableser findet die BASIS-Schluessel nicht mehr" \
      tests/smoke.mjs \
      "s/const de = block.slice(block.indexOf('de: {'), block.indexOf('en: {'));/const de = '';/"

# ══ Die KI-Schulung nach Art. 4 EU AI Act (2026-09-17) ═════════════════════
# Zwei Dateien: der Rahmen an der Wurzel und die byte-gleiche Kopie darunter.
# ⚠ JEDE Aenderung an der Kopie faellt ueber den Pin — die semantischen
# Waechter (Loesungsschluessel, laedt nichts nach) sind fuer den Tag gebaut, an
# dem jemand den Pin nachzieht. Deshalb steht hier KEIN Fall, der nur sie
# treffen koennte: er fiele immer zuerst am Pin, und „gefangen" hiesse dann
# nichts ueber den Waechter, um den es geht (benannte Grenze).
probe "die Kopie der Unterlage weicht vom Original ab" \
      schulung/EU_AI_Act_Art4_KI_Schulung.html \
      's/Musterfirma GmbH/Musterfirma AG/'
# Der Druck-Umbruch zwischen Seite 1 und 2 (Klaus 2026-09-18). Beide Faelle
# treffen ZUERST den Pin - das ist erwartbar und kein Fehler: der Pin bewacht die
# Datei, diese zwei bewachen, was sie tragen MUSS. Die rote Zeile mit ihrem Namen
# steht daneben.
probe "eine Ueberschrift darf wieder allein am Seitenende stehen" \
      schulung/EU_AI_Act_Art4_KI_Schulung.html \
      's/\.training h2{break-after:avoid}/.training h2{break-after:auto}/'
probe "der zweite Bogen verliert seine engeren Ueberschriften" \
      schulung/EU_AI_Act_Art4_KI_Schulung.html \
      's/<h2 class="bogen2">2\. KI ist hilfreich/<h2>2. KI ist hilfreich/'
probe "der Hochrisiko-Bereich darf wieder auseinandergerissen werden" \
      schulung/EU_AI_Act_Art4_KI_Schulung.html \
      's/\.training \.bogen4{break-inside:avoid}/.training .bogen4{break-inside:auto}/'
probe "der Hochrisiko-Block umschliesst die Eskalationsregel nicht mehr" \
      schulung/EU_AI_Act_Art4_KI_Schulung.html \
      's#<div class="bogen4">#<div class="bogen4"></div><div>#'
probe "der Schluss verliert seine Fussnoten-Groesse" \
      schulung/EU_AI_Act_Art4_KI_Schulung.html \
      's/<h2 class="fuss">Quellen und Stand/<h2>Quellen und Stand/'
probe "statt des Schlusses werden die Testfragen gestrafft" \
      schulung/EU_AI_Act_Art4_KI_Schulung.html \
      's/  \.training #result{margin:10px 0 0;padding:7px 9px}/  .training .q{padding:6px 0}/'
# Umlaute und Gedankenstriche (Klaus 2026-09-18). Auch diese drei treffen zuerst
# den Pin — das ist erwartbar; die rote Zeile mit dem eigenen Namen steht daneben,
# und genau das ist von Hand nachgestellt worden.
probe "die Unterlage schreibt wieder Umschrift statt Umlaut" \
      schulung/EU_AI_Act_Art4_KI_Schulung.html \
      's/Lösungsschlüssel/Loesungsschluessel/g'
probe "der Gedankenstrich kommt in die Unterlage zurueck" \
      schulung/EU_AI_Act_Art4_KI_Schulung.html \
      's#</strong> ist verboten, außer#</strong> — verboten, außer#'
probe "die Ueberschrift behauptet wieder eine andere Fragenzahl" \
      schulung/EU_AI_Act_Art4_KI_Schulung.html \
      's#<span id="quizCount">16</span>#<span id="quizCount">15</span>#'
probe "die Ueberschrift zieht nicht mehr von selbst nach" \
      schulung/EU_AI_Act_Art4_KI_Schulung.html \
      "s#document.getElementById('quizCount').textContent=TOTAL;##"
probe "die Seite zeigt auf eine Kopie, die es nicht gibt" \
      ki-schulung.html \
      's#schulung/EU_AI_Act_Art4_KI_Schulung.html#schulung/nirgends.html#g'
probe "die Unterlage laesst sich nicht mehr als Datei speichern" \
      ki-schulung.html \
      's/ download="EU_AI_Act_Art4_KI_Schulung.html"//'
# Klaus hat den Erklaer-Absatz am 2026-09-17 herausnehmen lassen. Der Fall
# haelt die Entscheidung: kommt die Begruendung zurueck, faellt der Waechter.
probe "die Begruendung fuers Nicht-Uebersetzen kommt auf die Seite zurueck" \
      ki-schulung.html \
      's#<p class="lead" data-i18n="schulung_lead">#<p class="hinweis">Die Unterlage wird bewusst nicht übersetzt.</p>\n    <p class="lead" data-i18n="schulung_lead">#'
probe "die englische Fassung verschweigt den Weg zum Uebersetzer" \
      assets/i18n-schulung.js \
      's/press and hold the language button/use the language button/'
probe "der deutsche Text bekommt den Uebersetzer-Satz mit" \
      assets/i18n-schulung.js \
      's/nichts wird hochgeladen · Stand der Unterlage/nichts wird hochgeladen · Browser-Übersetzer mit langem Druck · Stand der Unterlage/'
probe "die Seite verspricht Rechtskonformitaet" \
      ki-schulung.html \
      's/Keine Rechtsberatung, kein amtliches Zertifikat/Rechtssicher nach AI Act, kein amtliches Zertifikat/'
probe "die Seite meldet den Service-Worker nicht mehr an" \
      ki-schulung.html \
      "s/serviceWorker.register('sw.js')/serviceWorker.getRegistration('sw.js')/"
probe "der Eintrag faellt aus dem Regal" \
      assets/config/listings.js \
      's/"anchorId": "eigen-ki-schulung"/"anchorId": "eigen-ki-schulung-weg"/'
# Falle 1 aus dem Brief: die Liste ist eine ZEITACHSE. Ein Eintrag, der sich
# mit einem aelteren Datum neben den Pruefer draengelt, faellt am
# Reihenfolge-Waechter — genau das haette „gleich hinter dem Pruefer" getan.
probe "der Eintrag draengelt sich mit falschem Datum neben den Pruefer" \
      assets/config/listings.js \
      's/"seit": "2026-09-17"/"seit": "2026-08-20"/'
probe "der Eintrag bekommt einen Preis" \
      assets/config/listings.js \
      's/Auf Deutsch\. Mitarbeiter schulen/Auf Deutsch. Ab 49 € je Betrieb. Mitarbeiter schulen/'
probe "der Eintrag verspricht Rechtskonformitaet" \
      assets/config/listings.js \
      's/Eine Vorlage für die eigene Schulung — keine Rechtsberatung/Macht den Betrieb AI-Act-konform — keine Rechtsberatung/'
probe "die Kopie faellt aus dem Offline-Vorrat" \
      sw.js \
      's#  "schulung/EU_AI_Act_Art4_KI_Schulung.html",#  "schulung/EU_AI_Act_Art4_KI_Schulung.htm",#'
probe "die Seite faellt aus der Sitemap" \
      sitemap.xml \
      's#<loc>https://pwa-toolpoint.de/ki-schulung.html</loc>#<loc>https://pwa-toolpoint.de/ki-schulungen.html</loc>#'

# ── WARTUNG: unsichtbar schalten und wieder zurück (Klaus 2026-09-18) ────────
# Jeder Fall ist von Hand nachgestellt und seine rote Zeile gelesen — „rot" ist
# keine Messung, solange die rote Zeile den Namen einer ANDEREN Zusicherung
# trägt. Filter: NUR_FALL="WARTUNG:" bash tests/gegenprobe.sh
probe "WARTUNG: die Sperre geht NICHT mehr vor" \
      assets/karte.js \
      's/return !!wartungVon(e) \&\& !istGesperrt(e);/return !!wartungVon(e);/'
probe "WARTUNG: die sichtbare Liste filtert nichts mehr" \
      assets/karte.js \
      's/      return !istWartung(e);/      return true;/'
probe "WARTUNG: ein beliebiger Wert gilt schon als Wartung" \
      assets/karte.js \
      's/return (w \&\& w.wartung === true) ? w : null;/return (w \&\& w.wartung) ? w : null;/'
probe "WARTUNG: ein Eintrag in Wartung darf wieder Fund der Woche sein" \
      assets/karte.js \
      's/return e \&\& e.img \&\& !istGesperrt(e) \&\& !istWartung(e);/return e \&\& e.img \&\& !istGesperrt(e);/'
probe "WARTUNG: die Seite filtert die Liste nicht mehr" \
      assets/app.js \
      's/? window.PTKarte.sichtbare(alleListings)/? alleListings/'
probe "WARTUNG: die Seite liest PT_LISTINGS an einer zweiten Stelle" \
      assets/app.js \
      's/  var GELADEN = Date.now();/  var GELADEN = Date.now(); var nochmal = window.PT_LISTINGS;/'
probe "WARTUNG: das Bau-Werkzeug filtert nicht mehr" \
      tools/statische-listen.mjs \
      's/  return PTKarte.sichtbare(eintraege());/  return eintraege();/'
# ⚠ DIE DATEI HAT SICH AM 2026-09-21 GEAENDERT: `wacheLesen` wohnt seitdem in
#   tools/lib/markt-lesen.mjs, damit zwei Werkzeuge dieselbe Lese-Regel benutzen.
#   Wer eine Zeile verschiebt, auf die ein Fall zeigt, zieht den Fall mit —
#   sonst meldet er sich als „nicht gefangen", waehrend der Waechter tadellos ist.
probe "WARTUNG: der Bau-Leser wirft Einträge ohne Ampel wieder weg" \
      tools/lib/markt-lesen.mjs \
      's/    const inWartung = e.wartung === true;/    const inWartung = false;/'
probe "WARTUNG: der Messlauf zählt auch während der Wartung" \
      tools/messwerte-holen.mjs \
      's/  const tief = (w \&\& w.wartung === true) ? 0 : naechteUnterGrenze(reihen, e.anchorId, bis);/  const tief = naechteUnterGrenze(reihen, e.anchorId, bis);/'
probe "WARTUNG: der Messlauf vergisst das Enddatum" \
      tools/messwerte-holen.mjs \
      "s/    ? w.wartungBis : '';/    ? '' : '';/"
probe "WARTUNG: das Studio bietet keinen Rückweg an" \
      assets/studio.js \
      "s/      ? '<button type=\"button\" class=\"btn slim ghost\" data-wartungaus=\"' + esc(id) + '\">✅ Wartung beenden<\/button>'/      ? '<button type=\"button\" class=\"btn slim ghost\" data-wartungan=\"' + esc(id) + '\">🛠 Wartung<\/button>'/"
probe "WARTUNG: das Studio merkt sich das Ende nicht" \
      assets/studio.js \
      's/    else { neu.wartungBis = heuteOrt(); }/    else { neu.wartungSeit = heuteOrt(); }/'
probe "WARTUNG: das Studio überschreibt dabei die Ampel" \
      assets/studio.js \
      's/    neu.wartung = !!an;/    neu.ampel = ""; neu.wartung = !!an;/'
probe "WARTUNG: ein abgewiesenes Feld schickt ins falsche Repo" \
      assets/studio.js \
      's/    if (\/field_not_allowed|bad_wartung\/.test(t)) {/    if (false) {/'
# ── BILD: der Ausgangszustand vom 2026-09-18 ────────────────────────────────
# Der erste Fall ist genau der Fehler, den Klaus im Studio gesehen hat: der
# Riegel verlangt wieder `https://`, und die drei Eintraege mit eigenem Pfad
# verlieren ihr Icon. Er MUSS „KEIN Eintrag der Liste verliert im Studio sein
# Bild" umwerfen — der Waechter, den es vorher nicht gab.
probe "BILD: der Riegel verlangt wieder nur https (Klaus' Befund)" \
      assets/studio.js \
      's/    return (istHttps(u) || eigenerPfad(u)) ? u : "";/    return istHttps(u) ? u : "";/'
probe "BILD: SVG kommt wieder durch" \
      assets/studio.js \
      's/svg(/svgNIEMALS(/'
probe "BILD: ein Weg nach oben ist wieder erlaubt" \
      assets/studio.js \
      "s/ \&\& u.indexOf(\"..\") === -1;/;/"
probe "BILD: eine Adresse ohne Protokoll gilt als eigener Pfad" \
      assets/studio.js \
      's|^    return /\^\[A-Za-z0-9._-\]+|    return /^[A-Za-z0-9._\\/-]*|'
probe "WARTUNG: die Datei erklärt die Grenze nicht mehr" \
      assets/config/wache-hand.json \
      's/Ein ROT geschalteter Eintrag wird NICHT unsichtbar, die Sperre geht vor\./Ein ROT geschalteter Eintrag verhaelt sich anders./'

# ── Die zwei Rechnungen, die am 2026-09-18 die Veroeffentlichung stillgelegt
#    haben. Beide massen eine ZAHL statt einer Zusicherung und wurden ROT, als
#    Klaus zwei Apps in Wartung schaltete — der Arbeitsablauf brach ab, und
#    index.html wurde nie neu geschrieben. Sabotiert wird jede Rechnung an der
#    Stelle, an der sie damals falsch lag.
probe "RECHNUNG: sichtbarZahl zaehlt wieder ALLE statt der sichtbaren" \
      tests/smoke.mjs \
      's|    return !(w \&\& w.wartung === true \&\& w.ampel !== .rot.);|    return true;|'

probe "RECHNUNG: die Sperre geht der Wartung NICHT mehr vor" \
      tests/smoke.mjs \
      "s|    return !(w \&\& w.wartung === true \&\& w.ampel !== 'rot');|    return !(w \&\& w.wartung === true);|"

probe "RECHNUNG: gerechneteEintraege meldet wieder jeden Eintrag" \
      tests/smoke.mjs \
      "s|      if (!e \|\| typeof e !== 'object') return false;|      if (!e \|\| typeof e !== 'object') return false; return true;|"

probe "RECHNUNG: ein Automatik-Feld faellt nicht mehr auf" \
      tests/smoke.mjs \
      's|  const autoFelder = \[.unterGrenze.|  const autoFelder = ['keinFeldDasEsGibt'|'

echo
echo
echo "── DETAIL: die Detailseiten unter /apps/ ──"
# ⚠ DER KERNFALL DIESES BLOCKS STEHT ZUERST, und er ist Klaus' Tafel vom
# 2026-09-21: „kein sichtbarer Inhalt darf von JavaScript abhaengig sein."
# Eine Zusicherung, die keine Probe von ihrem Gegenteil unterscheiden kann,
# ist keine — also wandert hier ein Abschnitt ins Skript, und die
# Browser-Probe MUSS umfallen.
#
# ⚠ UND DIE SABOTAGE MUSS DAS TREFFEN, WAS DER WAECHTER MISST. Ein Abschnitt,
# den ein Skript erst nachtraegt, ist ohne JavaScript weg — genau das misst
# tests/smoke_detail.mjs mit `javaScriptEnabled: false`. Ein blosses
# Weg-Loeschen des Abschnitts wuerde dagegen schon `--pruefen` umwerfen, und
# der Fall bewiese etwas ueber das Werkzeug statt ueber die Tafel.

probe_befehl "DETAIL: ein Abschnitt wird erst von JavaScript gezeichnet" \
      apps/markt-mixarium/index.html \
      'python3 - <<PYEND
import pathlib, re
p = pathlib.Path("apps/markt-mixarium/index.html")
t = p.read_text()
m = re.search(r"  <section class=\"app-abschnitt glass\">\n    <h2 data-i18n=\"det_woher\".*?</section>", t, re.S)
roh = m.group(0)
skript = "<script>document.querySelector(\"main\").insertAdjacentHTML(\"beforeend\", " + repr(roh).replace("\x27", "\x22") + ");</" + "script>"
p.write_text(t.replace(roh, skript))
PYEND'

probe_befehl "DETAIL: das CSS versteckt die Messtabelle, bis ein Skript sie freigibt" \
      apps/markt-mixarium/index.html \
      'python3 -c "
import pathlib
p = pathlib.Path(\"apps/markt-mixarium/index.html\")
t = p.read_text()
p.write_text(t.replace(\"</head>\", \"<style>.mess-tabelle tr{display:none}</style></head>\", 1))
"'

# ⚠ UND MEIN ERSTER ANLAUF WAR VON BAUART BLIND. Er zielte auf den Waechter
# „kein Querlauf bei 390 px" — der misst aber das DOKUMENT, und `.mess-huelle`
# traegt `overflow-x: auto`: sie faengt jeden Ueberlauf ab, genau dafuer ist
# sie gebaut. Das Dokument laeuft deshalb NIE quer, egal wie breit die Tabelle
# wird. Der Fall konnte nie fangen, und er sah dabei aus wie eine bestandene
# Pruefung.
# Gemessen wird seitdem, ob die Tabelle die Huelle zum Scrollen ZWINGT — die
# Frage, um die es Klaus ging: „fuenf Spalten auf 360 px quetschen die Zahlen".
#
# ⚠ ZWEI RIEGEL, DIE EINANDER DECKEN, GEHOEREN IN EINEN FALL. Die Breite
# haengt an `table-layout: fixed` UND an der Breite der ersten Spalte; wer nur
# eines wegnimmt, misst den anderen mit. Sabotiert werden beide.
probe_befehl "DETAIL: die Tabelle passt bei 390 px nicht mehr in ihre Huelle" \
      assets/style.css \
      'python3 -c "
import pathlib
p = pathlib.Path(\"assets/style.css\")
t = p.read_text()
t = t.replace(\"table-layout: fixed;\", \"table-layout: auto;\")
t = t.replace(\"width: 31%;\", \"width: 60%;\")
t = t.replace(\"overflow-wrap: break-word;\", \"overflow-wrap: normal;\")
t = t.replace(\"white-space: normal;\", \"white-space: nowrap;\")
p.write_text(t)
"'

probe "DETAIL: ein Bedienelement im Inhalt wird zum toten Knopf" \
      apps/markt-mixarium/index.html \
      's|<a class="btn primary" href=|<button data-href=|'

probe "DETAIL: der Weg zurueck wird zum toten Anker (#pruefung ohne ../../)" \
      apps/markt-mixarium/index.html \
      's|href="\.\./\.\./#pruefung"|href="#pruefung"|'

probe "DETAIL: Canonical zeigt auf den Marktplatz statt auf die eigene Adresse" \
      apps/markt-mixarium/index.html \
      's|<link rel="canonical" href="https://pwa-toolpoint.de/apps/markt-mixarium/">|<link rel="canonical" href="https://pwa-toolpoint.de/">|'

probe "DETAIL: die Beschreibung endet wieder mitten im Wort" \
      apps/markt-mixarium/index.html \
      's|<meta name="description" content="\([^"]\{40\}\)[^"]*"|<meta name="description" content="\1 abgeschnitt"|'

probe "DETAIL: die Seite faellt aus dem Installations-Vorrat" \
      sw.js \
      's|^\( *\)"apps/markt-mixarium/index.html",|\1"apps/gibts-nicht/index.html",|'

probe "DETAIL: der Navigations-Rueckfall gibt fuer /apps/ wieder die Startseite" \
      sw.js \
      's|var istApp = url.pathname.indexOf("/apps/") !== -1;|var istApp = false;|'

# ⚠ UND DIESE SABOTAGE HAT BEIM ERSTEN LAUF NICHTS GEMESSEN. Sie suchte
# `<h1>${esc(e.label)}</h1>`, im Werkzeug steht `<h1>${esc(e.label || '')}</h1>`
# — die zweite Ersetzung traf nicht, nur die unbenutzte Konstante kam hinein.
# Die DATEI aenderte sich (also kein toter Anker), die AUSGABE nicht, und der
# Smoke blieb zu Recht gruen. Eine Sabotage muss treffen, was der Waechter
# misst; „sie hat die Datei veraendert" ist dafuer zu wenig.
#
# ⚠ EIN DATUM AUS DER UHR WAERE DER FEHLER VOM 2026-09-18, an einer neuen Tuer:
# die Pruefung steht im Arbeitsablauf VOR dem Commit, also waere `main` jeden
# Tag von allein rot. Der Fall setzt ein `new Date()` in die gebaute Seite —
# dann liefert das Werkzeug bei verstellter Zeitzone etwas anderes.
probe_befehl "DETAIL: ein Datum aus der Uhr macht den Bau zeitzonen-abhaengig" \
      tools/detailseiten.mjs \
      'python3 -c "
import pathlib
p = pathlib.Path(\"tools/detailseiten.mjs\")
t = p.read_text()
t = t.replace(\"const robots = process.argv.includes\", \"const STEMPEL = new Date().toLocaleDateString(\\\"de-DE\\\");\nconst robots = process.argv.includes\", 1)
t = t.replace(\"<h1>\${esc(e.label || \x27\x27)}</h1>\", \"<h1>\${esc(e.label || \x27\x27)} \${STEMPEL}</h1>\", 1)
p.write_text(t)
"'

# ⚠ UND DIE ZWEI FRAGEN, DIE VORHER EINE WAREN: „weicht ab" und „gibt es noch
# nicht" verlangen das Gegenteil voneinander. Wirft man sie wieder zusammen,
# ist `--pruefen` rot, obwohl nichts kaputt ist — genau der Zustand, in dem
# dieser Block heute nicht mehr laufen wuerde.
probe "DETAIL: ungebaut und abweichend werden wieder verwechselt" \
      tools/detailseiten.mjs \
      's|  if (alt === null) {|  if (false) {|'

echo
echo "── SITEMAP: eine Einladung, die sich nicht widerspricht ──"
# ⚠ GEMESSEN AM 2026-09-21, nicht ausgedacht: `impressum.html` und
# `datenschutz.html` standen in der Sitemap UND trugen `noindex` — eine
# Einladung und eine Absage zugleich. Und `auslieferungspruefer.html` FEHLTE,
# obwohl indexierbar. Das zweite hat kein Waechter gefunden, weil keiner in
# die GEGENRICHTUNG fragte: „jede Adresse existiert" ist auch dann gruen,
# wenn die Sitemap nur eine Zeile hat.

probe_befehl "SITEMAP: eine noindex-Seite wird wieder eingeladen" \
      sitemap.xml \
      'python3 -c "
import pathlib
p = pathlib.Path(\"sitemap.xml\")
t = p.read_text()
p.write_text(t.replace(\"</urlset>\", \"  <url><loc>https://pwa-toolpoint.de/impressum.html</loc></url>\n</urlset>\"))
"'

probe_befehl "SITEMAP: eine indexierbare Seite faellt wieder heraus" \
      sitemap.xml \
      'python3 -c "
import pathlib, re
p = pathlib.Path(\"sitemap.xml\")
t = p.read_text()
p.write_text(re.sub(r\"  <url>\s*<loc>https://pwa-toolpoint.de/auslieferungspruefer.html</loc>.*?</url>\n\", \"\", t, flags=re.S))
"'

# ⚠ Eine Seite, die auf eine ANDERE kanonisiert, laedt Google zu etwas ein,
# das es gleich wieder wegwirft — Googles Bericht nennt das „Duplikat, Google
# hat eine andere Seite als kanonisch bestimmt", und genau diese Zeile steht
# in Klaus' Bericht schon einmal.
probe "SITEMAP: eine eingeladene Seite kanonisiert auf eine andere" \
      ki-schulung.html \
      's|<link rel="canonical" href="https://pwa-toolpoint.de/ki-schulung.html"|<link rel="canonical" href="https://pwa-toolpoint.de/"|'

echo
echo "── AUFKLAPP: der Messverlauf klappt auf, und der Weg zum Pruefer ──"

probe "AUFKLAPP: der Verlauf steht wieder offen statt zugeklappt" \
      tools/detailseiten.mjs \
      "s|T.push('    <details class=\"mess-auf\">');|T.push('    <div class=\"mess-auf\">');|"

# ⚠ DER FALL, AUF DEN ES BEI EINEM AUFKLAPPER ANKOMMT: waere der Inhalt erst
# beim Oeffnen da, saehe eine Suchmaschine eine leere Tabelle. Die Sabotage
# laesst die Zeilen erst von einem Skript nachtragen — dann steht zugeklappt
# NICHTS im HTML, und genau das muss auffallen.
probe_befehl "AUFKLAPP: die Zeilen stehen zugeklappt NICHT mehr im HTML" \
      apps/markt-mixarium/index.html \
      'python3 - <<PYEND
import pathlib, re
p = pathlib.Path("apps/markt-mixarium/index.html")
t = p.read_text()
m = re.search(r"      <tbody>\n.*?      </tbody>", t, re.S)
roh = m.group(0)
skript = "<tbody></tbody></table></div><script>document.querySelector(\"main .mess-tabelle tbody\").innerHTML = " + repr(roh.split(">",1)[1].rsplit("<",1)[0]).replace("\x27", "\x22") + ";</" + "script><div style=\"display:none\"><table><tbody>"
p.write_text(t.replace(roh, skript))
PYEND'

probe "AUFKLAPP: die Adresse wird beim Laden gleich ABGERUFEN" \
      assets/pruefer-ui.js \
      's|        feldVor.value = u.href;|        feldVor.value = u.href; setTimeout(holeAdresse, 0);|'

probe "AUFKLAPP: ein javascript:-Wert kommt wieder ins Adressfeld" \
      assets/pruefer-ui.js \
      's|      if (u.protocol === "http:" \|\| u.protocol === "https:") {|      if (true) {|'

probe "AUFKLAPP: der Weg zum Pruefer traegt die Adresse nicht mehr mit" \
      tools/detailseiten.mjs \
      's|auslieferungspruefer.html?adresse=${esc(encodeURIComponent(e.url))}|auslieferungspruefer.html|'

# ⚠ DIE GRENZE GEHOERT DANEBEN. Ohne sie verspricht der Abschnitt, dass der
# Pruefer sieht, was eine Seite VERSCHICKT — und das kann er nicht: er liest
# den ausgelieferten Quelltext, nicht den laufenden Verkehr. Ein Versprechen,
# das das Werkzeug nicht haelt, ist genau das, was der Ton dieses Depots
# verbietet.
probe "AUFKLAPP: die benannte Grenze des Pruefers faellt weg" \
      tools/detailseiten.mjs \
      's|data-i18n="det_selbst_grenze"|data-i18n="det_selbst_ohne_grenze"|'

echo
echo "── KNOEPFE: die zwei, die Klaus am Tablet gefunden hat ──"
# ⚠ „Ich komme jedes Mal auf die Seite von PWA Toolpoint zurueck, jeweils
#   immer an einer anderen Stelle." (Klaus 2026-09-21)
# Beide Knoepfe waren von der Marktplatz-Karte uebernommen, und beide fuehrten
# auf einer Detailseite woandershin, als sie versprechen. Der Melde-Knopf ist
# der teurere Fall: auf der Karte faengt `app.js` ihn ab, `#auftrag` ist nur
# der Rueckfall — die Detailseite hat kein app.js, also WAR der Rueckfall
# alles. Wer melden wollte, stand in einem Verkaufs-Formular.

probe 'KNOEPFE: der Zahlen-Knopf springt wieder vom Blatt' \
      tools/detailseiten.mjs \
      's|href="#woher" data-i18n="det_bewertung"|href="../../#pruefung" data-i18n="det_bewertung"|'

probe 'KNOEPFE: der Anker woher faellt weg - der Knopf zeigt ins Leere' \
      tools/detailseiten.mjs \
      "s|<h2 id=\"woher\" data-i18n=\"det_woher\">|<h2 data-i18n=\"det_woher\">|"

probe 'KNOEPFE: der Melde-Knopf landet wieder im Auftrags-Formular' \
      tools/detailseiten.mjs \
      's|href="../../?melden=${esc(encodeURIComponent(id))}"|href="../../#auftrag"|'

probe 'KNOEPFE: der Marktplatz liest den Melde-Anhang nicht mehr' \
      assets/app.js \
      's|var wen = new URLSearchParams(location.search).get("melden");|var wen = null;|'

# ⚠ DER ANHANG KOMMT AUS EINER ADRESSZEILE, und die kann jeder schreiben.
# Ohne die Pruefung gegen die echte Liste stuende ein frei erfundener Name im
# Melde-Dialog und saehe aus, als komme er von hier.
probe 'KNOEPFE: eine erfundene Kennung oeffnet wieder einen Dialog' \
      assets/app.js \
      's|        if (tr) meldeOeffnen(wen, tr.label \|\| "", null);|        meldeOeffnen(wen, (tr \&\& tr.label) \|\| wen, null);|'

# ⚠ UND DAS TEUERSTE: aus der UNGEFILTERTEN Liste zu lesen. Dann oeffnet
# `?melden=<App in Wartung>` einen Dialog fuer einen Eintrag, der ueberall
# sonst unsichtbar ist — und bestaetigt damit, dass es ihn gibt. Genau das
# Leck, gegen das die Wartung gebaut ist. Gefunden hat es ein VORHANDENER
# Waechter („app.js liest PT_LISTINGS an genau EINER Stelle").
probe 'KNOEPFE: ein Eintrag in WARTUNG wird wieder meldbar' \
      assets/app.js \
      's|        for (var i = 0; i < listings.length; i++) {|        var listings = window.PT_LISTINGS \|\| []; for (var i = 0; i < listings.length; i++) {|'

# ⚠ Und der Anhang muss aus der Adresszeile VERSCHWINDEN. Sonst oeffnet der
# Dialog bei jedem Neuladen wieder, und wer den Link weitergibt, schickt
# jemanden in ein Melde-Formular, das er nie oeffnen wollte.
probe 'KNOEPFE: der Melde-Anhang bleibt in der Adresszeile stehen' \
      assets/app.js \
      's|        history.replaceState(null, "", sauber);||'

echo
echo "── KENNUNG: eine Adresse, die einmal vergeben ist, bleibt ──"
# ⚠ GEMESSEN AM 2026-09-21, nicht vermutet: "Mein Tresor" und "Mein  Tresor!"
# ergaben beide markt-mein-tresor. Zwei Apps unter EINER Adresse, und die
# zweite erbt die Geschichte der ersten — ihre Messungen, ihre Verlinkungen,
# das, was Google ueber sie weiss. Bei 29 eigenen Eintraegen ist das nie
# passiert; bei fremden Einsendungen ist es eine Frage der Zeit.

probe 'KENNUNG: der Kollisions-Riegel faellt weg' \
      assets/studio.js \
      's|    if (!genommen\[roh\]) return roh;|    return roh;|'

# ⚠ EIN RIEGEL, DER IMMER EINE ZIFFER ANHAENGT, waere genauso falsch — nur
# andersherum. Dann traegt jede Adresse ein "-2", ohne dass es eine erste gibt.
probe 'KENNUNG: der Riegel feuert immer statt nur bei Kollision' \
      assets/studio.js \
      's|    if (!genommen\[roh\]) return roh;|    if (false) return roh;|'

probe 'KENNUNG: die Umlaut-Ersetzung faellt weg' \
      assets/studio.js \
      's|    return String(s \|\| "").replace(/\[äöüßÄÖÜ\]/g, function (z) { return UMLAUTE\[z\] \|\| z; });|    return String(s \|\| "");|'

# ⚠ Das scharfe s hat kein Gegenstueck in NFKD — ohne seinen Eintrag wird aus
# "Strasse" ein "stra-e". Ein eigener Fall, weil ein Waechter auf die Umlaute
# allein hier gruen bliebe.
probe 'KENNUNG: das scharfe s faellt aus der Tabelle' \
      assets/studio.js \
      's|"ß": "ss",|"ss_fehlt": "ss",|'

# ⚠ Die belegten Kennungen werden UEBERGEBEN. Wer das zweite Argument
# weglaesst, hat einen Riegel, der gegen eine leere Liste prueft — also gegen
# nichts. Genau die Sorte Fehler, die man aus Versehen macht.
probe 'KENNUNG: die belegten Kennungen kommen nicht mehr an' \
      assets/studio.js \
      's|      e.anchorId = kennung(e.label, belegteKennungen());|      e.anchorId = kennung(e.label);|'

probe 'KENNUNG: eine abweichende Kennung wird nicht mehr genannt' \
      assets/studio.js \
      's|      if (e.anchorId !== kennungRoh(e.label)) {|      if (false) {|'

# ══════════════════════════════════════════════════════════════════════════
# OHNEMESS: ein Messblatt ohne Messwerte (SEO-Plan S8a, dritte Luecke)
#
# Am ersten Tag hat ein fremder Eintrag keine Messung, keine geprueften
# Eigenschaften und kein `seit`. Die Seite muss trotzdem stehen UND sagen, was
# fehlt — ein leerer Abschnitt ist schlechter als keiner, ein erfundenes Datum
# schlimmer als beides.
#
# ⚠ Die Faelle sitzen am WERKZEUG, nicht an den echten Daten: heute traegt
# jeder sichtbare Eintrag eine Messreihe, der Fall kaeme im Bestand gar nicht
# vor. Der Smoke fuehrt das echte Werkzeug dafuer in einer Wegwerf-Kopie.
# ══════════════════════════════════════════════════════════════════════════
echo "── OHNEMESS: das Messblatt ohne Messwerte ──"

probe 'OHNEMESS: der Verlauf wird auch ohne Messpunkte gebaut (leere Tabelle)' \
      tools/detailseiten.mjs \
      's|  if (punkte.length > 1) {|  if (true) {|'

# Die GEGENRICHTUNG am selben Anker: wird er nie gebaut, misst „der Verlauf
# fehlt" nichts mehr — dann waere der Wachter oben trivial gruen.
probe 'OHNEMESS: der Verlauf wird NIE gebaut — „fehlt" misst dann nichts' \
      tools/detailseiten.mjs \
      's|  if (punkte.length > 1) {|  if (false) {|'

probe 'OHNEMESS: „Noch nicht gemessen" faellt weg — die Seite schweigt statt zu sagen, was fehlt' \
      tools/detailseiten.mjs \
      "s|Noch nicht gemessen — |Statt dessen nichts — |"

probe 'OHNEMESS: die Maengel-Ueberschrift steht AUSSERHALB ihres Riegels' \
      tools/detailseiten.mjs \
      "s|  if (j \&\& j.mangel.length) {|  T.push('    <h2>Was dabei bemängelt wurde</h2>');\n  if (j \&\& j.mangel.length) {|"

probe 'OHNEMESS: „Noch nicht geprueft" faellt weg' \
      tools/detailseiten.mjs \
      "s|Noch nicht geprüft — |Statt dessen nichts — |"

# ⚠ EIN ERFUNDENES DATUM IST DER TEUERSTE DIESER FAELLE: es sieht aus wie eine
# Auskunft und ist eine. `--pruefen` steht im Arbeitsablauf VOR dem Commit —
# ein Datum aus der Uhr legt die Veroeffentlichung am naechsten Tag still.
probe 'OHNEMESS: ein fehlendes `seit` wird durch das heutige Datum ersetzt' \
      tools/detailseiten.mjs \
      "s|  if (e.seit) fakten.push(|  fakten.push(\`<span class=\\\"seit\\\">seit \${monatJahr(new Date().toISOString())}</span>\`); if (e.seit) fakten.push(|"

# ══════════════════════════════════════════════════════════════════════════
# ANKER: ein Sprungziel landet nicht unter der klebenden Kopfleiste
#
# Klaus 2026-09-21 nach dem Sichttest: er klickt „Ausführlich: wie hier
# geprueft wird →", landet auf dem Marktplatz — und sieht die versprochene
# Ueberschrift nicht. Gemessen: die Leiste ist sticky, der Sprung setzt den
# Abschnitt auf top:0, die Ueberschrift stand bei top:24.
#
# ⚠ ZWEI VERSCHIEDENE ZUSICHERUNGEN, und sie brauchen verschiedene Faelle:
# die SICHTBARKEIT haelt der Rueckfall im Stylesheet (auch ohne Skript), die
# GENAUIGKEIT kommt aus der abgelesenen Hoehe. Ein Fall, der nur den Rueckfall
# anfasst, misst die zweite nicht — und umgekehrt.
# ══════════════════════════════════════════════════════════════════════════
echo "── ANKER: Sprungziele unter der Kopfleiste ──"

probe 'ANKER: es gibt gar kein scroll-padding mehr — das Ziel klebt unter der Leiste' \
      assets/style.css \
      's|^html { scroll-padding-top: var(--kopf-hoehe, 190px); }|html { scroll-padding-top: 0; }|'

# Der Rueckfall ist die gemessene Obergrenze (185 px + Luft). Zu klein heisst
# verdeckt — und zwar genau dort, wo kein Skript laeuft.
probe 'ANKER: der Rueckfall ist zu klein — ohne Skript wieder verdeckt' \
      assets/style.css \
      's|var(--kopf-hoehe, 190px)|var(--kopf-hoehe, 20px)|'

probe 'ANKER: die abgelesene Hoehe ist 0 — mit Skript wieder verdeckt' \
      assets/thema.js \
      's|    if (h > 0) document.documentElement.style.setProperty("--kopf-hoehe", (h + LUFT) + "px");|    document.documentElement.style.setProperty("--kopf-hoehe", "0px");|'

# ⚠ DIESER FALL MISST DIE GENAUIGKEIT, NICHT DIE SICHTBARKEIT. Ohne das
# Nachziehen bleibt die Ueberschrift sichtbar (der Rueckfall traegt) — sie
# sitzt nur zu tief. Ohne den Abstands-Waechter waere er blind.
probe 'ANKER: der Lade-Sprung wird nicht mehr nachgezogen — die Hoehe wirkt dort nicht' \
      assets/thema.js \
      's|^    sprungNachziehen();|    /* nachgezogen wird nicht mehr */|'

probe 'ANKER: die Kopfhoehe wird gar nicht erst abgelesen' \
      assets/thema.js \
      's|^    kopfHoeheSetzen();|    /* abgelesen wird nicht mehr */|'

echo "── ANKER: der Weg zum Marktplatz ist benannt ──"

# ⚠ DIESE ZWEI FAELLE FASSEN ZWEI DATEIEN AN, UND DAS IST DER GANZE PUNKT.
# Die Probe liest die GEBAUTE Seite; das Werkzeug allein zu sabotieren haette
# nur `--pruefen` umgeworfen (Seite weicht vom Werkzeug ab) — gefangen, aber
# aus dem falschen Grund, und mein Link-Waechter waere dabei ungemessen
# geblieben. Sabotiert wird deshalb das Werkzeug UND danach neu gebaut: dann
# passt die Seite zum Werkzeug, und nur der Waechter, um den es geht, kann
# fallen.
probe_mehr 'ANKER: der Link verliert seinen Sprach-Schluessel — auf Englisch bleibt er deutsch' \
      "tools/detailseiten.mjs apps/markt-mixarium/index.html" \
      'sed -i "s| data-i18n=.det_woher_mehr.||" tools/detailseiten.mjs
       node tools/detailseiten.mjs --nur=markt-mixarium >/dev/null 2>&1'

probe_mehr 'ANKER: der Link sagt nicht mehr, dass er auf den Marktplatz fuehrt' \
      "tools/detailseiten.mjs apps/markt-mixarium/index.html" \
      'sed -i "s|Ausführlich: wie hier geprüft wird — auf dem Marktplatz →|Ausführlich: wie hier geprüft wird →|" tools/detailseiten.mjs
       node tools/detailseiten.mjs --nur=markt-mixarium >/dev/null 2>&1'

probe 'ANKER: die englische Fassung des Links fehlt' \
      assets/i18n-detail.js \
      's|    "det_woher_mehr": "In detail: how things are checked here — on the marketplace →",||'

# ──────────────────────────────────────────────────────────────────────────
# PRUEFVOR: der Pruefer oeffnet den Eingang, den die Vorbelegung meint
#
# Klaus 2026-09-21: "dann landet man in PWA Toolpoint, um PWA Toolpoint zu
# pruefen, statt Mixarium." Das Feld war gefuellt — nur stand es in einem
# geschlossenen Reiter. Jeder Fall trifft GENAU EINE Zusicherung; eine
# Sabotage, die zwei umwirft, sagt nicht, welche gemessen wurde.
echo "── PRUEFVOR: der Eingang, den die Vorbelegung meint ──"

probe 'PRUEFVOR: der Reiter wird nicht mehr umgelegt — das Feld steht wieder im Verborgenen' \
      assets/pruefer-ui.js \
      's|        zeigeEingang("adresse");||'

# Der Riegel steht VOR dem Umschalten. Hier wandert er dahinter: eine fremde
# Adresszeile oeffnet dann den Abruf-Eingang, obwohl ihr Wert abgewiesen wird.
probe 'PRUEFVOR: ein javascript:-Wert legt den Reiter trotzdem um' \
      assets/pruefer-ui.js \
      's|      if (u.protocol === "http:" \|\| u.protocol === "https:") {|      zeigeEingang("adresse"); if (u.protocol === "http:" \|\| u.protocol === "https:") {|'

# Umgekehrt: springt der Reiter IMMER, kommt niemand mehr ohne Umweg zum
# Eingang fuer eine Datei. Sabotiert wird nur der Reiter, nicht das Feld —
# sonst faellt der Vorgabe-Waechter mit, und der misst etwas anderes.
probe 'PRUEFVOR: der Reiter springt auch OHNE Anhang um' \
      assets/pruefer-ui.js \
      's|    var feldVor = \$("adrFeld");|    var feldVor = $("adrFeld"); zeigeEingang("adresse");|'

# ──────────────────────────────────────────────────────────────────────────
# APPS: 27 Seiten, eine Uebersicht, und der Weg dorthin (S7, 2026-09-21)
#
# Klaus: "wie wird diese Seite aufgerufen, von welcher anderen Seite?" Bis
# dahin von keiner. Jeder Fall trifft GENAU EINE Zusicherung; wo eine Sabotage
# das Werkzeug betrifft, wird danach NEU GEBAUT, damit nicht `--pruefen`
# faellt statt des gemeinten Waechters.
echo "── APPS: Vollstaendigkeit, Uebersicht, der Weg dorthin ──"

probe_befehl 'APPS: eine Detailseite fehlt — der Eintrag steht ohne Seite da' \
      apps/markt-mixarium/index.html \
      'rm -f apps/markt-mixarium/index.html'

probe 'APPS: das Werkzeug rechnet den Pfad wieder selbst — zwei Fassungen derselben Adresse' \
      tools/detailseiten.mjs \
      's|PTKarte.detailPfad(id)|`apps/${id}/`|'

probe_mehr 'APPS: die Uebersicht laesst einen Eintrag aus' \
      "tools/detailseiten.mjs apps/index.html" \
      'python3 - <<PYEOF
p="tools/detailseiten.mjs"; s=open(p,encoding="utf-8").read()
alt="    for (const e of g.eintraege) {"
neu="    for (const e of g.eintraege.slice(1)) {"
assert s.count(alt)==1
open(p,"w",encoding="utf-8").write(s.replace(alt,neu))
PYEOF
       node tools/detailseiten.mjs >/dev/null 2>&1'

probe_mehr 'APPS: die ItemList zeigt auf die fremde App statt auf die eigene Seite' \
      "tools/detailseiten.mjs apps/index.html" \
      'python3 - <<PYEOF
p="tools/detailseiten.mjs"; s=open(p,encoding="utf-8").read()
alt="      url: \`\${BASIS_URL}/\${seitenPfad(String(e.anchorId || \x27\x27))}\`,"
neu="      url: String(e.url || \x27\x27),"
assert s.count(alt)==1, s.count(alt)
open(p,"w",encoding="utf-8").write(s.replace(alt,neu))
PYEOF
       node tools/detailseiten.mjs >/dev/null 2>&1'

probe_mehr 'APPS: „Einzelheiten" faellt von der Karte — der Weg dorthin ist wieder weg' \
      "assets/karte.js index.html" \
      'sed -i "s|          einzelheitenHtml(e) +||" assets/karte.js
       node tools/statische-listen.mjs >/dev/null 2>&1'

# Diese eine trifft NUR die gestellte rote Lage — der Bestand hat heute keinen
# roten Eintrag, die statische Liste bleibt also unberuehrt und `--pruefen`
# gruen. Genau deshalb faellt hier nur der gemeinte Waechter.
# ⚠ UND DER ERSTE ANKER HIER TRAF ZWEIMAL. `if (!id) return "";` steht auch
# in `bewertungHtml` — `sed` ersetzte beide, `bewertungHtml` rief danach ein
# `PTKarte`, das es modulintern nicht gibt, und der Bau der statischen Liste
# starb. Gefangen war der Fall, aber die roten Zeilen trugen fremde Namen
# ("statische Liste ist auf dem Stand", "Fund der Woche"): gefangen aus dem
# falschen Grund. Gefunden hat es erst das Nachstellen von Hand.
# Sabotiert wird jetzt an der EINEN Stelle, an der der Knopf zusammengebaut
# wird, mit der dort schon vorhandenen lokalen Variablen — kein fremder
# Bezeichner, keine Nebenwirkung auf die statische Liste.
probe 'APPS: bei roter Ampel faellt auch der Weg zur eigenen Seite weg' \
      assets/karte.js \
      's|          einzelheitenHtml(e) +|          (gesperrt ? "" : einzelheitenHtml(e)) +|'

probe 'APPS: eine Einzelseite wandert in den Installations-Vorrat' \
      sw.js \
      's|  "apps/index.html",|  "apps/index.html",\n  "apps/markt-mixarium/index.html",|'

probe 'APPS: die Uebersicht faellt aus dem Installations-Vorrat' \
      sw.js \
      's|^  "apps/index.html",$||'

probe 'APPS: /apps/ faellt offline nicht mehr auf die Uebersicht zurueck' \
      sw.js \
      's|return h \|\| (istUebersicht ? caches.match("apps/index.html") : null);|return h;|'

# ══ DER BEFUND GEHT OHNE DIE FUNDWERTE HINAUS (Klaus 2026-09-21) ═══════════
#
# ⚠ DIESES WERKZEUG FINDET SCHLUESSEL — und gab sie bis zum 2026-09-21 mit dem
# Bericht heraus. Gemessen im echten Browser an der mitgelieferten Test-Datei:
# 6 von 6 Fundwerten standen im kopierten Text. Wer den Befund einer KI zeigt,
# schickte genau die Schluessel mit, die der Pruefer gerade gefunden hat.
#
# ⚠ UND ES SIND DREI STELLEN, NICHT EINE. Bericht, Textdatei und der Knopf an
# der einzelnen Stelle gehen in dieselbe Zwischenablage; jede bekommt ihren
# eigenen Fall, sonst faengt einer ueber den Nachbarn und belegt nicht, was sein
# Name behauptet.
probe 'VERDECKT: die rohe Quellzeile kommt wieder in den Bericht' \
      assets/pruefer-ui.js \
      's|bericht.push("  " + marke +|bericht.push("  " + marke + (s ? ": " + s : "") + "" +|'

probe 'VERDECKT: der Knopf an der einzelnen Stelle gibt wieder die rohe Zeile' \
      assets/pruefer-ui.js \
      's|? marke + ": " + verdeckteMarke(g.kennung)|? marke + ": " + (s \|\| x.satz)|'

# Eine stille Kuerzung ist die schlimmere Sorte: sie sieht aus wie
# Vollstaendigkeit. Der Bericht muss selbst sagen, dass die Werte fehlen.
probe 'VERDECKT: der Bericht sagt nicht mehr, dass die Werte fehlen' \
      assets/pruefer-ui.js \
      's|if (VERDECKT_AUF) bericht.push(verdecktHinweis());||'

# Ohne die Sorte ist die Marke ein leerer Platz: man weiss, dass dort etwas
# war, aber nicht was — und repariert nichts.
probe 'VERDECKT: die Marke nennt die Sorte des Fundes nicht mehr' \
      assets/pruefer-ui.js \
      's|" \\u00B7 " + (kennung \|\| "?") + "\\u27E7"|"\\u27E7"|'

# ══ ZWECK ZUERST, BAUWEISE DANACH ══════════════════════════════════════════
probe 'ZWECK: der Zweck-Satz faellt ganz weg' \
      auslieferungspruefer.html \
      's|<p class="pr-zweck" data-i18n-html="pr_zweck">|<p class="pr-zweck-aus" hidden>|'

# ⚠ DIE REIHENFOLGE IST DIE ZUSICHERUNG, nicht die Anwesenheit. Ein Zweck-Satz
# UNTER der Datenschutz-Zusage beantwortet die Frage wieder in der falschen
# Reihenfolge — und im Quelltext saehe beides gleich aus.
probe_befehl 'ZWECK: der Zweck steht wieder UNTER der Datenschutz-Zusage' \
      auslieferungspruefer.html \
      'python3 -c "
import io
p=\"auslieferungspruefer.html\"; s=io.open(p,encoding=\"utf-8\").read()
s=s.replace(\"<p class=\\\"pr-zweck\\\"\", \"<p style=\\\"order:9;position:relative;top:400px\\\" class=\\\"pr-zweck\\\"\",1)
io.open(p,\"w\",encoding=\"utf-8\").write(s)"'

probe 'ZWECK: die zwei Faelle vor der Bedienung fallen weg' \
      auslieferungspruefer.html \
      's|id="prWann"|id="prWann-aus"|'

# Ein deutscher Satz in einer englischen Oberflaeche ist die halb uebersetzte
# Tafel, gegen die netzweit alles gebaut ist.
probe 'ZWECK: der Zweck-Satz hat keine englische Fassung mehr' \
      assets/i18n-pruefer.js \
      's|"pr_zweck": "<strong>Before you put|"pr_zweck_aus": "<strong>Before you put|'

# ══ DER SATZ, DER SAGT WOFUER ══════════════════════════════════════════════
probe 'WOFUER: der Satz an den Mitnehm-Knoepfen faellt weg' \
      auslieferungspruefer.html \
      's|id="mitreiheWofuer"|id="mitreiheWofuer-aus"|'

# ⚠ EINE ZUSICHERUNG UEBER KNOEPFE, DIE MAN NICHT SIEHT, ist keine. Schaltet
# nur die Reihe, bleibt der Satz stehen, wenn die Knoepfe weg sind.
probe 'WOFUER: der Satz bleibt stehen, wenn die Knoepfe verschwinden' \
      assets/pruefer-ui.js \
      's|if (mitreiheWofuer) mitreiheWofuer.hidden = !ja;|if (mitreiheWofuer) mitreiheWofuer.hidden = false;|'

# ⚠ UND DER GESCHAERFTE pre-line-WAECHTER DARF NICHT LEERLAUFEN. Erkennt
# `wirdBeschrieben` gar nichts mehr, ist die Pruefung darueber immer gruen —
# eine Zusicherung, die von ihrem Fehlen nicht zu unterscheiden ist.
probe 'PRELINE: die Erkennung der Meldestellen laeuft leer' \
      tests/smoke.mjs \
      's|const wirdBeschrieben = (id) => {|const wirdBeschrieben = (id) => { if (1) return false;|'

# ⚠ `hidden` VERLIERT GEGEN `display` — ein VORBESTEHENDER Fehler, den ein
# Waechter fuer etwas anderes ans Licht gebracht hat. Ohne diese Regel stehen
# die zwei Mitnehm-Knoepfe schon beim Laden da und fuehren ins Nichts.
probe 'HIDDEN: die Regel gegen display faellt weg — Knoepfe stehen beim Laden da' \
      assets/style.css \
      's|^\[hidden\] { display: none !important; }|[hidden] { opacity: 0.99; }|'


# ──────────────────────────────────────────────────────────────────────────
# STUDIO: eine freigegebene App, die niemand sieht (Befund 2026-09-21)
#
# Bis zu diesem Tag konnte Klaus im Studio auf Veroeffentlichen druecken, der
# Server committete listings.js — und danach passierte NICHTS. Der naechtliche
# Lauf prueft VOR dem Commit; drei Waechter wurden rot (kein `seit`, keine
# Zeitachse, keine Detailseite), also wurde index.html nie geschrieben. Im
# Studio sah alles richtig aus.
#
# Jeder Fall hier trifft GENAU EINE Zusicherung.
echo "── STUDIO: der Weg von der Freigabe bis auf die Seite ──"

# ⚠ DIE WURZEL: das Bearbeiten ersetzte den Eintrag, statt die Formularfelder
# hineinzuschreiben. `text_en`, `seit`, `sichttest`, `eigenschaften`, `appUrl`
# fielen dabei still weg — an den gepflegtesten Eintraegen.
probe 'STUDIO: das Bearbeiten ersetzt den Eintrag wieder (Felder fallen weg)' \
      assets/studio.js \
      's|      var alt = WORK\[bearbeite\];|      var alt = WORK[bearbeite]; WORK[bearbeite] = e;|'

probe 'STUDIO: das Zusammenfuehren faellt aus — nur noch Kennung und Messung bleiben' \
      assets/studio.js \
      's|for (var f in e) if (Object.prototype.hasOwnProperty.call(e, f)) alt\[f\] = e\[f\];|for (var f in e) if (false) alt[f] = e[f];|'

# Ohne Formularfeld kann Klaus das Datum gar nicht eintragen — ein eigener
# Eintrag aus dem Studio waere per Bauart kaputt.
probe 'STUDIO: das Feld fuer `seit` faellt aus dem Formular' \
      assets/studio.js \
      "s|<input type=\"date\" data-f=\"seit\">|<input type=\"date\" data-f=\"entstanden\">|"

probe 'STUDIO: die Datums-Pflicht fuer eigene Eintraege faellt weg' \
      assets/studio.js \
      's|if (e.own \&\& !/\^\\d{4}-\\d{2}-\\d{2}\$/.test(e.seit)) {|if (false) {|'

probe 'STUDIO: ein neuer eigener Eintrag wartet nicht mehr sichtbar auf den Sichttest' \
      assets/studio.js \
      's|if (e.own) e.sichttest = "ausstehend";||'

# ⚠ DIE GEGENRICHTUNG: einer fremden App ein Datum andichten. `seit` ist der
# Tag der Repo-Anlage — der Tag der Uebernahme waere eine andere Zahl unter
# demselben Namen, und sie saehe aus wie eine nachgeschlagene.
probe 'STUDIO: der Uebernahme-Zweig erfindet ein `seit` fuer eine fremde App' \
      assets/studio.js \
      's|      sporeUrl: istHttps(it.sporeUrl) ? String(it.sporeUrl).trim() : ""|      sporeUrl: istHttps(it.sporeUrl) ? String(it.sporeUrl).trim() : "", seit: heuteOrt()|'

# ⚠ DER ARBEITSABLAUF: kein Lauf rief `detailseiten.mjs`. Die Seite einer neu
# freigegebenen App entstand nie, und die 27 vorhandenen drifteten auf alte
# Messwerte. Die Liste der Laeufe wird GEFUNDEN, nicht gepflegt — deshalb
# trifft ein Eingriff in EINEN Lauf den Waechter.
probe 'STUDIO: ein Arbeitsablauf baut die Detailseiten nicht mehr' \
      .github/workflows/messwerte-taeglich.yml \
      's|        run: node tools/detailseiten.mjs|        run: echo uebersprungen|'

probe 'STUDIO: ein Arbeitsablauf baut sie, committet sie aber nicht' \
      .github/workflows/eigenschaften-taeglich.yml \
      's|git add assets/config/listings.js index.html apps|git add assets/config/listings.js index.html|'

# ⚠ UND DIE REGEL SELBST. Am Bestand ist heute KEIN Eintrag undatiert — die
# zweite Haelfte der Zeitachse waere dort trivial wahr. Gemessen wird sie an
# gestellten Lagen; faellt eine davon weg, misst die Lockerung nichts mehr.
probe 'STUDIO: die Zeitachse laesst einen undatierten Eintrag ueberall stehen' \
      tests/smoke.mjs \
      's|vorgedraengt: l.filter((e, i) => i < letzter \&\& !IST_DATUM(e)).map((e) => e.label)|vorgedraengt: []|'

probe 'STUDIO: die Zeitachse beanstandet einen undatierten Eintrag am Ende' \
      tests/smoke.mjs \
      's|const letzter = l.map(IST_DATUM).lastIndexOf(true);|const letzter = l.length;|'


# ──────────────────────────────────────────────────────────────────────────
# SUCHE: das Suchfeld der Uebersicht (Klaus 2026-09-21)
#
# „ob ich da nicht eine semantische Suche schon einpflege, so wie bei der
# ersten Hauptseite auch?" — hier steht ein WORTFILTER ueber das, was ohnehin
# im Dokument steht, und daneben der Weg zur richtigen Suche. Die Waechter
# dazu leben in tests/smoke_detail.mjs und laufen als Kindprozess.
echo "── SUCHE: der Wortfilter und der Weg in den Marktplatz ──"

# ⚠ OHNE `action`/`method` taete Enter ohne JavaScript nichts — ein Feld, das
# ohne Skript nichts tut, ist ein toter Knopf mit Beschriftung.
probe_mehr 'SUCHE: das Formular verliert seinen Weg in den Marktplatz' \
      "tools/detailseiten.mjs apps/index.html" \
      'sed -i "s|<form class=\"app-suche\" action=\"../\" method=\"get\" role=\"search\">|<form class=\"app-suche\" role=\"search\">|" tools/detailseiten.mjs
       node tools/detailseiten.mjs >/dev/null 2>&1'

# ⛔ DIE TAFEL: der Filter nimmt nur weg. Baut das Werkzeug die Zeilen schon
# versteckt, haengt sichtbarer Inhalt an einem Skript.
probe_mehr 'SUCHE: die Uebersicht baut ihre Zeilen schon versteckt (Tafel gebrochen)' \
      "tools/detailseiten.mjs apps/index.html" \
      'python3 - <<"PYEOF"
# \u26a0 DER ANKER DARF KEIN ${...} TRAGEN. Die erste Fassung stand in einem
# UNZITIERTEN Heredoc — die Shell loeste ${esc(String(e.anchorId || ""))} vorher
# auf, der Anker traf nicht, die Datei blieb unveraendert, und `probe_mehr` hat
# keine Tote-Anker-Pruefung: gemeldet wurde BLIND. Ein toter Anker heisst "zieh
# den Fall nach", ein blinder Waechter "bau einen Waechter" — die weisen in
# entgegengesetzte Richtungen.
#
# `<li><a href="$` ist eindeutig: die Nachbarn-Liste der Detailseite schreibt
# `<li><a href="../$`.
p = "tools/detailseiten.mjs"
s = open(p, encoding="utf-8").read()
alt = chr(60) + "li" + chr(62) + chr(60) + "a href=" + chr(34) + "$"
assert s.count(alt) == 1, s.count(alt)
open(p, "w", encoding="utf-8").write(s.replace(alt, chr(60) + "li hidden" + chr(62) + chr(60) + "a href=" + chr(34) + "$", 1))
PYEOF
       node tools/detailseiten.mjs >/dev/null 2>&1'

# ⚠ EIN FILTER, DER ETWAS HAENGEN LAESST, versteckt Eintraege dauerhaft — und
# niemand sieht, dass sie fehlen.
probe 'SUCHE: ein geleertes Feld gibt die Liste nicht wieder frei' \
      assets/app-suche.js \
      's|var zeigen = !worte.length \|\| passt(i, worte);|var zeigen = worte.length \&\& passt(i, worte);|'

probe 'SUCHE: ein Bereich ohne Treffer bleibt als leere Ueberschrift stehen' \
      assets/app-suche.js \
      's|b.hidden = alle.length > 0 \&\& alle.every(function (li) { return li.hidden; });|b.hidden = false;|'

probe 'SUCHE: die Trefferzeile nennt keine Zahl mehr' \
      assets/app-suche.js \
      's|.replace("{n}", sichtbar).replace("{alle}", zeilen.length);|;|'

# ⚠ EINZEILIG ANSETZEN — `sed` sieht keine Zeilenumbrueche. Ein Ausdruck ueber
# zwei Zeilen aendert nichts und meldet sich als toter Anker.
probe 'SUCHE: Enter springt weg, statt hier zu filtern' \
      assets/app-suche.js \
      's|    ev.preventDefault();|    void 0;|'

probe 'SUCHE: die Umlaute werden nicht mehr aufgeloest — „kuche" findet nichts' \
      assets/app-suche.js \
      's|.replace(/ü/g, "ue")||'

# ⚠ UND DER MARKTPLATZ MUSS `?q=` LESEN. Sonst kommt der Besucher auf einer
# Seite an, die so tut, als haette sie nichts gehoert.
probe 'SUCHE: der Marktplatz liest ?q= nicht mehr' \
      assets/app.js \
      's|        zeichne(wortsuche(q.trim()));||'

# ⚠ UND ER DARF DABEI NICHT DIE 30-MB-BEDEUTUNGS-SUCHE ANWERFEN. Das waere
# eine Entscheidung ueber fremdes Datenvolumen, ungefragt aus einer Adresse.
probe 'SUCHE: ?q= wirft ungefragt das 30-MB-Modell an' \
      assets/app.js \
      's|        zeichne(wortsuche(q.trim()));|        if ($("semantisch")) $("semantisch").checked = true; zeichne(wortsuche(q.trim()));|'

# ⚠ UND DER LADEFEHLER-WAECHTER — dreimal an einem Tag hat ein deutsches Zitat
# in einem JS-String eine Datei unlauffaehig gemacht. Jedes Mal war die rote
# Zeile der Name eines Absturzes statt der einer Zusicherung.
probe_befehl 'LADEN: eine Skript-Datei wird unlauffaehig' \
      assets/app-suche.js \
      "printf '\nvar kaputt = \"offen;\n' >> assets/app-suche.js"

# ⚠ HIER STAND EINE SABOTAGE AM SELBST-RIEGEL (`> 10` → `>= 0`), und sie
# hat NICHTS gemessen: der Sammler fand weiter alle Dateien, die Zahl blieb
# über zehn, und beide Fassungen waren wahr. Der Fall meldete sich als BLIND,
# während der Wächter tadellos war.
#
# Gemeint ist der Fall, in dem der SAMMLER leerläuft — dann muss der
# Selbst-Riegel umfallen, denn sonst wäre „alle Dateien laden sauber" auch
# bei null Dateien grün. Sabotiert wird deshalb die Liste selbst.
probe 'LADEN: der Waechter findet gar keine Dateien mehr (laeuft leer)' \
      tests/smoke.mjs \
      "s|^  const dateien = \[$|  const dateien = []; const _weg = [|"



# ──────────────────────────────────────────────────────────────────────────
# SITEMAP: die Einladung an Google (S9, 2026-09-21)
#
# Die Seiten sind ab hier indexierbar, und die Sitemap wird GEBAUT. Beides
# kann still kaputtgehen: eine Sitemap, die hinterherhängt, lädt zu Adressen
# ein, die es nicht mehr gibt — und eine Seite, die wieder `noindex` trägt,
# fällt lautlos aus dem Index, ohne dass irgendwo eine Zeile rot wird.
echo "── SITEMAP: die Einladung an Google ──"

probe 'SITEMAP: die Sitemap haengt hinterher — eine Adresse fehlt' \
      sitemap.xml \
      's|<loc>https://pwa-toolpoint.de/apps/markt-mixarium/</loc>|<loc>https://pwa-toolpoint.de/apps/GIBTESNICHT/</loc>|'

# ⚠ DER NOINDEX-ZWEIG IST EINE ABSICHT (Impressum, Knotenkarte). Faellt er weg,
# steht eine Einladung und eine Absage zugleich in der Sitemap.
probe_mehr 'SITEMAP: eine noindex-Seite kommt in die Einladung' \
      "tools/sitemap-bauen.mjs sitemap.xml" \
      'sed -i "s|if (/\\\\bnoindex\\\\b/i.test(robots))|if (false)|" tools/sitemap-bauen.mjs
       node tools/sitemap-bauen.mjs >/dev/null 2>&1'

probe 'SITEMAP: ein fremdes Canonical faellt nicht mehr heraus' \
      tools/sitemap-bauen.mjs \
      's|if (can !== soll) return|if (false) return|'

# ⚠ „kein Canonical" und „noindex" verlangen das GEGENTEIL voneinander: das eine
# ist ein Mangel an der Seite, das andere eine Entscheidung. Wer sie zusammen-
# wirft, kann den Mangel nie melden.
probe 'SITEMAP: ein fehlendes Canonical wird als Absicht verbucht statt als Mangel' \
      tools/sitemap-bauen.mjs \
      "s|grund: 'kein-canonical'|grund: 'noindex'|"

# ⚠ DER FALL, OHNE DEN S9 VON SEINEM FEHLEN NICHT ZU UNTERSCHEIDEN WAERE.
probe 'SITEMAP: eine Detailseite traegt wieder noindex' \
      apps/markt-mixarium/index.html \
      's|<meta name="robots" content="index,follow|<meta name="robots" content="noindex,follow|'

probe 'SITEMAP: ein Arbeitsablauf baut die Sitemap nicht mehr' \
      .github/workflows/messwerte-taeglich.yml \
      's|        run: node tools/sitemap-bauen.mjs|        run: echo uebersprungen|'

probe 'SITEMAP: ein Arbeitsablauf baut sie, committet sie aber nicht' \
      .github/workflows/eigenschaften-taeglich.yml \
      's|index.html apps sitemap.xml|index.html apps|'

# ⚠ Lighthouse ist KEINE Nutzerbewertung. Sterne im Suchergebnis waeren der
# einzige Lohn und eine Luege in Maschinenschrift — Google ahndet das mit einer
# manuellen Massnahme.
probe 'SITEMAP: das JSON-LD traegt eine erfundene Bewertung' \
      apps/markt-mixarium/index.html \
      's|"operatingSystem":"Web"|"aggregateRating":{"@type":"AggregateRating","ratingValue":"4.8","ratingCount":"3"},"operatingSystem":"Web"|'

# ── VERWAIST: eine Seite in der Einladung und nirgendwo im Haus ──────────────
# Den Fund hat Klaus am 2026-09-22 gemacht, an family-projekt.de, und eine
# Ebene weiter getragen traf er auch hier: apps/index.html stand in der
# Sitemap und war von KEINER Seite verlinkt.

probe 'VERWAIST: der Link auf die Uebersicht /apps/ faellt weg' \
      index.html \
      's|<a class="alle-apps" href="apps/"|<a class="alle-apps" href="nirgendwo/"|'

# Die Gegenrichtung: ein EINZELNER Einzelheiten-Knopf faellt weg. Ohne diesen
# Fall waere „keine verwaiste Seite" auch dann gruen, wenn nur die Uebersicht
# verlinkt ist und keine der 27 Detailseiten.
probe 'VERWAIST: eine einzelne Detailseite wird nicht mehr verlinkt' \
      index.html \
      's|href="apps/eigen-sage/"|href="apps/GIBTESNICHT/"|'

# ── ANHANG: Anhänge und einzelne Dateien öffnen (2026-09-29) ─────────────────
# Klaus: „Ist das nicht dann dem Auslieferungsprüfer …?" — die Prüfung steht in
# assets/pruefer-anhang.js und wird byte-1:1 in den Sende-Prüfer kopiert.
echo "── ANHANG: Anhänge und einzelne Dateien öffnen ──"

probe "ANHANG: der Datei-Reiter fällt aus der Liste der Eingänge" \
      assets/pruefer-ui.js \
      's|"mail", "datei"\];|"mail"];|'

probe "ANHANG: die Anhänge einer Mail werden nicht mehr geöffnet" \
      assets/pruefer-ui.js \
      's|^    anhaengeOeffnen(inhalt, r, opt, danach);|    /* weg */|'

probe "ANHANG: „Kein Anhang wurde geöffnet“ bleibt stehen, obwohl geöffnet wurde" \
      assets/pruefer-ui.js \
      's|return h.replace(/⚠ Kein Anhang|return h; h.replace(/⚠ Kein Anhang|'

probe "ANHANG: der Text einer Datei geht nicht mehr durch den Text-Prüfer" \
      assets/pruefer-ui.js \
      's|if (r.text \&\& window.PrueferFormate) {|if (false) {|'

probe "ANHANG: ein spät fertiger Anhang überschreibt ein neueres Ergebnis" \
      assets/pruefer-ui.js \
      's|if (mein !== anhangLauf) return;|if (false) return;|'

probe "ANHANG: der Datei-Prüfer wird von der Seite nicht mehr geladen" \
      auslieferungspruefer.html \
      's|<script src="assets/pruefer-anhang.js?v=[0-9]*"></script>||'

probe "ANHANG: eine neue Kennung verliert ihren Klartext-Satz" \
      assets/pruefer-ui.js \
      's|    "SVG-SKRIPT": {|    "SVG-SKRIPT-ALT": {|'

probe "ANHANG: Daten hinter einem PNG werden nicht mehr gesucht" \
      assets/pruefer-anhang.js \
      's|else if (art === "png") anhaengsel(b, pngPruefen(b, melde), melde);|else if (art === "png") pngPruefen(b, melde);|'

probe "ANHANG: die Endung wird nicht mehr gegen den Dateikopf gehalten" \
      assets/pruefer-anhang.js \
      's|else if (ENDUNGEN\[art\] \&\& endung \&\& ENDUNGEN\[art\].indexOf(endung) < 0)|else if (false)|'

probe "ANHANG: die Grenze sagt nicht mehr, dass nichts ausgeführt wird" \
      auslieferungspruefer.html \
      's|Anhänge werden <em>gelesen</em>, nie ausgeführt|Anhänge werden <em>gelesen</em>|'

probe "ANHANG: GPS wird geraten statt im IFD0 gesucht" \
      assets/pruefer-anhang.js \
      's|        var gps = exifHatGps(b, i + 10, Math.min(i + 2 + len, b.length));|        var gps = true;|'

probe "ANHANG: ein SVG-Skript wird übersehen" \
      assets/pruefer-anhang.js \
      's|if (/<script\[\\s>\]/i.test(s)) melde|if (false) melde|'

probe "ANHANG: Makros in Office-Dateien werden übersehen" \
      assets/pruefer-anhang.js \
      's|    if (makro.length) melde("OFFICE-MAKRO"|    if (false) melde("OFFICE-MAKRO"|'

probe "ANHANG: gepackte Office-Teile werden nicht entpackt" \
      assets/pruefer-anhang.js \
      's|new welt.DecompressionStream("deflate-raw")|new welt.DecompressionStream("deflate")|'

probe "ANHANG: ein Programm wird nur an der Endung erkannt" \
      assets/pruefer-anhang.js \
      's|    if (b\[0\] === 0x4D \&\& b\[1\] === 0x5A) return "programm";||'

probe "ANHANG: der Umbruch vor der Grenze bleibt am Anhang hängen" \
      assets/pruefer-anhang.js \
      's|.replace(/\\r?\\n\$/, "")), tiefe + 1);|), tiefe + 1);|'

probe "ANHANG: ein RFC-2231-Name wird nicht entschlüsselt" \
      assets/pruefer-anhang.js \
      's|try { return decodeURIComponent(n); } catch|try { return n; } catch|'

probe "ANHANG: ein zu großer Anhang wird doch geöffnet" \
      assets/pruefer-anhang.js \
      's|if (geschaetzt > GROESSE_MAX) {|if (false) {|'

probe "ANHANG: ausMail findet keine Anhänge mehr" \
      assets/pruefer-anhang.js \
      's|      if (!name) return;|      return;|'

# ── SPRUNG: die Zahlen über den Befunden sind Links auf ihre Karte (2026-09-29)
echo "── SPRUNG: Zahlen springen zur Karte ──"

probe "SPRUNG: die Zahlen sind wieder nur Text" \
      assets/pruefer-ui.js \
      's|      var a = t("a", klasse + " pr-sprung", text);|      return t("span", klasse, text); var a;|'

probe "SPRUNG: die Karte trägt keine Kennung, der Link führt ins Leere" \
      assets/pruefer-ui.js \
      's|      li.id = "pr-g-" + gi;||'

probe "SPRUNG: ein zweiter Tipp bleibt auf derselben Karte" \
      assets/pruefer-ui.js \
      's|        n = (n + 1) % ziele.length;|        n = 0;|'

probe "SPRUNG: eine N×-Zahl führt auf eine Karte fremder Art" \
      assets/pruefer-ui.js \
      's|      summe.appendChild(sprung("pr-zahl", kartenJe\[k\].length + "× " + etikett, kartenJe\[k\]));|      summe.appendChild(sprung("pr-zahl", kartenJe[k].length + "× " + etikett, kartenJe[k].map(function (x) { return (x + 1) % gruppen.length; })));|'

# ══ PDFTEXT: Stufe 2 D, der Seitentext eines PDFs (2026-09-29) ══
probe "PDFTEXT: pdf.js läuft wieder MIT eval (CVE-2024-4367)" \
      assets/pruefer-anhang.js \
      's|isEvalSupported: false|isEvalSupported: true|'
probe "PDFTEXT: die KI-Anweisung im Seitentext wird nicht mehr gemeldet" \
      assets/pruefer-anhang.js \
      's|if (st.kennung !== "KI-ANWEISUNG") return;|return;|'
probe "PDFTEXT: der Fund nennt seine Seite nicht mehr" \
      assets/pruefer-anhang.js \
      's| (Seite " + x.seite + ", Zeile | (Zeile |'
probe "PDFTEXT: Seiten ohne Textebene werden verschwiegen" \
      assets/pruefer-anhang.js \
      's|if (leer.length) hinweise.push(|if (false) hinweise.push(|'
probe "PDFTEXT: über der Seiten-Grenze wird still abgeschnitten" \
      assets/pruefer-anhang.js \
      's|if (r.alle > r.seiten.length) hinweise.push(|if (false) hinweise.push(|'
probe "PDFTEXT: ein nicht lesbares PDF heißt nicht mehr ungeprüft" \
      assets/pruefer-anhang.js \
      's|var grund = /password/|return null; var grund = /password/|'
probe "PDFTEXT: fehlt die KI-Liste, steht nichts da" \
      assets/pruefer-anhang.js \
      's|if (!PM) hinweise.push(|if (!PM) void (|'
probe "PDFTEXT: es steht nicht mehr da, wie viele Seiten gelesen wurden" \
      assets/pruefer-anhang.js \
      's|hinweise.push("Seitentext gelesen: "|void ("Seitentext gelesen: "|'
probe "PDFTEXT: die App nennt die Seite eines Text-Funds nicht mehr" \
      assets/pruefer-ui.js \
      's|", Seite " + sx.seite + (x.zeile|(x.zeile|'
probe "PDFTEXT: die App sagt dem Prüfer nicht, wo pdf.js liegt" \
      assets/pruefer-ui.js \
      's|window.PrueferAnhang.pfade({ pdfjs:|window.PrueferAnhang.pfade({ nix:|'

# ══ VORLAGEN: Klaus' Befunde an den Testvorlagen (2026-09-30) ══
probe "VORLAGEN: eine Textdatei wird wieder nicht als Text geprüft" \
      assets/pruefer-anhang.js \
      's|else if (art === "text") text = |else if (false) text = |'
probe "VORLAGEN: ein Namensraum (xmlns) gilt wieder als fremde Adresse" \
      assets/pruefer-formate.js \
      's|if (NAMENSRAUM_WIRTE\[wirt\] .. VOR_XMLNS.test(zeile.slice(0, am.index))) continue;|if (false) continue;|'
probe "VORLAGEN: ein JPEG im PDF-Eingang ist wieder ein sauberes PDF" \
      assets/pruefer-ui.js \
      's|if (String.fromCharCode.apply(null, kopf) !== "%PDF-") {|if (false) {|'
probe "VORLAGEN: der PDF-Eingang liest den Seitentext wieder nicht" \
      assets/pruefer-ui.js \
      's|window.PrueferAnhang ? window.PrueferAnhang.pruefe(f.name, bytes)|false ? window.PrueferAnhang.pruefe(f.name, bytes)|'

# ══ ALLEIN: der Prüfer hängt nicht an Workflow PDF (Klaus 2026-09-30) ══
probe "ALLEIN: die Seite holt pdf.js wieder aus ../Workflow-PDF/" \
      assets/pruefer-ui.js \
      's|new URL("vendor/pdfjs/", location.href)|new URL("../Workflow-PDF/vendor/pdfjs/", location.href)|'
probe "ALLEIN: pdf.js im eigenen Ordner ist verändert" \
      vendor/pdfjs/pdf.min.js \
      '1s|^|/* x */|'
probe "ALLEIN: ein PDF im HTML-Eingang landet wieder als HTML im Quelltext" \
      assets/pruefer-ui.js \
      's|if (pdf .. binaer) {|if (false) {|'

# ══ OCR: Text im Bild lesen (Stufe 2 A, 2026-09-30) ══
probe "OCR: ein Bild geht wieder nicht durch die Texterkennung" \
      assets/pruefer-anhang.js \
      's|if (/^(png.jpeg.webp.gif)$/.test(art)) weiter = weiter.then|if (false) weiter = weiter.then|'
probe "OCR: eine Anweisung im Bild wird nicht mehr gemeldet" \
      assets/pruefer-anhang.js \
      's|melde("BILD-KI-ANWEISUNG", st.satz|void ("BILD-KI-ANWEISUNG", st.satz|'
probe "OCR: nichts gelesen heisst wieder sauber statt ungeprüft" \
      assets/pruefer-anhang.js \
      's|      if (!r.zeilen.length) {$|      if (!r.zeilen.length) { return null;|'
probe "OCR: unsichere Zeilen zählen wieder mit" \
      assets/pruefer-anhang.js \
      's|if (!(li.confidence >= OCR_SICHER)) { unsicher++; return; }|if (false) { unsicher++; return; }|'
probe "OCR: gescannte PDF-Seiten werden nicht mehr gelesen" \
      assets/pruefer-anhang.js \
      's|return scanSeitenLesen(r.doc, leer, melde, hinweise, stand).then|return Promise.resolve({ seiten: [] }).then|'
probe "OCR: die Anzeige sagt wieder kein Befund statt ungeprüft" \
      assets/pruefer-ui.js \
      's|var ungeprueft = !treffer.length .. !opt.erwartet .. !!opt.ungeprueft;|var ungeprueft = false;|'
probe "OCR: die Stelle nennt nicht mehr Bildtext" \
      assets/pruefer-ui.js \
      's|(r.textQuelle === "bild" ? ", Bildtext Zeile " : ", Textzeile ")|", Textzeile "|'

# ══ BLASS: blasser Text im Bild (Stufe 2 B, 2026-09-30) ══
probe "BLASS: der zweite Lesedurchgang fällt still weg" \
      assets/pruefer-anhang.js \
      's|var z2 = gestreckt(quelle),|var z2 = null,|'
probe "BLASS: die Kontrast-Spreizung tut nichts mehr" \
      assets/pruefer-anhang.js \
      's|var g = 255 - Math.min(255, Math.max(0, p - grau.j.) . KONTRAST_VERST);|var g = grau[j];|'
probe "BLASS: der Befund sagt nicht mehr blass" \
      assets/pruefer-anhang.js \
      's|" (blass, erst nach Kontrast-Spreizung lesbar: Bildtext Zeile "|" (Bildtext Zeile "|'
probe "BLASS: jede Zeile des zweiten Durchgangs gilt als blass" \
      assets/pruefer-anhang.js \
      's|return ws.filter(function (w) { return bekannt.w.; }).length . 2 < ws.length;|return true;|'
probe "BLASS: der zweite Durchgang bekommt eine eigene Frist" \
      assets/pruefer-anhang.js \
      's|bildLesen(z2, bis)|bildLesen(z2)|'
probe "BLASS: ein Ausfall des zweiten Durchgangs wird verschwiegen" \
      assets/pruefer-anhang.js \
      's|if (r2.fehlt) hinweise.push(|if (false) hinweise.push(|'

# ══ VERSTECKT: unsichtbarer Text im PDF (Stufe 2 E, 2026-09-30) ══
# Keine Fälle für „die Tinte sieht nirgends Schrift" und „winzige Schrift zählt
# als sichtbar": der erste greift nur, wo die Texterkennung SICHTBAREN Text
# übersieht (in keiner Probe-PDF), der zweite wird in 0D vom Weiß gedeckt.
probe "VERSTECKT: die Textebene wird nicht mehr gegen das Seitenbild gelesen" \
      assets/pruefer-anhang.js \
      's|var mitText = seiten.filter(function (x) { return x.text; }).map|var mitText = [].filter(function (x) { return x.text; }).map|'
probe "VERSTECKT: der Befund wird nicht mehr gemeldet" \
      assets/pruefer-anhang.js \
      's|if (v.versteckt.length >= GEGEN_MIN_VERSTECKT)|if (false)|'
probe "VERSTECKT: die Tinten-Prüfung sieht überall Schrift" \
      assets/pruefer-anhang.js \
      's|return hi - lo >= GEGEN_TINTE;|return true;|'
probe "VERSTECKT: ein Wort, das einmal sichtbar steht, gilt trotzdem als versteckt" \
      assets/pruefer-anhang.js \
      's|da.every(function (x) { return !tinte(x); })|da.some(function (x) { return !tinte(x); })|'
probe "VERSTECKT: hinter Seite 10 wird still nicht gegengelesen" \
      assets/pruefer-anhang.js \
      's|if (gesamt > GEGEN_SEITEN_MAX) hinweise.push(|if (false) hinweise.push(|'
probe "VERSTECKT: die Seitengrenze fällt weg" \
      assets/pruefer-anhang.js \
      's|return n <= GEGEN_SEITEN_MAX; });|return true; });|'
probe "VERSTECKT: eine hängende Texterkennung wird verschwiegen" \
      assets/pruefer-anhang.js \
      's|hinweise.push("Textebene NICHT gegengelesen auf Seite "|void ("Textebene NICHT gegengelesen auf Seite "|'
probe "VERSTECKT: der PDF-Eingang lässt den Befund wieder weg" \
      assets/pruefer-ui.js \
      's# .. b.kennung === "PDF-VERSTECKTER-TEXT"; })#; })#'

# ══ HTMLANH: HTML-Anhänge (2026-09-30) ══
probe "HTMLANH: eine HTML-Datei wird nicht mehr als HTML-Seite erkannt" \
      assets/pruefer-anhang.js \
      's|test(anf)) return "html";|test(anf)) return "unbekannt";|'
probe "HTMLANH: der HTML-Prüfer wird für den Anhang nicht gefragt" \
      assets/pruefer-anhang.js \
      's|else if (art === "html") text = htmlPruefen(b, melde, hinweise, stand);|else if (art === "html") text = "";|'
probe "HTMLANH: fremde Adressen werden aus dem Ergebnis nicht übernommen" \
      assets/pruefer-anhang.js \
      's|var HTML_UEBERNOMMEN = \["FREMDE-ADRESSE"\];|var HTML_UEBERNOMMEN = [];|'
probe "HTMLANH: jede Art des Webseiten-Prüfers wird übernommen (Fehlalarm bei harmlosen Seiten)" \
      assets/pruefer-anhang.js \
      's|if (HTML_UEBERNOMMEN.indexOf(x.kennung) >= 0) melde|melde|'
probe "HTMLANH: fehlt pruefer.js, heißt die Seite still sauber" \
      assets/pruefer-anhang.js \
      's|hinweise.push("Der HTML-Prüfer (assets/pruefer.js) ist nicht geladen|void ("Der HTML-Prüfer (assets/pruefer.js) ist nicht geladen|'
probe "HTMLANH: der Quelltext statt des sichtbaren Textes geht weiter (Linkziele als Adresse)" \
      assets/pruefer-anhang.js \
      's|return entitaeten(sichtbar)|return t; entitaeten(sichtbar)|'
probe "HTMLANH: fehlt pruefer.js, steht oben wieder „Text im Bild ungeprüft“" \
      assets/pruefer-ui.js \
      's|ungeprueftSatz: r.art === "html" ? "HTML-Seite ungeprüft" : "",|ungeprueftSatz: "",|'
# START (2026-10-01): die Startseite „Was die App kann"
probe "START: index.html springt wieder direkt in den Prüfer" index.html \
  's|localStorage.getItem("auslieferungspruefer_start_v1") !== "1"|false|'
probe "START: der Haken merkt sich nichts mehr" start.html \
  's|if (h.checked) localStorage.setItem(K, "1");|if (false) localStorage.setItem(K, "1");|'
probe "START: ein Fund ohne Schritte" start.html \
  's|<ol><li>Nicht öffnen, nicht weiterleiten.</li><li>Die Mail löschen.</li><li>Beim Absender auf anderem Weg nachfragen.</li></ol>|<ol><li>Nicht öffnen.</li></ol>|'
probe "START: deutsche Wörter in der englischen Fassung" start.html \
  's|<li>Delete the email.</li>|<li>Die Mail löschen und nicht weiterleiten.</li>|'
probe "START: der Überblick fehlt in der Kopfleiste" auslieferungspruefer.html \
  's|id="ueberblickKnopf" href="start.html"|id="ueberblickKnopf" href="handbuch.html"|'
probe "START: ?adresse= landet auf der Startseite" index.html \
  's|if (!location.search \&\& |if (|'

# ══ VERDACHT: versteckte Botschaft in Bildpunkten (Stufe 2 C, 2026-10-01) ══
probe "VERDACHT: der Längenkopf wird nicht mehr gelesen" \
      assets/pruefer-anhang.js \
      's|if (t \&\& lsbTextOk(t)) { funde.push|if (false) { funde.push|'
probe "VERDACHT: ein Lauf druckbarer Zeichen zählt nicht mehr" \
      assets/pruefer-anhang.js \
      's|if (r >= VERDACHT_MIN_LAUF) funde.push|if (false) funde.push|'
probe "VERDACHT: jedes Byte gilt als druckbar (Fehlalarm bei weißen Bildern)" \
      assets/pruefer-anhang.js \
      's|function lsbDruckbar(x) { return x === 9|function lsbDruckbar(x) { return true \|\| x === 9|'
probe "VERDACHT: ein JPEG heißt wieder kein Verdacht statt nicht geprüft" \
      assets/pruefer-anhang.js \
      's|if (art === "jpeg") return Promise.resolve(aus(false,|if (art === "jpeg") return Promise.resolve(aus(true,|'
probe "VERDACHT: die Anweisung im versteckten Text wird nicht mehr erkannt" \
      assets/pruefer-anhang.js \
      's|if (st.kennung === "KI-ANWEISUNG") melde("BILD-KI-ANWEISUNG"|if (false) melde("BILD-KI-ANWEISUNG"|'
probe "VERDACHT: die Suche läuft ohne Knopf bei jeder Prüfung" \
      assets/pruefer-ui.js \
      's|    ergebnis.appendChild(box);$|    ergebnis.appendChild(box); knopf.click();|'
probe "VERDACHT: der Knopf erscheint auch ohne Bild" \
      assets/pruefer-ui.js \
      's|    if (!bilder.length) return;$|    if (!bilder.length) bilder = dateien;|'
probe "VERDACHT: das Ergebnis heißt wieder gefunden statt Verdacht" \
      assets/pruefer-ui.js \
      's|(lage === "ja" ? "Verdacht auf versteckte Daten in Bildpunkten"|(lage === "ja" ? "versteckte Botschaft gefunden"|'

# ══ WAS JETZT TUN (Klaus 2026-10-01) — ruhige Schritte bei Verdacht und Anweisung
probe "WASTUN: der Kasten fehlt an den Befund-Karten" \
      assets/pruefer-ui.js \
      's|      if (ruhe) li.appendChild(ruhe);$|      if (false) li.appendChild(ruhe);|'
probe "WASTUN: der Kasten fehlt beim Verdacht in Bildpunkten" \
      assets/pruefer-ui.js \
      's|if (lage === "ja") { var ruhe = wasTunKasten|if (false) { var ruhe = wasTunKasten|'
probe "WASTUN: der Kasten steht auch an Karten ohne Verdacht" \
      assets/pruefer-ui.js \
      's|var A = window.PrueferAnhang, schritte = A \&\& A.wasTun ? A.wasTun(kennung) : \[\];|var A = window.PrueferAnhang, schritte = A \&\& A.wasTun ? A.wasTun("KI-ANWEISUNG") : [];|'
probe "WASTUN: die Anweisung im Bild hat keine Schritte mehr" \
      assets/pruefer-anhang.js \
      's|    "BILD-KI-ANWEISUNG": RUHE_KI,|    "BILD-KI-ANWEISUNG": [],|'
probe "WASTUN: die Überschrift steht wieder doppelt" \
      assets/pruefer-anhang.js \
      's|melde("BILD-LSB-VERDACHT", "In den untersten Bits (|melde("BILD-LSB-VERDACHT", "Verdacht auf versteckte Daten in Bildpunkten: in den untersten Bits (|'

# ══ DIE STELLE IM BILD (Klaus 2026-10-01) — rot markiert, als Kopie
probe "MARKE: die Anweisung im Bild trägt keinen Kasten mehr" \
      assets/pruefer-anhang.js \
      's|"Bildtext Zeile " + st.zeile + ")", boxen ? boxen\[st.zeile - 1\] : null);|"Bildtext Zeile " + st.zeile + ")", null);|'
probe "MARKE: der Kasten zeigt auf die falsche Zeile" \
      assets/pruefer-anhang.js \
      's|boxen ? boxen\[st.zeile - 1\] : null);|boxen ? boxen[0] : null);|'
probe "MARKE: die Datei-Prüfung zeigt das markierte Bild nicht" \
      assets/pruefer-ui.js \
      's|      markiertZeigen(ergebnis, f.name, bytes, r.befunde);|      void 0;|'
probe "MARKE: der Verdacht zeigt das markierte Bild nicht" \
      assets/pruefer-ui.js \
      's|          if (lage === "ja") return markiertZeigen(li, x.name, x.bytes, r.befunde);||'
probe "MARKE: dieselbe Stelle wird doppelt markiert" \
      assets/pruefer-anhang.js \
      's|      if (gesehen\[k\]) return;  |      if (false) return;  |'
probe "MARKE: ohne Rand, nur Beschriftung" \
      assets/pruefer-anhang.js \
      's|g.lineWidth = dick; g.strokeStyle = "#d61e1e"; g.strokeRect|g.lineWidth = dick; g.strokeStyle = "#d61e1e"; void|'

# ══ TESTDATEI: zwei Test-Dateien zum Anklicken (Klaus 2026-10-01) ══
probe "TESTDATEI: der Kasten fehlt" \
      auslieferungspruefer.html \
      's|<div class="pr-test" data-test-dateien>|<div class="pr-test">|'
probe "TESTDATEI: der Knopf holt die Datei, prüft sie aber nicht" \
      assets/pruefer-ui.js \
      's|        dateiPruefen(new File(\[b\], name|        void (new File([b], name|'
probe "TESTDATEI: das Ergebnis sagt nicht mehr, dass es eine Test-Datei ist" \
      assets/pruefer-ui.js \
      's|"🧪 Das ist eine mitgelieferte Test-Datei — |"|'
probe "TESTDATEI: der Bild-Knopf zeigt auf eine Datei, die es nicht gibt" \
      auslieferungspruefer.html \
      's|data-test-datei="beispiele/Testbild-versteckte-Anweisung.png"|data-test-datei="beispiele/fehlt.png"|'

echo "$gruen Wächter schlagen an, $rot blind, $tot tote Anker — $marktplatz Marktplatz-Fälle nicht gefahren" \
     "${NUR_FALL:+— $uebersprungen Fälle ausgelassen (NUR_FALL=\"$NUR_FALL\"), das ist KEIN voller Lauf}"
[ "$rot" -eq 0 ] || exit 1
