# Brief · Stufe 2 A: Text im Bild lesen (Texterkennung)

Absender: Sitzung vom 2026-09-29/30. Für die nächste Sitzung an
**Auslieferung-Pruefer**, danach byte-1:1 in **Sende-Pruefer**.

## Lies zuerst

1. `CLAUDE.md` dieses Depots, besonders „Stufe 2 D“, „Testvorlagen“, „Gleiche Art, eine Karte“
2. `Sende-Pruefer/docs/BRIEF_2026-09-29_anhaenge-stufe2.md`, Abschnitt A und „Entschieden“
3. `testvorlagen/index.html`: dort steht je Vorlage, was HEUTE herauskommt

## Stand auf main (2026-09-30)

- Der Seitentext eines PDFs wird gelesen (D). pdf.js liegt in `vendor/pdfjs/`, die App hängt nicht von Workflow PDF ab.
- Bilder: Metadaten, Anhängsel und Tarnung werden gefunden. **Der Text IM Bild wird nicht gelesen.**
  Vorlage 1A (PNG) und 1A-Scan-PDF melden das heute als „nicht gelesen“.
- Gleiche Befund-Arten stehen auf einer Karte. Das neue Icon liegt in PWA Toolpoint und family-project.

## Auftrag A

1. **Tesseract in den eigenen Ordner holen.** Klaus hat am 2026-09-30 entschieden, dass der Prüfer nicht mehr von Workflow PDF abhängt.
   Das gilt auch für die Texterkennung. Also **nicht** von `/Workflow-PDF/vendor/` nachladen, wie der alte Brief vorschlug.
   Quelle ist `Workflow-PDF/vendor/tesseract/` (21 MB, Tesseract.js 7.0.0, deu/eng/rus).
   Die Dateien kommen byte-gleich nach `vendor/tesseract/`, jede mit SHA-Pin in `smoke_knoten`.
   Die Lizenzen gehören in `THIRD_PARTY.md`. Die Dateien kommen **nicht** in den Installations-Vorrat.
2. **Lesen:** In `pruefer-anhang.js` geht jedes Bild (PNG, JPEG, WebP) und jede PDF-Seite ohne Textebene durch die Texterkennung.
   Die Seite setzt den Pfad über `pfade({tesseract})`, wie bei pdf.js.
3. **Befunde:** Der erkannte Text geht durch dieselbe KI-Liste (`PrueferMail`) und `pruefeText`.
   Ergebnis ist `BILD-KI-ANWEISUNG` mit der Stelle „…, Bildtext Zeile n“.
4. **Nie still:** Lädt die Texterkennung nicht, überschreitet sie die Zeit oder findet sie keine sicheren Zeilen,
   dann steht „Text im Bild ungeprüft“ da, nicht „kein Befund“. Eine Zeitgrenze je Bild wählen und benennen.
5. **Nachziehen:** `pruefer-anhang.js` byte-1:1 in den Sende-Prüfer kopieren, `ANHANG_SHA` nachziehen.
   Tesseract bekommt dort ebenfalls einen eigenen `vendor/`-Ordner.
6. In `testvorlagen/index.html` die grünen Zeilen für 1A nachziehen.

## Messen

- `npm test` und die Browser-Probe an Vorlage 1A: die Anweisung im Bild muss gefunden werden.
  Dazu ein sauberes Bild in der Gegenrichtung.
- Gegenprobe-Fälle `OCR:` **in einer Kopie**. ⚠ Diese Gegenprobe kennt `NUR_ANKER` nicht.
- ⚠ Nicht messbar im Behälter: Zeit und Speicher am Tablet. Das in der Doku benennen.

## Danach

B (blasser Text), dann E (Bild gegen Textebene, höchstens 10 Seiten), dann C (Verdacht auf eigenem Knopf).
So steht es im alten Brief.

## Abschluss

PULS/CLAUDE.md fortschreiben, einen Forschungseintrag in Kimhub, den Stundennachweis gemessen angeben
und einen neuen Brief als Codeblock im Chat.
