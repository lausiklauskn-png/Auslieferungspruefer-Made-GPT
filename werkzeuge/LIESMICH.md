# Auslieferungsprüfer

Sucht in einer HTML-Seite nach dem, was vor der Auslieferung nicht drin sein
sollte — zeilengenau, ohne Netz, ohne Installation.

> **Es gibt ihn zweimal, und das ist Absicht.** Diese Python-Fassung ist für die
> **Prüfkette**: sie nimmt mehrere Dateien, gibt 0 oder 1 zurück und lässt sich
> in ein Skript hängen. Daneben steht seit dem 2026-08-21 eine
> **Browser-Fassung** unter <https://pwa-toolpoint.de/auslieferungspruefer.html>
> — für den Fall, dass jemand eine einzelne Seite prüfen will und kein Python
> hat. Sie ist im Marktplatz eingetragen.
>
> **Beide müssen dasselbe sagen.** Zwei Fassungen, die auseinanderlaufen, sind
> schlimmer als eine: man glaubt irgendwann der falschen.
> `PWA-Toolpoint/tests/smoke_pruefer.mjs` ruft **diese Datei hier** auf und
> vergleicht sie Zeile für Zeile mit der Browser-Fassung — an der Köderseite und
> an vier echten Seiten. Wer hier etwas ändert, ändert es dort mit, sonst wird
> die Probe zu Recht rot.

```bash
python3 pruefe-seite.py meineseite.html
python3 pruefe-seite.py *.html --erlaubt meine-domain.de
```

Rückgabewert **0 = sauber**, **1 = Befunde**, 2 = Aufruffehler. Damit lässt er
sich in eine Prüfkette hängen.

> `| tail` ist zum Lesen da, nicht zum Urteilen — hinter einer Pipe bekommst du
> den Rückgabewert von `tail`, nicht den des Prüfers.

## Der zweite Prüfer: Text, JSON, Konfiguration

**`pruefe-seite.py` ist ein HTML-Leser.** Auf einer JSON-Datei feuert kein
einziges Tag — sie geht als sauber durch, und der einzige Fund wäre
„keine Sprache angegeben".

**Das ist keine graue Theorie.** Am 2026-08-22 lagen 75 Rechnungen als JSON
unter einer öffentlichen Adresse, obwohl das Depot privat stand. Genau diese
Datei hätte der HTML-Prüfer durchgewinkt.

```bash
python3 pruefe-datei.py belege.json
python3 pruefe-datei.py --ordner ~/mein-repo      # den ganzen Baum durchsehen
python3 pruefe-datei.py --ordner . --erlaubt meine-domain.de
```

| Kennung | Was gefunden wurde |
|---|---|
| `SCHLUESSEL` | `sk-ant-…` · `sk-…` · `ghp_…` · `github_pat_…` · `AIza…` · `AKIA…` · `xox?-…` · `nsec1…` · `-----BEGIN … PRIVATE KEY-----` · ein Feld namens `api_key`/`secret`/`password` mit Wert · `Authorization: Bearer …` |
| `PERSONENBEZUG` | Mailadresse · Telefonnummer **mit Ländervorwahl** · IBAN **mit stimmender Prüfziffer** |
| `RECHNUNGSDATEN` | Felder wie `betrag`, `rechnungsnummer`, `kundennummer` · Beträge mit Währung |
| `FREMDE-ADRESSE` | eine nackte `http(s)://`-Adresse |
| `FUELLTEXT` | dieselbe Wortliste wie oben — sie wird aus `pruefe-seite.py` **geholt**, nicht abgeschrieben |

**Der Ordner-Gang ist der eigentliche Zweck.** Die Browser-Fassung kann immer
nur eine Datei. Vor dem Veröffentlichen will man den ganzen Baum wissen — und
dafür ist die Kommandozeile da. `.git`, `node_modules` und `__pycache__` werden
übersprungen; wer sie will, nennt den Pfad ausdrücklich.

