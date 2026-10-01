/*
 * Siegel-Inhalt — DIE IDENTITÄT DIESES KNOTENS, und sonst nichts.
 *
 * ⚠ HIER STEHT KEIN KANON. Der Andock-Wizard, alle Anzeigetexte und alle
 * Prüfungen liegen seit A18 (2026-09-14) in EINER netzweit byte-gleichen
 * Datei — `assets/pruefer-sbkim-andock-wizard.js`, Kanon `Sage-Protokol/src/modules/16b_andock_wizard.js`.
 * Diese Datei trägt nur noch, was in jedem Knoten ANDERS sein muss.
 *
 * Warum die Trennung: gemessen über die 20 Kopien im Netz standen am 2026-09-14
 * ZWÖLF verschiedene Code-Fassungen desselben Werkzeugs. Jede Verbesserung
 * kostete Handarbeit mal zwanzig und unterblieb deshalb meistens.
 *
 * ⚠ UND DIESE DATEI WIRD NIE VERTEILT. Sie trägt die BEDEUTUNG des Knotens; ein
 * Überschreiben gäbe dieser App den Namen und den Vektor einer fremden — der
 * Schaden vom 2026-08-16 in Alis Moderaum.
 *
 * Vertrag: Sage-Protokol/docs/INTERFACES.md §11.9.
 */
(function () {
  "use strict";
  window.SBKIM_SIEGEL_WIZ = {
    domain: "Auslieferung/Datenschutz/Werkzeug",
    endpoint: "https://lausiklauskn-png.github.io/Auslieferungspruefer-Made-GPT/auslieferungspruefer.html",
    nodeType: "hybrid",
    nodeName: "Auslieferungsprüfer GPT",
    /* ⚠ WORTGLEICH MIT assets/config/pruefer-netz.js. Zwei Beschreibungen ergeben
       zwei Vektoren fuer denselben Knoten — je nachdem, ueber welchen Weg die Spore
       entstand (Verbinden-Fenster oder Andock-Wizard). Ein Waechter in
       tests/smoke.mjs vergleicht beide Stellen. */
    domainDescription: "Der Auslieferungsprüfer ist ein Werkzeug im SBKIM-Mycel und ein eigener Knoten, als eigenständige GPT-Fassung von Klaus Nitzsche. Er prüft, was eine Internetseite wirklich ins Netz gibt, statt was sie zu geben vorgibt. Er findet fremde Adressen, von denen eine Seite ungefragt nachlädt, versehentlich mitgelieferte Server-Dateien, offene Zugangsdaten und Schlüssel, und Personenbezug, der dort nicht hingehört: Kontonummern werden nachgerechnet, Telefonnummern brauchen eine Ländervorwahl, und wo sich ein echtes Etikett nicht von einem vergessenen Platzhalter unterscheiden lässt, meldet er nichts. Er läuft in zwei Fassungen — eine im Browser, eine als Textleser ohne Browser — und der Unterschied zwischen beiden ist selbst ein Befund: was der Browser lädt und der Textleser nicht sieht, ist ein Versteck. Ein Link, den ein Mensch anklickt, ist kein Abruf und steht deshalb nicht in der Fundliste.",
    domainKeywords: ["SBKIM-Protokoll", "Knoten", "Mycel", "SBKIM", "Auslieferungsprüfer", "Auslieferung prüfen", "was gibt meine Seite heraus", "fremde Hosts", "offene Geheimnisse", "Zugangsdaten im Quelltext", "Datenschutz", "Personenbezug", "IBAN", "Telefonnummer", "Platzhalter", "statischer Server", "GitHub Pages", "Caddy", "zwei Fassungen ein Ergebnis", "Werkzeug für Betreiber"],
    stammCategories: ["Auslieferung", "Befund", "Datenschutz"],
    guestCategories: ["Fremde Adresse", "Offenes Geheimnis", "Personenbezug"],
    backupPrefix: "auslieferungspruefer-backup",   // Dateiname-Praefix des verschluesselten Backups
  };
})();
