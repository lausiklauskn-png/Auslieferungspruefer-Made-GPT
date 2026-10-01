/* ============================================================================
 * Auslieferungsprüfer — Netz-Konfiguration (der EIGENE Knoten dieses Werkzeugs).
 *
 * Klaus 2026-09-08: „Beide Tools, Company und das Ausliefer-Tool, sollen als
 * eigenständige Knoten agieren … mit Zelle und auch dem Siegel."
 *
 * ⚠ ZWEI KNOTEN AUF EINER ADRESSE, UND DAS IST DER GANZE GRUND FÜR DIESE DATEI.
 * `pwa-toolpoint.de` beherbergt den Marktplatz (`assets/config/netz.js`,
 * Schublade `toolpoint`) und seit heute den Prüfer. IndexedDB gehört dem
 * URSPRUNG, nicht dem Pfad — ohne getrennte Schubladen schrieben beide in
 * dieselbe und hätten dieselbe Identität. Genau der Befund vom 2026-08-16, als
 * Alis Moderaums Wizard die Beschreibung einer fremden App zeigte.
 *
 * Der Prüfer bekommt deshalb `auslieferungspruefer`, netzweit noch nicht
 * vergeben. Ein Suffix wird EINMAL vergeben und nie geändert: ein anderer Wert
 * wäre ein anderer, leerer Knoten, und die alte Identität nicht mehr auffindbar.
 *
 * ⚠ WAS ER MIT DEM MARKTPLATZ TEILT UND WAS NICHT.
 *   geteilt:   die Modul-Dateien unter `sbkim/` (byte-1:1, ein Ordner),
 *              die Relais-Liste (dieselben Poststellen, dieselbe Kehrseite),
 *              die erlaubten Herkünfte für `postMessage`
 *   getrennt:  Schublade, Identität, Spore, Name, Bedeutungs-Beschreibung,
 *              das Siegel-Band — alles, was den Knoten AUSMACHT
 *
 * Die Relais zu teilen ist Absicht: sie transportieren nur. Ob zwei Knoten sich
 * treffen, entscheidet der RAUM (`RDV_TAG` in Modul 23), nicht die Poststelle —
 * dieselbe Klarstellung wie in `netz.js`, und sie wird hier nicht verwässert.
 * ========================================================================== */

window.PR_NETZ = {
  dbSuffix: "auslieferungspruefer-gpt",

  nodeName: "Auslieferungsprüfer GPT",
  repoUrl: "https://github.com/lausiklauskn-png/Auslieferungspruefer-Made-GPT",
  endpoint: "https://lausiklauskn-png.github.io/Auslieferungspruefer-Made-GPT/auslieferungspruefer.html",
  domain: "Auslieferung/Datenschutz/Werkzeug",
  nodeType: "hybrid",

  /* ⚠ DIE BESCHREIBUNG IST KEINE ZIERDE. Modul 03 rechnet daraus den
     Domänen-Vektor, Modul 04 vergleicht damit. Ein Satz ergibt einen Knoten,
     der zu allem und zu nichts passt — und der findet dann die falschen
     Nachbarn, ohne dass es jemandem auffällt. Vorausgefüllt (Klaus 2026-09-08)
     aus dem, was dieses Werkzeug wirklich tut. */
  beschreibung: "Der Auslieferungsprüfer ist ein Werkzeug im SBKIM-Mycel und ein eigener Knoten, als eigenständige GPT-Fassung von Klaus Nitzsche. Er prüft, was eine Internetseite wirklich ins Netz gibt, statt was sie zu geben vorgibt. Er findet fremde Adressen, von denen eine Seite ungefragt nachlädt, versehentlich mitgelieferte Server-Dateien, offene Zugangsdaten und Schlüssel, und Personenbezug, der dort nicht hingehört: Kontonummern werden nachgerechnet, Telefonnummern brauchen eine Ländervorwahl, und wo sich ein echtes Etikett nicht von einem vergessenen Platzhalter unterscheiden lässt, meldet er nichts. Er läuft in zwei Fassungen — eine im Browser, eine als Textleser ohne Browser — und der Unterschied zwischen beiden ist selbst ein Befund: was der Browser lädt und der Textleser nicht sieht, ist ein Versteck. Ein Link, den ein Mensch anklickt, ist kein Abruf und steht deshalb nicht in der Fundliste.",

  stichworte: ["SBKIM-Protokoll", "Knoten", "Mycel", "SBKIM", "Auslieferungsprüfer", "Auslieferung prüfen", "was gibt meine Seite heraus", "fremde Hosts", "offene Geheimnisse", "Zugangsdaten im Quelltext", "Datenschutz", "Personenbezug", "IBAN", "Telefonnummer", "Platzhalter", "statischer Server", "GitHub Pages", "Caddy", "zwei Fassungen ein Ergebnis", "Werkzeug für Betreiber"],

  /* Fremde Seiten, die per postMessage mit diesem Knoten reden dürfen. Alles
     andere weist Modul 15 ab und meldet es an der FREMD-Lampe. Dieselbe Liste
     wie beim Marktplatz — es sind dieselben Adressen, unter denen dieses
     Werkzeug ausgeliefert wird. */
  allowedOrigins: [
    "https://pwa-toolpoint.de",
    "https://www.pwa-toolpoint.de",
    "https://pwa-toolpoint.com",
    "https://www.pwa-toolpoint.com"
  ],

  /* ⚠ ABGELESEN, NICHT ABGESCHRIEBEN. Die Voreinstellung kommt aus
     `window.PT_NETZ.relais` — zwei Listen derselben Poststellen liefen
     auseinander, und dann sendete der Prüfer über andere Relais als der
     Marktplatz, ohne dass es irgendwo stand. Fehlt `netz.js` (etwa weil die
     Datei nicht geladen wurde), bleibt die Liste leer und Modul 05b behält
     seine eigene Vorgabe — fail-soft statt geraten. */
  get relais() {
    try { return (window.PT_NETZ && window.PT_NETZ.relais) || []; } catch (_e) { return []; }
  }
};
