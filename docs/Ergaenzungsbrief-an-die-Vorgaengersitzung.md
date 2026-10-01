# Ergänzungsbrief an die Vorgängersitzung

Klaus bittet um eine ergänzende Rückmeldung zur Prüfung und Weiterentwicklung des Sendeprüfers. Grundlage sind der frühere Prüfbericht und die anschließende Untersuchung des baugleichen Prüfkerns im Auslieferungsprüfer.

Die erste Sitzung hat wichtige Grundlagen richtig erkannt: OCR und einfache LSB-Textsuche waren bereits vorhanden, ihre Grenzen wurden benannt, und die fehlende Injection-Prüfung vor dem tatsächlichen KI-Ausgang wurde herausgestellt. Die Trennung zwischen Erkennung durch den Prüfer und Befolgung durch ein KI-Modell war sinnvoll.

Die Prüfung hätte an folgenden Stellen vollständiger sein können:

1. **Alle Eingabewege bis zur Anzeige und zum Ausgang verfolgen.** Der gleiche Testsatz sollte als Mailtext, TXT, SVG, HTML, DOCX, PDF-Textebene, OCR-Ausgabe und dekodierter Mail-Anhang geprüft werden. Im Auslieferungsprüfer wurde der Text aus TXT/SVG/HTML/DOCX korrekt extrahiert, anschließend aber nur durch den allgemeinen Textprüfer geleitet. Der KI-Musterprüfer wurde dort nicht aufgerufen. Diese Pfadunterschiede waren im ersten Bericht nicht vollständig untersucht.
2. **Nachträgliche Befunde in Bericht und Export prüfen.** Die optionale Pixelprüfung ergänzt ihre eigene Anzeige, aber den vorhandenen Bericht nicht. Ein Klick auf „Bericht kopieren“ oder „Speichern“ kann deshalb den Stand vor dem LSB-Fund liefern. Die Empfehlung eines zentralen Ergebnisses war richtig; ein konkreter Exporttest hätte diese bestehende Lücke direkt belegt.
3. **Hinweise und Gesamtstatus gemeinsam prüfen.** Ein Ungeprüft-Hinweis reicht nicht, wenn die hervorgehobene Zusammenfassung „kein Befund“ anzeigt. PDF.js-Ausfall, gemischte OCR-Sicherheit, unbekannte Formate, zu große Anhänge und Fehler benötigen eine verlässliche gemeinsame Abdeckungsbewertung.
4. **Testauslassungen bis zur Teststeuerung durchreichen.** Der Browser fehlte in beiden Umgebungen. Der vorhandene Gesamtrunner beendet sich dennoch erfolgreich und meldet pauschal „alle Proben grün“. Das Protokoll muss bestandene, fehlgeschlagene und nicht ausführbare Teile getrennt zählen. Die lokale Browser-Pfadsuche sollte außerdem die bereits vorhandene gemeinsame Suchfunktion verwenden.
5. **Für Reparaturen positive Abnahmekriterien schreiben.** Tests, die einen Fehler als bestehende Grenze bestätigen, sind Diagnosewerkzeuge. Nach dem Umbau muss derselbe Fall die korrekte Warnung, den vollständigen Bericht oder den ehrlichen Teilstatus verlangen. Eine weiterhin grüne Grenzprobe bescheinigt keine Reparatur.
6. **Browser- und Gerätemessungen weiter offenlassen, bis sie tatsächlich erfolgt sind.** Eingesetzte OCR-Ausgaben und isolierte DOM-Funktionen prüfen Nachlauf und Logik. Sie messen weder Tesseract-Erkennung noch das Verhalten auf Klaus’ Galaxy Tab S6. Gleiches gilt für Stego aus fremden Werkzeugen und für bereinigte Ausgaben.

Für den nächsten Umbau empfehle ich zuerst eine gemeinsame Inhaltsprüfung für alle extrahierten Texte, danach ein gemeinsames Ergebnis für Anzeige und Bericht und anschließend eine ehrliche Kennzeichnung der Abdeckung. Der bestehende OCR-/PDF-/LSB-Kern kann weiterverwendet werden. Ein neuer allgemeiner Steganalyse-Dienst ist dafür nicht notwendig.

Die neue Fassung „Auslieferungsprüfer GPT“ entsteht als eigenständiger Fork auf Klaus’ ausdrücklichen Auftrag. Sie wird nicht automatisch zurück in den ursprünglichen Sendeprüfer oder dessen Repository geschrieben. Änderungen, Abnahmetests und offene Grenzen werden in einer eigenen Übergabedatei dokumentiert.

Stand: 01.10.2026. Der Zusatzbericht bestätigte 410 vorhandene Prüfzusicherungen und 55 weitere Bestandsannahmen, darunter 29 Grenzen. Diese Zahlen sind keine Quote abgewehrter Angriffe.
