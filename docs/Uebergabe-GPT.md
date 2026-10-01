# Übergabe · Auslieferungsprüfer GPT 1.0.0

Stand: 01.10.2026. Ziel: `https://lausiklauskn-png.github.io/Auslieferungspruefer-Made-GPT/`. Auslieferung als ZIP; keine GitHub-Schreibzugriffe und keine Veröffentlichung durch diese Sitzung.

## Was sich geändert hat

- Eigenes Design in Violett, Koralle und hellen Flächen, ruhige Karten, klare Eingangsreiter, responsive Regeln, sichtbare Tastaturfokussierung und Unterstützung für reduzierte Bewegung. Nacht- und Kontrastthema bleiben wählbar.
- Neue native SVG-Marke, PNG-App-Icons 192/512, maskierbares Icon, Apple-Icon, Favicons und Vorschaubild. Manifest, relative Ressourcenpfade und Scope auf das genannte Repository abgestimmt.
- Direktstart im Datei-Eingang, Dateiablage per Drag-and-drop, ergänzter Überblick und DE/EN-Texte. Vorhandene sechs Prüfwege, Beispiele, Export, Installation und optionale SBKIM-Ausstattung erhalten.
- Ein gemeinsamer Inhaltsprüfer ergänzt die Prüfung extrahierter TXT-, HTML-, SVG- und Office-Texte um mögliche KI-Anweisungen. Begrenzte Normalisierung unsichtbarer Zeichen, zusätzliche DE/EN/RU-Muster und begrenzte Base64-Decodierung kommen hinzu. Keine Behauptung vollständiger Prompt-Injection-Erkennung.
- Gemeinsames Ergebnis für Anzeige und Bericht. Zusätzliche Pixelbefunde aktualisieren die Summe und stehen im kopierten/gespeicherten Bericht. Gleichnamige Anhänge bleiben getrennt. Auch unauffällige Ergebnisse können exportiert werden.
- Unbekannte Formate, fehlende PDF-Bibliothek, unsichere OCR-Zeilen, überschrittene Seitengrenzen und fehlgeschlagene Zusatzprüfungen werden als Prüfgrenzen berücksichtigt. Eine geänderte Eingabe entwertet den vorherigen Bericht. Alte asynchrone Dateilesungen und Abrufe sollen neuere Ergebnisse nicht überschreiben.
- Service Worker mit 82 ausgelieferten Ressourcen einschließlich PDF.js, Tesseract, drei Sprachdateien, WASM, Beispielen und SBKIM-Modulen. Der Status „Offline bereit“ erfordert tatsächlich alle Cacheeinträge. Keine geprüften Benutzerdaten im Cache, keine fremden URLs, kein POST-Caching. Die eigenen Cache- und Einstellungsnamen sowie SBKIM-Datenbank sind vom ursprünglichen Prüfer und der Sender-PWA getrennt. Aktualisieren löscht nur eigene Caches und die eigene Service-Worker-Registrierung.

## Was tatsächlich geprüft wurde

| Umfang | Ergebnis |
|---|---|
| Bestehende Knoten-/Ressourcen-/Versionsprüfungen, auf Fork angepasst | 194 bestanden |
| Bestehende Datei-/Anhangprüfungen einschließlich PDF-/OCR-Nachlauf | 115 bestanden |
| Bestehende Node-/Python-Vergleiche des Prüfers | 139 bestanden |
| Neue positive Fork-Regressionen, Bericht und SW-Logik mit Netz-/Cacheadaptern | 45 bestanden |
| Zusammen | **493 bestanden, 0 Fehler** |
| Lokale HTML-Ressourcenpfade und Iconabmessungen | 94 Einzelprüfungen bestanden, keine fehlende Referenz |
| JavaScript-Syntax in App, Tests und SBKIM-Modulen | separat geprüft |
| Echter Browser, reale Tesseract-Erkennung, echte CacheStorage-/Service-Worker-Laufzeit | **nicht durchgeführt** |
| Darstellung, Touch, PWA-Installation und Offline auf Galaxy Tab S6 | **nicht durchgeführt** |

