# Brief: Stufe 2 E, unsichtbarer Text im PDF

**Geschrieben am 2026-09-30, für eine frische Sitzung.** Gebaut ist noch nichts von E.
Der Stand wurde gegen `origin/main` beider Depots gemessen.

## Lies zuerst

1. `Auslieferung-Pruefer/CLAUDE.md` § „📄 Stufe 2 D", „🔤 Stufe 2 A", „🌫 Stufe 2 B"
2. `Sende-Pruefer/docs/BRIEF_2026-09-29_anhaenge-stufe2.md` § E und § „Entschieden"
3. `Auslieferung-Pruefer/testvorlagen/index.html`, Karten 0D und 3E

Frisch abzweigen: `git fetch origin --quiet && git checkout -B <zweig> origin/main`.

## Stand am 2026-09-30

| Schritt | Stand |
|---|---|
| D · Seitentext eines PDFs (pdf.js) | ✅ gebaut, höchstens 100 Seiten |
| A · Text im Bild, gescannte PDF-Seiten (Tesseract) | ✅ gebaut, höchstens 10 Scan-Seiten, 90 s je Bild |
| B · blasser Text (zweiter Durchgang nach Kontrast-Spreizung) | ✅ gebaut, **nur Bilder** |
| **E · Textebene gegen das, was man sieht** | ❌ **dieser Brief** |
| C · Botschaft in den Bildpunkten | ❌ erst nach dem Messplan (Fehlalarm-Zahl an den 17 Fotos) |

Der Prüfkern `assets/pruefer-anhang.js` wird im **Auslieferungsprüfer** gepflegt. Danach wird er
byte-1:1 in den Sende-Prüfer kopiert, und dort wird der Pin `ANHANG_SHA` in `tests/anhaenge.mjs`
nachgezogen. pdf.js und Tesseract liegen in beiden Depots unter `vendor/`.

## Was E tun soll

Je PDF-Seite wird verglichen, was in der **Textebene** steht (D, `getTextContent`), mit dem, was die
Texterkennung auf dem **gerenderten Bild** derselben Seite liest (A). Wörter, die in der Textebene
stehen und im Bild fehlen, sind **unsichtbar**. Befundart **`PDF-VERSTECKTER-TEXT`**, Stelle „Seite n".
Der Befund sagt, welche Wörter es sind, und gibt einen Rat.

Typische Fälle: weiß auf weiß, Schrift unter 1 pt, außerhalb der MediaBox, Darstellungsart 3
(unsichtbar), Text hinter einem Bild.

- **Vorlage 3E** (sichtbar 120 €, in der Textebene 12.000 € mit IBAN): heute meldet der Prüfer die
  KI-Anweisung und die IBAN, aber **nicht den Widerspruch**. Nach E steht zusätzlich
  „Was man sieht und was im Text steht, weicht ab (Seite 1)" da.
- **Vorlage 0D** (Seite 2 weiß auf weiß, 1 pt): die Anweisung wird heute schon gemeldet. Nach E steht
  zusätzlich `PDF-VERSTECKTER-TEXT` auf Seite 2 da.
- **Gegenrichtung:** Seite 1 von 0D (harmloser Brief) und ein sauberes PDF melden **keinen** Befund.

## Entschieden (Klaus 2026-09-29)

- **Höchstens die ersten 10 Seiten** werden gegengelesen. Dahinter steht es beim Namen:
  „Seiten 11–N nicht gegengelesen", nie still.
- Die Reihenfolge D → A → B → E → C bleibt.

## Vorschläge zur Bauart (nicht entschieden, prüfen)

- Rendern mit pdf.js auf eine Leinwand (lange Kante ≤ `OCR_KANTE`), dann dieselbe
  Texterkennung wie bei A, dieselbe `OCR_FRIST`-Logik.
- Vergleichen über **Wörter ab 3 Buchstaben**, wie bei B. Tesseract liest einzelne Zeichen anders;
  ein wörtlicher Vergleich meldet sonst Schein-Funde. Die Schwelle nicht raten, sondern an 0D/3E und
  an einem sauberen PDF messen und benennen.
- Seiten **ohne** Textebene haben nichts zum Vergleichen. Sie laufen weiter über A, und das wird benannt.
- Kann die Texterkennung eine Seite nicht lesen (Frist, `file://`, kein Werkzeug), heißt es
  „ungeprüft", nie „kein Befund".
- Kosten: ein Tesseract-Lauf je Seite, zusätzlich zu A. Die Zeit messen und hinschreiben.

## Leitplanken

- Nichts wird ausgeführt oder angezeigt. Ergebnisse nur über `textContent`.
- An die KI geht im Sende-Prüfer weiterhin nur der Mailtext.
- Nachgeladene Werkzeuge nicht in den Installations-Vorrat.
- Neue Befundart: Wächter in `tests/smoke_anhang.mjs` und `tests/smoke_pruefer.mjs`, dazu
  Gegenprobe-Fälle `NUR_FALL="VERSTECKT:"`, **in einer Kopie** gefahren. Die roten Zeilen von Hand lesen.
- Rat und Name der Befundart in DE und EN (`pruefer-ui.js`, `i18n-pruefer.js`). Cache und alle `?v=`
  erhöhen (heute v16 / `?v=91` im Auslieferungsprüfer, v31 im Sende-Prüfer).
- `testvorlagen/index.html`: die grüne Zeile für 3E nachziehen (gebaut mit `node tools/testvorlagen-bauen.mjs`).
- Der Sende-Prüfer: die vier Dateien sind voll. Alles Neue gehört nach `assets/`.

## Abschluss

1. Beide Depots: `npm test` grün, Gegenprobe in einer Kopie, PR, Selbst-Merge, auf `main` nachsehen.
2. CLAUDE.md beider Depots: Abschnitt „Stufe 2 E" mit den gemessenen Zahlen.
3. Forschungseintrag in Kimhub (`node tools/sitzung-eintragen.mjs`, `arm` Pflicht, Spanne gemessen).
4. Brief für C (Messplan zuerst) als Codeblock im Chat.
5. Ungemessen bleibt: das Tablet (Zeit, Speicher).
