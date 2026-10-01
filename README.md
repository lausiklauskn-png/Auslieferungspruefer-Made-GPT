# Auslieferungsprüfer GPT · 1.0.0

Eigenständige, statische PWA für lokale Datei-, Text-, HTML-, Mail- und PDF-Prüfung. Neues Design, eigene Icons, OCR in Deutsch/Englisch/Russisch, zusätzliche Bildpunktprüfung, gemeinsamer Bericht und vollständiger Offline-Vorrat. Die Benutzeroberfläche bietet Deutsch und Englisch sowie drei Farbthemen.

**Zieladresse:** https://lausiklauskn-png.github.io/Auslieferungspruefer-Made-GPT/

## ZIP in GitHub veröffentlichen

1. ZIP entpacken. **Den Inhalt** direkt ins Repository `Auslieferungspruefer-Made-GPT` übernehmen: `index.html`, `sw.js`, `manifest.json`, `.nojekyll`, `assets/`, `icons/`, `vendor/` und die weiteren Ordner liegen auf der obersten Ebene. Die ZIP selbst und ein zusätzlicher äußerer Ordner sind keine fertige Pages-Seite.
2. In GitHub unter **Settings → Pages → Deploy from a branch → main → /(root)** speichern. Bei einem anderen Hauptbranch diesen wählen.
3. Nach der Veröffentlichung die Zieladresse öffnen. Sie führt direkt zum Datei-Eingang. Auf **„Offline bereit · OCR + PDF geladen“** warten; der erste Download umfasst etwa 26 MB. Danach bei Bedarf über den Installationsknopf bzw. das Browsermenü installieren.
4. Vor Verwendung auf dem Zielgerät die Offline-Abnahme aus `docs/Uebergabe-GPT.md` durchführen.

Die App benötigt keinen Build, keinen Server mit Backend, keinen API-Schlüssel und kein `npm install` zur Veröffentlichung. GitHub Pages liefert sie über HTTPS aus. Ein Doppelklick auf eine lokale HTML-Datei reicht für Service Worker und OCR nicht aus.

## Ausstattung und Grenzen

Sechs Eingänge: Datei, HTML/MHTML, Text/JSON, PDF, Adresse und E-Mail. Die Datei bleibt auf dem Gerät; der Adress-Eingang ruft auf ausdrücklichen Klick eine Website ab. Die optionale SBKIM-Verbindung ist weiterhin enthalten und hat eine eigene Identität. Datei-/Textinhalte werden nicht in den App-Cache geschrieben.

Bekannte KI-Anweisungen werden im extrahierten Inhalt mitgeprüft. Unicode-Normalisierung und eine begrenzte Base64-Prüfung ergänzen die Muster. Hinweise sind keine Angriffsnachweise. OCR bleibt von Bildqualität abhängig. PDF-Textebene: höchstens 100 Seiten, visueller Vergleich/OCR: höchstens 10 Seiten. Dateigrenze: 25 MiB. Die zusätzliche Pixelprüfung sucht bestimmte unverschlüsselte LSB-Textbotschaften; sie ist keine universelle Steganalyse. Kein Virenscanner, keine umfassende Sicherheitsfreigabe.

## Entwicklung und Tests

```sh
npm run serve
# http://localhost:8000/ öffnen
npm run test:node
```

Für echte Browser-, OCR- und Offline-Tests:

```sh
npm install
npx playwright-core install chromium
npm run test:browser
npm test
```

Optional einen vorhandenen Chromium mit `CHROMIUM_PATH=/absoluter/pfad/chrome` verwenden. Node 22 oder neuer und Python 3 empfohlen. `npm test` verlangt auch die Browser-Abnahme: fehlender Browser ergibt Exit 2, Testfehler Exit 1. `test:node` bewertet ausdrücklich nur den Node-Testumfang. Browserbilder entstehen bei erfolgreichem Start unter `test-output/`.

**Übergabestand:** 493 Node-Prüfzusicherungen bestanden; Browser/echte OCR/Installation auf dem Galaxy Tab S6 hier nicht geprüft. Details und Testprotokolle liegen in `docs/`.

Die bisherigen `smoke_start.mjs` und `smoke_vorbelegung.mjs` sind historische Tests der Vorgängeroberfläche und nicht Teil der aktuellen Abnahme. Sie dürfen nicht als Nachweis für das neue Design verwendet werden. Aktuelle Browser-Abnahme: `tests/gpt-browser.mjs`.

## Herkunft

Grundlage: vom Nutzer bereitgestellte `Auslieferung-Pruefer-main.zip`, Commit `70b291809c9044f82cccbeecc3568fcf40a477b2`. Ursprünglicher Prüfer aus PWA Toolpoint; bestehende Rechte, Lizenzen, Python-Referenz und SBKIM-Module bleiben enthalten. Die Weiterentwicklung dieses Forks wird nicht automatisch in den Sendeprüfer kopiert. Das ursprüngliche signierte Spore-Dokument liegt ausschließlich zur Herkunftsdokumentation unter `docs/herkunft/`.

Nach Änderungen an ausgelieferten Dateien die Version in `sw.js` erhöhen, damit installierte PWAs einen neuen Cache aufbauen. Exakte Pages-Adresse und Canonical-/SBKIM-Endpunkte bei einer Repository-Umbenennung ebenfalls anpassen.
