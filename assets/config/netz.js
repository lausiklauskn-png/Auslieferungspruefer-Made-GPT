/* ============================================================================
 * PWA Toolpoint — Netz-Konfiguration (der eigene Knoten).
 *
 * Klaus 2026-08-09: „Mit dem Knotennetz verbinden / Mycel — das eigene,
 * unabhängige von Sage. Auch von Family Projekt."
 *
 * Das ist der Ort, an dem diese Unabhängigkeit steht. Alles, was PWA Toolpoint
 * mit dem Netz verbindet, wird HIER eingestellt — nicht in den Modulen. Die
 * Module unter `sbkim/` sind byte-1:1-Kopien aus Sage-Protokol und werden nie
 * angefasst (Drift-Guard wacht darüber).
 *
 * DREI EBENEN DER UNABHÄNGIGKEIT — was heute geht und was nicht:
 *
 *   1. Eigene Identität   ✅ geht heute.  Eigener Schlüssel, eigene Spore,
 *      eigene Datenbank-Schublade (`dbSuffix`). Nichts davon ist mit Sage oder
 *      Family Projekt geteilt.
 *
 *   2. Eigene Relais      ✅ geht heute.  `RELAIS` unten wird per
 *      `SbkimNostrRelay.configure({relays})` gesetzt. Mehrere Adressen sind
 *      Absicht: fällt eine aus, laufen die anderen weiter.
 *
 *   3. Eigener Raum       ⚠️ geht heute NOCH NICHT.  Modul 23 trägt das Etikett
 *      des Raums als feste Konstante (`var RDV_TAG = "sbkim-rdv"`), und
 *      `configure()` kennt es nicht. Solange das so ist, treffen sich hier alle
 *      im GEMEINSAMEN Raum — auch die Knoten von Sage und Family Projekt.
 *
 *      Der saubere Weg ist NICHT, die Kopie hier zu ändern (das erzeugt eine
 *      dritte Modul-Generation und der Drift-Guard schlägt zu Recht an),
 *      sondern ein optionales `roomTag` IM KANON, Standard unverändert. Bis
 *      dahin steht `RAUM` unten als vorbereiteter Wert und wird vom Modul
 *      ignoriert — sichtbar und benannt, statt still falsch.
 * ========================================================================== */