Die SW-Tests führen den echten Worker-Code in einer VM mit Speicher-/Netzadaptern aus. Sie belegen Scope, Cacheauswahl, Status, fehlgeschlagenen Download und Offline-Fallbacks in diesem Testmodell. Sie sind kein Ersatz für die Browser-Abnahme. OCR-Nachlauftests mit eingesetzten Texten belegen die Verarbeitung, nicht die Bildlesequalität.

Chromium war nicht vorhanden. Der Downloadversuch lieferte ungültige/unvollständige Archive. Die neue Browser-Suite wurde deshalb nicht ausgeführt und beendet sich mit **Exit 2 / UNGEPRÜFT**. Es liegt kein belastbarer Screenshot-Test des neuen Designs vor. Die neuen Browser-Tests selbst sind bis zur ersten echten Ausführung ebenfalls als unbestätigte Abnahmesuite zu behandeln. Die Protokolle `Node-Testprotokoll.txt` und `Browser-Teststatus.txt` dokumentieren den Stand.

## Abnahme auf deinem Gerät

1. ZIP-Inhalt laut README auf die oberste Repository-Ebene übernehmen und GitHub Pages für Hauptbranch/Root aktivieren.
2. App online öffnen. Kontrollieren: Datei-Eingang sichtbar, Dateien auswählbar, kein seitliches Scrollen im Hoch- und Querformat, alle sechs Reiter erreichbar. DE/EN, drei Themen und Tastatur-/Touchbedienung ausprobieren.
3. Auf „Offline bereit“ warten. Die mitgelieferten Testvorlagen für normales Bild, blassen Text, PDF-Scan und versteckten PDF-Text prüfen. OCR-Befunde samt Angaben zum Prüfumfang lesen.
4. Bei `Vorlage-4C-Bild-mit-versteckter-Botschaft.png` auf „Bildpunkte auf Verdacht prüfen“ klicken. Der Verdacht muss in Anzeige **und** kopiertem/gespeichertem Bericht stehen. Die saubere Gegenprobe darf nicht denselben Verdacht erhalten.
5. Nach einem Ergebnis den Eingabetext ändern. Der alte Export muss verschwinden. PDF-Prüfung starten und sofort zu einem anderen Eingang wechseln: das alte PDF darf dort keinen Bericht einblenden.
6. Installieren, Flugmodus einschalten, App vollständig schließen und erneut starten. Ohne Netz ein mitgeliefertes Bild und PDF prüfen. OCR muss nach diesem Neustart funktionieren. Die fehlende Internetverbindung darf Dateiprüfung und Export nicht sperren; Adressabrufe können offline nicht funktionieren.
7. Sender-PWA separat öffnen. Die Aktualisierung dieser App darf deren Einstellungen, Offline-Cache oder SBKIM-Identität nicht löschen.

## Grenzen und Pflege

Die Musterprüfung kann zitierte Anweisungen melden und neue Formulierungen übersehen. Base64 wird nur begrenzt und nicht rekursiv untersucht; beliebige Kodierungen, Verschlüsselung und sämtliche Sprachen sind nicht abgedeckt. LSB prüft bestimmte Farbkanal-/Textlayouts, keine beliebigen Stego-Verfahren. PDF und OCR haben Zeit-, Seiten- und Qualitätsgrenzen. Der Export kann Dateinamen und gelesenen versteckten Text enthalten: vor Weitergabe ansehen.

Lizenz- und Urheberhinweise wurden erhalten. Impressum und Datenschutz behalten die vorhandenen Betreiberangaben aus der gelieferten Quelle; bei einem anderen Betreiber müssen diese vor Veröffentlichung angepasst werden. Bibliotheken wurden nicht neu versioniert: vorhandenes PDF.js 3.11.174 und Tesseract.js 7.0.0 bleiben enthalten. Eine Prüfung aktueller Bibliotheks-Sicherheitsmeldungen war nicht Bestandteil dieser Übergabe.

Die `CLAUDE.md` enthält ältere Sitzungsverläufe. Ihr neuer Kopf beschreibt den gültigen Fork-Auftrag. Ältere Forderungen nach Bytegleichheit mit dem Sender gelten für diesen ausdrücklich eigenständigen Umbau nicht. Die Python-Referenz bleibt Vergleichsbasis für die ursprüngliche HTML-Prüflogik; die neuen KI-Inhaltsregeln sind JavaScript-Erweiterungen.