### Die Freistellung geht über den PFAD, nie über den WERT

Neunzehn von Klaus' Seiten tragen ein `impressum.html` mit echter Anschrift und
echter Mailadresse. Die **müssen** dort stehen (§ 5 DDG). Ein Prüfer, der bei
jedem Lauf Alarm schlägt, wird abgeschaltet — und meldet dann auch den echten
Fund nicht mehr.

Freigestellt sind deshalb **Pfade** (`impressum.html`, `datenschutz.html`,
`RECHTE.md`, `LICENSE`). Würde man den **Wert** freistellen („diese Mailadresse
ist in Ordnung"), schwiege dieselbe Adresse auch dort, wo sie versehentlich
steht — in einer Konfiguration, in einem Protokoll, in einem Datenauszug. Genau
die ist der echte Fund.

**Und die Freistellung gilt nur für den Personenbezug, nie für einen Schlüssel.**
In einem Impressum gehört eine Anschrift; ein Zugangsschlüssel gehört dort so
wenig hin wie anderswo. Eine Freistellung, die auch Schlüssel mitnimmt, wäre
eine Hintertür mit Dateinamen. Beide Richtungen sind in
`PWA-Toolpoint/tests/smoke_pruefer.mjs` bewacht.

### Warum die IBAN nachgerechnet wird

Die Form allein — zwei Buchstaben, zwei Ziffern, dann Zeichen — trifft auch
Bestellnummern und Kennungen. Mit der Prüfziffer nach ISO 7064 bleibt fast nur
eine echte IBAN übrig. **Ein Muster ohne diese Rechnung wäre ein Fehlalarm-Werk**,
und ein Prüfer, der auf jeder Datei etwas meldet, wird weggeklickt.

Aus demselben Grund braucht eine Telefonnummer eine **Ländervorwahl** oder ein
`tel:`. Eine blosse Ziffernfolge als Telefonnummer zu lesen meldet jede Kennung
und jeden Zeitstempel in einer JSON-Datei. Lieber eine Nummer ohne Vorwahl
übersehen als jede Datei mit Zahlen anklagen.

### Was dieser Prüfer NICHT kann

- **Er versteht die Datei nicht.** Er liest Zeilen und sucht Muster. Ob ein
  Schlüssel echt oder abgelaufen ist, weiß er nicht.
- **Er kennt nur die Muster, die er kennt.** Ein hausgemachtes Schlüsselformat
  fällt durch. „Kein Befund" heißt nie „sicher".
- **Er entscheidet nicht, ob die Datei ausgeliefert werden soll.** Das tut ein
  Mensch. Er sagt nur, was drinsteht.
- **Binärdateien überspringt er.** Sie zählen als *nicht lesbar*, nicht als
  sauber — und die Schlusszeile sagt, wie viele es waren.

---

## Was er meldet

| Kennung | Was gefunden wurde | Warum es zählt |
|---|---|---|
| `FREMDE-ADRESSE` | `src` · `srcset` · `poster` · `data` · `action` · `content` (nur bei og:image und Verwandten) · `href` **nur bei `<link>` und `<base>`** · `style="…url()"` · `url()` und `@import` in `<style>` | Die Seite holt etwas von einem fremden Rechner. Das kostet Ladezeit, es geht offline nicht, und der fremde Rechner sieht jeden Besucher. Betrifft auch `preload` und `preconnect` — die fallen beim Aufräumen am häufigsten durch. |
| `FUELLTEXT` | Reste aus der Bauzeit: `Lorem ipsum`, `TODO`, `Platzhalter`, `Max Mustermann`, `example.com`, `Ihre Firma` … | Ausgeliefert wirkt so etwas nicht wie ein Versehen, sondern wie Nachlässigkeit. |
| `BILD-OHNE-ALT` | `<img>` ganz ohne `alt` | Für ein Vorleseprogramm ist das Bild dann nicht vorhanden. |
| `LEERER-LINK` | `<a>` ohne `href`, mit `href=""`, `href="#"` oder `href="javascript:void(0)"` | Ein Knopf, der nichts tut. |
| `KEINE-SPRACHE` | `<html>` ohne `lang` | Vorleseprogramme raten dann die Sprache und sprechen Deutsch englisch aus. |

**Ein `<a href="https://…">` ist kein Befund.** Bei `<link>` *holt* die Seite
etwas; bei `<a>` geht der Besucher weg, wenn er klickt. Das ist ein ganz normaler
Link. An Klaus' echten Seiten gemessen waren **27 von 58** Meldungen genau solche
Links — eine Warnung, die man nicht mehr los wird, ist keine Warnung.

`alt=""` ist **kein** Befund. Ein leeres `alt` ist die richtige Angabe für ein
rein schmückendes Bild — es sagt dem Vorleseprogramm „überspringen". Fehlt das
Attribut ganz, sagt es gar nichts.

## Die Wortliste: zwei Wörter gemessen, achtzehn aus Erfahrung

Am 2026-08-20 lief der Prüfer über acht von Klaus' echten Seiten. Zwei
naheliegende Wörter sind daraufhin **wieder herausgeflogen**:

| Wort | Treffer | was es wirklich war |
|---|---|---|
| `placeholder` | 32 | das gültige HTML-Attribut `placeholder="…"` |
| `platzhalter` | 24 | ein gewöhnliches deutsches Wort im Quelltext |

Außerdem wird auf **Wortgrenze** gesucht, nicht als Teilzeichenkette: `tbd`
meldete sonst die Knopf-Kennung `tbDark`.

**Was danach übrig blieb, war echt.** Acht große Seiten, sechs Befunde: zweimal
`cdn.jsdelivr.net` (Kim-Bell und Kimseek laden `eruda` nach, obwohl ihre eigene
Verfassung „keine CDNs, offline-first" sagt), zweimal Fülltext, und die eigene
Domain in einer Seite, die sie nicht freigegeben hatte.

### Wie viel wirklich gemessen ist

**Zwei von zwanzig — also neunzig Prozent der Liste sind nicht gemessen.**
Auf denselben acht Seiten kam vor:

| Wort | Treffer |
|---|---|
| `example.com` | 1 |
| `ihre firma` | 1 |
| alle achtzehn anderen | **0** |

Die achtzehn stehen **vorsorglich** darin — sie stammen aus Erfahrung, nicht aus
einer Messung an diesen Seiten. Das ist ein Unterschied, und er gehört
hingeschrieben: eine Liste, die man für geprüft hält, wird nicht mehr
hinterfragt. *(Sten hat in der Gegenprüfung vom 2026-08-20 genau danach gefragt
— die Aussage „geeicht" wirkte präziser, als sie war.)*

**Beide gemessenen Treffer waren Formular-Hinweise** (`placeholder="du@example.com"`,
`placeholder="Ihr Name oder Ihre Firma"`) — also die Unschärfe aus dem nächsten
Absatz, nicht der Fall, für den die Liste gedacht ist.

### Die eine Unschärfe, die bleibt

Ein Formular-Hinweis darf ein Beispiel enthalten: `placeholder="du@example.com"`,
`placeholder="Ihr Name oder Ihre Firma"`. Der Prüfer meldet das trotzdem — er
sieht ein Wort aus der Liste und weiß nicht, dass es hier hingehört. Zwei
Treffer auf acht Seiten. **Das wird bewusst nicht ausgeblendet:** eine Ausnahme
für `placeholder="…"` würde auch einen echten Rest verstecken, der zufällig
dort steht.

## Die Köderseite — der eigentliche Punkt

`koeder.html` ist absichtlich kaputt und löst **jede Befundart genau einmal**
aus. Daneben stehen **Gegenproben, die NICHT anschlagen dürfen** — ein Bild mit
richtiger Beschreibung, ein Bild mit `alt=""`, ein Link mit echtem Ziel. Sie sind
der stillere Teil der Probe: eine Zahl, die zu hoch ist, fällt genauso auf wie
eine, die zu niedrig ist.

Wer den Prüfer ändert, lässt ihn darüber laufen:

```bash
python3 pruefe-seite.py koeder.html      # erwartet: 5 Befunde, Rückgabewert 1
```

Kommen nicht alle fünf zurück, ist **der Prüfer kaputt, nicht die Seite.**

Das ist kein Zierat. Ein Prüfer ohne Gegenprobe ist nur ein grüner Haken: er
meldet „sauber", und niemand weiß, ob er überhaupt hingesehen hat. Beim Bau hat
die Köderseite sofort einen Fehler gezeigt — eine Anmerkung im Quelltext enthielt
das Wort, das sie beschrieb, und zählte dadurch als sechster Befund.

**Was die Köderseite nicht abdeckt:** sie löst je Art *einen* Fall aus. Die
selteneren Wege zu einer fremden Adresse — `srcset` mit mehreren Bildern,
`@import` im Stilblock, `style="…url()"` am Element, protokoll-relative
Adressen (`//host/…`) — prüft die Probe im Werkstatt-Repo
(`tests/smoke_pruefer.mjs`), nicht diese Datei.

## Was dieser Prüfer NICHT kann

Der wichtigere Abschnitt. Wer ihn überspringt, hält „sauber" für mehr, als es ist.

1. **Er führt kein JavaScript aus.** Was erst zur Laufzeit nachgeladen wird —
   ein `fetch()` auf eine fremde Adresse, ein per Skript eingehängtes
   `<script>`, eine Schrift aus einer Konfigurationsdatei — sieht er nicht. Eine
   Seite kann hier sauber sein und im Browser trotzdem nach draußen greifen.

2. **Er liest keine ausgelagerten CSS-Dateien.** Nur `<style>`-Blöcke in der
   Seite selbst und `style="…"` am Element. Steht `@font-face` mit einer fremden
   Adresse in `stil.css`, findet er nichts. Wer ausgelagerte Dateien hat, ruft
   ihn auch darüber auf — als HTML gelesen findet er dort immerhin `url()`.

3. **Er beurteilt kein Wort inhaltlich.** Eine erfundene Zahl, ein falsches
   Datum, ein Preis von vorletztem Jahr: alles sauber. Er kennt eine Wortliste,
   keinen Sinn.

4. **Seine Wortliste ist endlich.** Ein Platzhalter, den niemand eingetragen hat
   (`ANSPRECHPARTNER_HIER`), rutscht durch. Die Liste steht oben in
   `pruefe-seite.py` unter `FUELLWOERTER` und darf wachsen.

5. **Ein Befund ist keine Anklage.** Er sagt „hier ist etwas", nicht „hier ist
   etwas falsch". Das `eruda` von `cdn.jsdelivr.net` in Kim-Bell ist eine
   bewusste Entscheidung von Klaus — der Prüfer meldet es zu Recht, und Klaus
   entscheidet zu Recht anders.

6. **Er misst nichts.** Ladezeit, Bildgrößen, Lighthouse-Werte — nicht sein Fach.

7. **`--erlaubt` schaltet still ab.** Wer die eigene Domain freigibt, sieht deren
   Adressen nicht mehr. Das ist gewollt, aber es heißt: eine freigegebene Domain
   wird nicht mehr geprüft.

## Herkunft

Vorgeschlagen von **Emil** (Bauer) in der Ideen-Konferenz der Kimhub-Werkstatt
am 2026-08-20, angenommen mit 20 von 20 möglichen Fremdstimmen. Gebaut hat ihn
eine Sitzung mit Werkzeugen, gegengeprüft wird er von Vera und Sten.