window.PT_NETZ = {
  /* Eigene Schublade in der Browser-Datenbank. NIE ändern — alle Apps auf
     GitHub Pages teilen sich eine Adresse; ein anderer Wert wäre ein anderer,
     leerer Knoten, und die alte Identität wäre nicht mehr auffindbar. */
  dbSuffix: "pwatoolpoint",

  nodeName: "PWA Toolpoint",
  repoUrl: "https://github.com/lausiklauskn-png/PWA-Toolpoint",

  /* Fremde Seiten, die per postMessage mit diesem Knoten reden dürfen.
     Alles andere weist Modul 15 (Membran) ab und meldet es an der FREMD-Lampe. */
  allowedOrigins: [
    "https://pwa-toolpoint.de",
    "https://www.pwa-toolpoint.de",
    "https://pwa-toolpoint.com",
    "https://www.pwa-toolpoint.com"
  ],

  /* ---- Relais ------------------------------------------------------------
   * Frei wählbar, mehrere gleichzeitig — Vorbild ist Kimboard. Alle gewählten
   * laufen PARALLEL; fällt eins aus, tragen die anderen weiter. Kein
   * Umschalten, kein Wartestand.
   *
   * OHNE `relay.family-projekt.de` (Klaus 2026-08-09): PWA Toolpoint soll ein
   * eigenständiges Projekt sein und nicht am Server von Family Projekt hängen.
   *
   * WAS DAS BEWIRKT — und was NICHT. Es entkoppelt den **Betrieb**: fällt der
   * Server von Family Projekt aus, merkt dieser Marktplatz nichts davon. Es
   * trennt aber **nicht die Netze**. Ob zwei Knoten sich treffen, entscheidet
   * der RAUM (`RDV_TAG`), nicht die Poststelle — und der heißt bei allen noch
   * `sbkim-rdv`. Kimboard und Family Projekt benutzen dieselben öffentlichen
   * Relais wie wir; über `relay.damus.io` sitzt man weiterhin im selben
   * Zimmer. Wer wirklich ein eigenes Netz will, braucht den eigenen Raum
   * (siehe unten) — die Relais-Liste allein leistet das nicht.
   *
   * EHRLICH ZUR KEHRSEITE: ohne Klaus' eigenes Relais gehören jetzt ALLE
   * Poststellen Fremden. Sie transportieren nur — aber sie sehen, DASS zwei
   * Knoten sich treffen wollen. `relay.nostr.band` ist ausdrücklich ein
   * Archiv- und Suchdienst und steht deshalb NICHT im Voreinstellungs-Satz.
   * Sobald `wss://relay.pwa-toolpoint.de` läuft, gehört es an die erste
   * Stelle und wird der Standard.
   *
   * `relaisPool` = was zur Auswahl steht. `relais` = was voreingestellt AN ist.
   * Die Wahl des Nutzers liegt in `localStorage` unter `pt_relais` (mit
   * App-Kürzel, weil sich alle Apps auf GitHub Pages eine Adresse teilen). */
  /* EIGENES RELAIS AN ERSTER STELLE (Klaus 2026-08-11).
   *
   * Die Lage vorher: ALLE Poststellen gehörten Fremden. Sie transportieren nur
   * und sehen keine Inhalte — aber sie sehen, DASS zwei Knoten sich treffen
   * wollen, und die IP jedes Besuchers geht an sie, teils außerhalb der EU.
   * Genau so steht es auch im Datenschutz.
   *
   * `relay.pwa-toolpoint.de` steht deshalb jetzt vorn. Es ändert NICHTS an der
   * Zugehörigkeit — die entscheidet der RAUM (`RDV_TAG`), nicht die Poststelle.
   * Wer ein eigenes Netz will, braucht den eigenen Raum (siehe `raum` /
   * `raumAktiv` weiter unten); die Relais-Liste allein leistet das nicht. Diese
   * Klarstellung ist Klaus gegenüber ausdrücklich gemacht worden und wird nicht
   * wieder verwässert.
   *
   * DIE ÖFFENTLICHEN BLEIBEN DAHINTER — bewusst. Alle laufen parallel; fällt
   * eins aus, tragen die anderen weiter. Klaus' eigener Server ist damit die
   * bevorzugte, aber nicht die einzige Poststelle: geht er vom Netz, läuft die
   * Netz-Funktion über die fremden weiter, statt auszufallen. Deshalb steht
   * hier nicht NUR das eigene.
   *
   * SOLANGE ES NOCH NICHT LÄUFT, kostet es nichts: eine nicht erreichbare
   * Adresse scheitert still, die übrigen tragen. Es ist dann kein Fehler —
   * nur noch keine Verbesserung. */
  relaisPool: [
    "wss://relay.pwa-toolpoint.de",
    "wss://relay.damus.io",
    "wss://nos.lol",
    "wss://relay.primal.net",
    "wss://relay.snort.social",
    "wss://nostr.mom",
    "wss://offchain.pub",
    "wss://relay.mostr.pub",
    "wss://relay.nostr.band"
  ],
  relais: [
    "wss://relay.pwa-toolpoint.de",
    "wss://relay.damus.io",
    "wss://nos.lol",
    "wss://relay.primal.net"
  ],

  /* Vorbereitet für den eigenen Raum (siehe Kopf, Punkt 3). Das Modul liest
     diesen Wert heute NICHT — er steht hier, damit die Absicht dokumentiert
     ist und der Tag, an dem der Kanon es kann, nur noch eine Zeile braucht. */
  raum: "pwatp-rdv",
  raumAktiv: false
};
