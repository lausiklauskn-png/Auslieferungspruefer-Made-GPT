/* ============================================================================
 * Auslieferungsprüfer — SBKIM-Andock (Klebstoff zwischen Seite und Modulen).
 *
 * Kopiert von `assets/sbkim-init.js`, dem Andock des Marktplatzes, und an drei
 * Stellen angepasst. Es ist bewusst dieselbe Bauart und nicht eine zweite:
 * die Ladezeit dieser Seite steht öffentlich im Marktplatz, und die 100/100/100
 * dort hängen genau an dieser Bauart.
 *
 * ══ DIE DREI UNTERSCHIEDE, jeder mit Grund ═════════════════════════════════
 *
 *   1. EIGENE SCHUBLADE (`auslieferungspruefer` aus `config/pruefer-netz.js`).
 *      Zwei Knoten auf einer Adresse — ohne getrennte Schubladen hätten sie
 *      dieselbe Identität. Der Vorgabe-Wert steht zusätzlich im `<head>` der
 *      Seite, weil Modul 01 ihn BEIM LADEN liest (Falle 1 aus Sages LEHREN § 4).
 *
 *   2. MODUL 17 LÄUFT MIT, beim Marktplatz nicht. Der Marktplatz hat eine eigene
 *      Lampen-Leiste in der Kopfzeile und bringt `#lamp-fremd` und
 *      `#sbkim-siegel-badge` selbst mit; diese Seite hat keine. Modul 17 legt
 *      beide an — und es steht VOR 15 und 16, sonst hängen Wächter und Siegel
 *      LAUTLOS ins Leere (Falle 3). Es kostet 79 KB, und die kauft man hier für
 *      eine Statusleiste, die es sonst nicht gäbe.
 *
 *   3. KEINE PLATZRESERVE IM KOPF NÖTIG. Beim Marktplatz hält
 *      `.lamps{min-height:34px}` den Platz für das Siegel frei, sonst wächst
 *      die Kopfleiste beim Erscheinen und schiebt die Seite (bei
 *      SB·KIMTool·Point gemessen: CLS 0,103 → 0,052). Modul 17 mountet eine
 *      SCHWEBENDE Pille (`position:fixed`) — sie nimmt keinen Platz im Fluss
 *      und kann deshalb auch keinen wegnehmen. Nachgemessen, nicht angenommen:
 *      die Zahlen stehen im PR.
 *
 * ══ WARUM NACHGELADEN UND NICHT AM SEITENENDE (gemessen, nicht gemeint) ═════
 *
 * Dreizehn Module als gewöhnliche `<script>`-Zeilen kosten messbar: an
 * family-project 91 statt 100, an Mein-WorkFloh 85 → 95. Die Seite wird zuerst
 * fertig gezeichnet; danach, in einer Leerlauf-Pause, kommt die Kette — Datei
 * für Datei, in exakter Reihenfolge, jede wartet auf die vorige.
 *
 * ALLES FAIL-SOFT. Fehlt ein Modul, fällt eine Datei aus, gibt es kein Netz:
 * die Prüfung läuft weiter, der Text-Eingang geht, die PDF-Fassung geht. Es
 * fehlen dann nur die Lampen und das Siegel — kein toter Knopf, kein Absturz.
 * Das ist hier wichtiger als sonst: dieses Werkzeug wirbt damit, dass nichts
 * nach außen geht, und es muss vollständig ohne Netz arbeiten.
 * ========================================================================== */
(function () {
  "use strict";

  var NETZ = window.PR_NETZ || {};

  /* ---- Gerätename (frei wählbarer Anzeige-Name, lokal, kein PII) ------------
     Netzweite Bauregel INTERFACES § 11.7: das Feld gehört INS Verbinden-Panel
     und wird vom app-eigenen Klebstoff hineingehängt — NIE in die byte-kopierte
     Panel-Datei, sonst schlägt der Drift-Guard zu Recht an.

     ⚠ DER SPEICHER-SCHLÜSSEL IST DERSELBE WIE BEIM MARKTPLATZ, und das ist
     Absicht: `localStorage` gehört der Adresse, und es ist DASSELBE Gerät.
     Wer sich einmal „Klaus-Handy" nennt, meint das für beide Knoten. Getrennt
     bleibt, was den Knoten ausmacht — Kennung, Spore, Beschreibung. */
  var LS_GERAETENAME = "sbkim_geraetename";
  function geraetename() {
    try { return (localStorage.getItem(LS_GERAETENAME) || "").trim().slice(0, 40); } catch (_e) { return ""; }
  }
  function anzeigeName() {
    var g = geraetename();
    return g ? (NETZ.nodeName + " · " + g) : NETZ.nodeName;
  }
  function namensfelderAbgleichen() {
    try {
      var wert = geraetename();
      var liste = document.querySelectorAll("[data-sbkim-geraetename]");
      for (var i = 0; i < liste.length; i++) { if (liste[i].value !== wert) liste[i].value = wert; }
    } catch (_e) {}
  }
  function geraetenameFeldEinhaengen() {
    function versuch() {
      var panel = document.getElementById("sbkim-rdv-panel");
      if (!panel) return false;
      if (panel.querySelector("[data-sbkim-geraetename]")) return true;
      var zeile = document.createElement("div");
      zeile.style.cssText = "margin:8px 0;display:flex;gap:6px;align-items:center;flex-wrap:wrap";
      var beschriftung = document.createElement("label");
      beschriftung.setAttribute("for", "sbkim-geraetename");
      beschriftung.textContent = "🏷️ Gerätename:";
      beschriftung.style.cssText = "color:#9aa7b6;font-size:.85rem";
      var feld = document.createElement("input");
      feld.id = "sbkim-geraetename"; feld.type = "text"; feld.maxLength = 40;
      feld.setAttribute("data-sbkim-geraetename", "1");
      feld.placeholder = "z. B. Klaus-Handy (frei wählbar)";
      feld.value = geraetename();
      feld.title = "Nur ein Anzeige-Hinweis, kein Vertrauens-Beweis — die Kennung steht daneben.";
      feld.style.cssText = "flex:1;min-width:120px;padding:4px 6px;border-radius:6px;border:1px solid #33414f;background:#0d1520;color:#dfeaf2;font:inherit";
      feld.addEventListener("input", function () {
        try { localStorage.setItem(LS_GERAETENAME, String(feld.value || "").trim().slice(0, 40)); } catch (_e) {}
        try { window.dispatchEvent(new CustomEvent("sbkim:geraetename-changed")); } catch (_e) {}
      });
      zeile.appendChild(beschriftung); zeile.appendChild(feld);
      panel.insertBefore(zeile, panel.children[1] || null);
      return true;
    }
    if (versuch()) return;
    try {
      var beobachter = new MutationObserver(function () { if (versuch()) beobachter.disconnect(); });
      beobachter.observe(document.body, { childList: true, subtree: true });
    } catch (_e) {}
  }

  /* ---- Die Kette, in kanonischer Reihenfolge -------------------------------
     Sages docs/PFLICHT_MODULE.md. Wer hier zwei Zeilen vertauscht, nimmt einem
     Modul seine Voraussetzung: 02 braucht 01, 16 braucht die acht Pflicht-
     Module für seine Selbstprüfung, 23 braucht 05 und 05b, und 17 muss vor 15
     und 16 stehen. */
  var KANON = [
    ["",       "sbkim/03_embedding.js"],
    ["",       "sbkim/01_storage.js"],
    ["",       "sbkim/04_match.js"],
    ["",       "sbkim/02_spore.js"],
    ["",       "sbkim/05_anastomose.js"],
    ["",       "sbkim/23_rendezvous.js"],
    ["",       "sbkim/23_rendezvous_ui.js"],
    ["",       "sbkim/17_floating_widget.js"],
    ["",       "sbkim/07_apoptose.js"],
    ["",       "sbkim/15_membran.js"],
    ["",       "sbkim/16_siegel.js"],
    /* ⚠ 05b IST EIN ES-MODUL und importiert `noble-secp256k1` relativ. Per
       `document.createElement` als klassisches Skript nachgehängt liefe es NIE
       — und ohne es leuchtet das Siegel, während der Raum tot ist (Falle 2,
       Alis Moderaum 2026-08-16). `type="module"` in der Kette ist der Weg, den
       auch der Marktplatz geht: das Modul holt sich noble selbst. */
    ["module", "sbkim/05b_nostr_relay.js"],
    ["",       "assets/pruefer-siegel-inhalt.js"],   // Andock-Werkzeug IM Siegel
    ["",       "assets/pruefer-sbkim-andock-wizard.js"]   // Andock-Werkzeug IM Siegel
  ];

  function pause(f) {
    if (typeof window.requestIdleCallback === "function") {
      window.requestIdleCallback(f, { timeout: 500 });
    } else {
      setTimeout(f, 16);
    }
  }

  function naechste(i, fertig) {
    if (i >= KANON.length) { fertig(); return; }
    var s = document.createElement("script");
    if (KANON[i][0]) s.type = KANON[i][0];
    s.src = KANON[i][1];
    /* onerror WIE onload: eine fehlende Datei darf die Kette nicht anhalten. */
    s.onload = s.onerror = function () { pause(function () { naechste(i + 1, fertig); }); };
    document.body.appendChild(s);
  }

  /* ---- Start-Kette --------------------------------------------------------
     Reihenfolge nach dem Rezept „status-leiste-siegel": Storage → Widget →
     Membran → Siegel → Apoptose → Anastomose → Rendezvous.                  */
  async function starten() {
    try {
      if (!window.SbkimStorage) return;   // Kette nicht angekommen — still bleiben
      await window.SbkimStorage.init({ dbSuffix: NETZ.dbSuffix });

      if (window.SbkimNostrRelay && window.SbkimNostrRelay.configure &&
          Array.isArray(NETZ.relais) && NETZ.relais.length) {
        try { window.SbkimNostrRelay.configure({ relays: NETZ.relais }); } catch (_e) {}
      }

      /* ⚠ MODUL 17 ZUERST — es legt die Anker an, in die sich Membran und
         Siegel hängen. Andersherum hängen beide lautlos ins Leere: die Seite
         sieht normal aus, nur fehlt beides, und niemand bekommt eine Meldung. */
      if (window.SbkimWidget && window.SbkimWidget.init) {
        try {
          await window.SbkimWidget.init({
            allowedOrigins: NETZ.allowedOrigins,
            repoUrl: NETZ.repoUrl
          });
        } catch (_e) {}
      }

      if (window.SbkimMembrane) {
        await window.SbkimMembrane.init({
          allowedOrigins: NETZ.allowedOrigins,
          lampSelector: "#lamp-fremd"
        });
      }

      if (window.SbkimSiegel) {
        /* `ribbonText` ist Pflicht — ohne ihn bleibt das Band im Wappen LEER.
           Modul 16 leitet bewusst nichts aus dem Repo-Namen ab: auf eine
           Auszeichnung gehört kein geratener Name. Und hier steht NICHT
           „PWA TOOLPOINT": das Werkzeug ist ein eigener Knoten, kein Teil des
           Marktplatz-Knotens. */
        window.SbkimSiegel.init({
          badgeSelector: "#sbkim-siegel-badge",
          mountModal: true,
          repoUrl: NETZ.repoUrl,
          ribbonText: "AUSLIEFERUNGSPRÜFER GPT"
        });
      }

      if (window.SbkimApoptose) { try { await window.SbkimApoptose.init(); } catch (_e) {} }
      if (window.SbkimAnastomose) { try { await window.SbkimAnastomose.init(); } catch (_e) {} }

      /* Rendezvous: der Raum, in dem sich Knoten treffen. `init()` baut NICHTS
         auf und ruft NICHTS — es macht die Werkzeuge nur bereit. Angemeldet und
         gesucht wird erst auf ausdrücklichen Klick (Empfangsmodus: kein
         Dauer-Piepser, keine Eigenanfragen ins Netz).

         `ensureIdentity` ABSICHTLICH NICHT (netzweite Stufe 0b, 2026-07-30): es
         legte beim Seiten-Start WORTLOS eine neue Kennung an, wenn die
         Schublade leer war. Aus einem Speicher-Problem wurde so unbemerkt ein
         Identitäts-Wechsel. */
      if (window.SbkimRendezvous) {
        try { window.SbkimRendezvous.init({ nodeName: anzeigeName(), dbSuffix: NETZ.dbSuffix }); } catch (_e) {}
      }
      if (window.SbkimRendezvousUI) {
        try { window.SbkimRendezvousUI.init({ nodeName: anzeigeName(), dbSuffix: NETZ.dbSuffix }); } catch (_e) {}
      }

      geraetenameFeldEinhaengen();
      try {
        window.addEventListener("sbkim:geraetename-changed", function () {
          namensfelderAbgleichen();
          try {
            if (window.SbkimRendezvous && window.SbkimRendezvous.configure) {
              window.SbkimRendezvous.configure({ nodeName: anzeigeName() });
            }
          } catch (_e) {}
        });
      } catch (_e) {}
    } catch (e) {
      if (window.console && console.warn) console.warn("[Prüfer-SBKIM] Andock übersprungen:", e);
    }
  }

  if (document.readyState === "complete") {
    pause(function () { naechste(0, starten); });
  } else {
    window.addEventListener("load", function () {
      pause(function () { naechste(0, starten); });
    });
  }
})();
