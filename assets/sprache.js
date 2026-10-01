/* ==========================================================================
 * PWA Toolpoint — Sprache DE/EN und der Riegel gegen den Auto-Übersetzer.
 *
 * WARUM ES DIESE DATEI GIBT (Klaus 2026-09-14):
 *   „oben ist noch keine Englisch-Übersetzung, so wie jetzt in Family Project
 *    … da das die beiden Seiten sind, die online im Netz sind und somit auch
 *    von anderssprachigen benutzt werden können."
 *
 * Übernommen aus `family-project/assets/app.js` (PR #294 und #296 vom selben
 * Tag) — KOPIERT, NICHT NEU ERFUNDEN. Was dort gemessen wurde, gilt hier
 * genauso; die Unterschiede sind benannt, wo sie stehen.
 *
 * Eigene Datei statt eines Anbaus an `app.js`: fünf Seiten brauchen den
 * Schalter, und `app.js` lädt nur die Startseite. Impressum und Datenschutz
 * laden sonst gar kein Skript außer `thema.js`.
 *
 * ⚠ DIE SPEICHER-SCHLÜSSEL SIND APP-EIGEN (`toolpoint_…`). Auf einer geteilten
 * Adresse liegt der Speicher am Ursprung, nicht an der App — `fp_lang` zu
 * übernehmen hieße, die Sprachwahl mit einer Geschwister-App zu teilen.
 * ========================================================================== */
(function (global) {
  "use strict";

  var LS_SPRACHE = "apgpt_lang";
  var LS_WAHL    = "apgpt_lang_wahl";

  /* ---- Basis-Wörterbuch: Kopf, Fuß, Navigation ---------------------------
   * Die Seiten ergänzen ihre eigenen Texte über `window.PT_SEITE_I18N`, das
   * VOR dieser Datei gesetzt wird. Eine Seite, die nichts ergänzt, bekommt
   * trotzdem Kopf und Fuß auf Englisch. */
  var BASIS = {
    de: {
      nav_eintragen: "Eintragen",
      nav_pruefung: "Wie geprüft wird",
      nav_start: "Zur Startseite",
      nav_markt: "Marktplatz",
      nav_zum_markt: "← Marktplatz",
      nav_zur_app: "← Auslieferungsprüfer",
      nav_app: "Auslieferungsprüfer",
      btn_frisch: "Aktualisieren",
      btn_ueberblick: "Überblick",
      btn_ueberblick_t: "Überblick: was der Prüfer kann und was bei einem Fund zu tun ist",
      fuss_impressum: "Impressum",
      fuss_datenschutz: "Datenschutz",
      fuss_zurueck: "← zur Startseite",
      /* Die Status-Lampen in der Kopfleiste (Klaus 2026-09-14). Sie stehen als
       * Markup in der Seite, nicht in Modul 17 — die Startseite laedt es
       * bewusst nicht, weil sie diese eigene Leiste hat. Der Sprach-Haken des
       * Moduls erreicht sie deshalb NICHT; gemessen headless mit lang="en"
       * standen hier „lebt · verkehr · fremd" zwischen englischen Zeilen.
       * Die Begriffe sind mit Modul 17 abgestimmt (alive/traffic/foreign). */
      lampe_lebt: "lebt",
      lampe_verkehr: "verkehr",
      lampe_fremd: "fremd",
      lampe_lebt_t: "lebt — eigene Identität geladen",
      lampe_verkehr_t: "verkehr — grün, solange am Relais gelauscht wird",
      lampe_fremd_t: "fremd — rot nur bei echtem Fremdzugriff"
    },
    en: {
      nav_eintragen: "Submit",
      nav_pruefung: "How we check",
      nav_start: "To the home page",
      nav_markt: "Marketplace",
      nav_zum_markt: "← Marketplace",
      nav_zur_app: "← Delivery checker",
      nav_app: "Delivery checker",
      btn_frisch: "Refresh",
      btn_ueberblick: "Overview",
      btn_ueberblick_t: "Overview: what the checker does and what to do when it finds something",
      fuss_impressum: "Imprint",
      fuss_datenschutz: "Privacy",
      fuss_zurueck: "← back to the home page",
      lampe_lebt: "alive",
      lampe_verkehr: "traffic",
      lampe_fremd: "foreign",
      lampe_lebt_t: "alive — own identity loaded",
      lampe_verkehr_t: "traffic — green while listening on the relay",
      lampe_fremd_t: "foreign — red only on a real foreign access"
    }
  };

  function woerterbuch() {
    var seite = global.PT_SEITE_I18N || {};
    var aus = { de: {}, en: {} };
    ["de", "en"].forEach(function (l) {
      var a = BASIS[l] || {}, b = seite[l] || {}, k;
      for (k in a) aus[l][k] = a[k];
      for (k in b) aus[l][k] = b[k];
    });
    return aus;
  }
  var I18N = woerterbuch();

  var sprache = "de";
  try {
    var g = localStorage.getItem(LS_SPRACHE);
    if (g === "de" || g === "en") sprache = g;
  } catch (_e) {}

  function getLang() { return sprache; }

  function anwenden(l) {
    sprache = (l === "en") ? "en" : "de";
    try { localStorage.setItem(LS_SPRACHE, sprache); } catch (_e) {}
    document.documentElement.lang = sprache;
    var buch = I18N[sprache] || {};
    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      var k = el.getAttribute("data-i18n");
      if (buch[k] != null) el.textContent = buch[k];
    });
    /* ⚠ EIN ABSATZ MIT AUSZEICHNUNG DARIN VERTRÄGT KEIN `textContent`.
       Viele Sätze auf diesen Seiten tragen ein <b>, einen Link oder ein <code>.
       `textContent = …` würfe die alle weg — die Seite wäre auf Englisch ärmer
       als auf Deutsch, und zwar still. Für diese Stellen gibt es `data-i18n-html`.
       Das Wörterbuch ist eigener, mitgelieferter Text und keine fremde Eingabe;
       es kommt nichts aus dem Netz und nichts von einem Nutzer hier hinein. */
    document.querySelectorAll("[data-i18n-html]").forEach(function (el) {
      var k = el.getAttribute("data-i18n-html");
      if (buch[k] != null) el.innerHTML = buch[k];
    });
    document.querySelectorAll("[data-i18n-ph]").forEach(function (el) {
      var k = el.getAttribute("data-i18n-ph");
      if (buch[k] != null) el.setAttribute("placeholder", buch[k]);
    });
    /* ⚠ AUCH `title` UND `aria-label` SIND TEXT FÜR MENSCHEN. Ein Knopf, dessen
       sichtbarer Name englisch ist und dessen Vorlese-Name deutsch bleibt, ist
       für jemanden mit Vorlese-Programm gar nicht übersetzt. */
    document.querySelectorAll("[data-i18n-titel]").forEach(function (el) {
      var k = el.getAttribute("data-i18n-titel");
      if (buch[k] == null) return;
      el.setAttribute("title", buch[k]);
      if (el.hasAttribute("aria-label")) el.setAttribute("aria-label", buch[k]);
    });
    knopfBeschriften();
    /* Wer sonst noch etwas nachzuziehen hat, hört zu — die Einträge tun das
       (`karte.js` zeichnet sie mit dem englischen Text neu). Ein direkter
       Aufruf von hier aus wäre eine Abhängigkeit auf eine Datei, die zwei der
       fünf Seiten gar nicht laden. */
    try { global.dispatchEvent(new CustomEvent("pt:sprache", { detail: { lang: sprache } })); } catch (_e) {}
  }

  /* ---- Der Sprachriegel ---------------------------------------------------
   *
   * Klaus am 2026-09-14 an family-projekt.de, nachdem der Riegel auf Eigennamen
   * schon stand: „Ich klicke in der App das zwar an, aber Google Chrome zieht
   * wieder rüber und übernimmt wieder … Er zeigt ganz kurz Englisch an und
   * springt dann wieder auf Deutsch."
   *
   * Was passiert: sein Chrome hat „Englisch immer übersetzen" gesetzt. Er
   * drückt EN, die Seite wird englisch und setzt `lang="en"` — und genau das
   * löst die Regel aus. Chrome übersetzt sofort zurück.
   *
   * DREI FÄLLE, NICHT ZWEI:
   *
   *   niemand hat gewählt     → Google DARF übersetzen. Das ist der Fall, der
   *                             zählt: wer weder Deutsch noch Englisch liest,
   *                             hätte sonst keinen Weg.
   *   der Nutzer hat gewählt  → die APP gewinnt, in BEIDEN Richtungen: wer
   *                             Deutsch wählt, will auch kein übersetztes
   *                             Deutsch.
   *   Google war schneller    → die Seite sagt es, statt raten zu lassen.
   *
   * Gesperrt wird auf drei Wegen zugleich, weil keiner allein in jedem Browser
   * greift: `translate="no"` am Wurzelelement, die Klasse `notranslate` und
   * `<meta name="google" content="notranslate">`.
   *
   * ⚠ DER RIEGEL IM <head> IST DER EIGENTLICHE — eine Zeile ganz oben in jeder
   * Seite, die VOR dem ersten Anstrich läuft. Danach hat Chrome längst
   * entschieden. Was hier steht, ist der Teil für den Augenblick des Klicks.
   *
   * ⚠ EINE AUSDRÜCKLICHE WAHL IST NICHT DIE AKTUELLE SPRACHE. `apgpt_lang`
   * steht bei jedem Start; wäre das der Maßstab, wäre jeder Besucher sofort
   * gesperrt, auch der, der nie etwas gewählt hat. Die Wahl hängt deshalb an
   * einem EIGENEN Schlüssel, den nur ein Klick setzt. */
  function sperren() {
    var h = document.documentElement;
    h.setAttribute("translate", "no");
    h.classList.add("notranslate");
    if (!document.querySelector('meta[name="google"][content="notranslate"]')) {
      var m = document.createElement("meta");
      m.name = "google"; m.content = "notranslate";
      (document.head || h).appendChild(m);
    }
  }

  /* Chromes Übersetzer hängt beim Übersetzen `translated-ltr` bzw.
     `translated-rtl` ans Wurzelelement. Daran — und nur daran — lässt sich von
     der Seite aus erkennen, dass er zugegriffen hat. */
  function googleHatUebersetzt() {
    return /(^|\s)translated-(ltr|rtl)(\s|$)/.test(document.documentElement.className || "");
  }

  function hatGewaehlt() {
    try { return localStorage.getItem(LS_WAHL) === "1"; } catch (_e) { return false; }
  }

  /* DER DRITTE FALL: gewählt, und Chrome übersetzt trotzdem.
   *
   * Klaus über Chromes eigene Leiste: „Die taucht ab und zu kurz auf … oder
   * manchmal zeigt sie's gar nicht an." Also keine verlässliche Auskunft. Die
   * Seite sagt es selbst, und bleibend — aber NUR, wenn beides zutrifft: eine
   * Wahl liegt vor UND der Übersetzer hat zugegriffen. Wer Google absichtlich
   * benutzt, hat nie gewählt und sieht den Hinweis nie; sonst wäre er Lärm für
   * genau die Besucher, für die der Übersetzer angelassen wurde.
   *
   * `position:fixed`, damit er nichts verschiebt. Und `translate="no"` trägt er
   * selbst — sonst übersetzte Chrome ausgerechnet den Satz, der von Chromes
   * Übersetzung handelt. */
  function hinweis() {
    if (document.getElementById("ptUebersetzerHinweis")) return;
    var de = getLang() === "de";
    var k = document.createElement("div");
    k.id = "ptUebersetzerHinweis";
    k.className = "pt-ue-hinweis notranslate";
    k.setAttribute("translate", "no");
    k.setAttribute("role", "status");

    var satz = document.createElement("span");
    satz.textContent = de
      ? "Dein Browser übersetzt diese Seite zusätzlich — deshalb springt sie zurück."
      : "Your browser is translating this page on top — that is why it jumps back.";
    var weg = document.createElement("span");
    weg.className = "pt-ue-weg";
    weg.textContent = de
      ? "In Chrome: Menü (⋮) → Übersetzen → dort „nie übersetzen“ wählen."
      : "In Chrome: menu (⋮) → Translate → choose “never translate” there.";

    var zu = document.createElement("button");
    zu.type = "button";
    zu.className = "pt-ue-zu";
    zu.textContent = "✕";
    zu.setAttribute("aria-label", de ? "Hinweis schließen" : "dismiss notice");
    zu.addEventListener("click", function () { k.remove(); });

    k.appendChild(satz); k.appendChild(weg); k.appendChild(zu);
    document.body.appendChild(k);
  }

  /* Chrome übersetzt NACH dem Laden. Ein einmaliger Blick beim Start sähe die
     Klasse nie — gewartet wird deshalb auf die BEDINGUNG, nicht auf die Uhr.
     Ein `setTimeout` mit runder Zahl wäre ein Rennen, das auf einem langsamen
     Gerät still verloren geht. */
  function beobachten() {
    if (!hatGewaehlt()) return;               // wer nicht gewählt hat, wird nicht belästigt
    if (googleHatUebersetzt()) { hinweis(); return; }
    if (!global.MutationObserver) return;
    var beo = new global.MutationObserver(function () {
      if (googleHatUebersetzt()) { hinweis(); beo.disconnect(); }
    });
    try { beo.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] }); } catch (_e) {}
  }

  /* DER WEG ZURÜCK. Ohne ihn wäre ein einziger Klick eine Einbahnstraße: wer
     den Sprachknopf einmal gedrückt hat, bekäme den Übersetzer nie wieder — und
     das träfe ausgerechnet die Besucher, für die er angelassen wurde. Ein
     langer Druck nimmt die Wahl zurück, dasselbe Muster wie der versteckte
     Zugang zur Knotenkarte an der Marke.
     ⚠ BENANNTE GRENZE: ein langer Druck ist versteckt. Er steht im Vorlese-Namen
     des Knopfes — keine Lösung für alle, aber besser als kein Weg. */
  function wahlZuruecknehmen() {
    try { localStorage.removeItem(LS_WAHL); } catch (_e) {}
    try { location.reload(); } catch (_e) {}
  }
  function langerDruck(el) {
    if (!el) return;
    var uhr = null;
    var los = function () { uhr = global.setTimeout(wahlZuruecknehmen, 1500); };
    var stop = function () { if (uhr) { global.clearTimeout(uhr); uhr = null; } };
    el.addEventListener("pointerdown", los);
    ["pointerup", "pointerleave", "pointercancel"].forEach(function (e) { el.addEventListener(e, stop); });
  }

  function waehlen(l) {
    try { localStorage.setItem(LS_WAHL, "1"); } catch (_e) {}
    anwenden(l);
    sperren();
    /* Hat Chrome die Seite schon übersetzt, nützt das Sperren jetzt nichts mehr
       — es greift erst beim nächsten Aufbau. Also neu laden. Eine Schleife kann
       daraus nicht werden: das hier läuft nur auf einen Klick. */
    if (googleHatUebersetzt()) { try { location.reload(); } catch (_e) {} }
  }

  /* ---- Der Knopf ---------------------------------------------------------
   * Ein echtes `<button>`, kein `<span>`: sonst gibt es keinen Tabulator-Halt,
   * und wer die Seite mit der Tastatur bedient, kommt an die Sprache gar nicht
   * heran. In family-project musste das nachträglich mit `role`+`tabindex`
   * geflickt werden, weil die Pillen dort schon als `<span>` standen — hier
   * entsteht der Knopf neu, also gleich richtig. */
  function knopfBeschriften() {
    var b = document.getElementById("sprachKnopf");
    if (!b) return;
    var de = getLang() === "de";
    b.setAttribute("aria-label", de
      ? "Sprache umschalten, Deutsch oder Englisch. Langer Druck: Browser-Übersetzer wieder zulassen"
      : "switch language, German or English. Long press: allow the browser translator again");
    b.setAttribute("title", de ? "Sprache / Language" : "Language / Sprache");
    b.setAttribute("aria-pressed", de ? "false" : "true");
  }

  function knopfVerdrahten() {
    var b = document.getElementById("sprachKnopf");
    if (!b) return;
    b.addEventListener("click", function () { waehlen(getLang() === "de" ? "en" : "de"); });
    langerDruck(b);
  }

  /* ---- Riegel für Eigennamen ---------------------------------------------
   *
   * Der Übersetzer bleibt AN (Klaus' Entscheidung am 2026-09-14, solange
   * niemand gewählt hat). Geschützt wird deshalb GEZIELT: Eigennamen und
   * Bedienelemente, nie der Fließtext. Was ein Eigenname ist, entscheidet nicht
   * der Riegel, sondern diese Liste — an EINER Stelle, nicht in fünf Seiten
   * verteilt.
   *
   * Gemessen an family-projekt.de, wo der Übersetzer ohne Riegel aus „Hell"
   * ein „Hölle" und aus dem Markennamen ein „Familienprojekt" machte. */
  var EIGENNAMEN = [
    ".brand",                  // „PWA Toolpoint" — Kopf und Fuß
    "#themaKnopf",             // „Nacht" · „Signal" · „Tag" sind Themen-Namen
    ".lamps",                  // lebt · verkehr · fremd
    "#sbkim-rdv-btn",          // die schwebende Pille „🌐 Mycel"
    "#sbkim-rdv-myid",         // Kennungen sind Zeichenketten, kein Text
    "#sbkim-siegel-badge",
    ".mic-lang",               // Sprachnamen: „Türkçe" bleibt „Türkçe"
    ".listing h3",             // App-Namen: „Mein Rezeptbuch" ist ein Name, kein Satz
    ".listing .by",            // @handle
    ".fund-karte h3",
    "[data-eigenname]"         // freier Haken für die Seiten
  ];

  function riegeln(wurzel) {
    var n = 0;
    for (var i = 0; i < EIGENNAMEN.length; i++) {
      var treffer;
      try { treffer = (wurzel || document).querySelectorAll(EIGENNAMEN[i]); } catch (_e) { continue; }
      for (var j = 0; j < treffer.length; j++) {
        var el = treffer[j];
        if (el.getAttribute("translate") === "no") continue;
        el.setAttribute("translate", "no");
        /* Chrome sieht auf BEIDES; `translate="no"` ist der Standard, die Klasse
           ist Googles eigener Weg. Einer allein hat in der Praxis schon
           versagt, und zwei kosten nichts. */
        el.classList.add("notranslate");
        n++;
      }
    }
    return n;
  }

  /* Die SBKIM-Module hängen ihre Elemente ERST NACH dem Laden ein (die Kette
     läuft in der Leerlauf-Pause). Ein einmaliger Durchgang beim Start würde die
     schwebende Pille also nie erwischen. Gewartet wird auf die BEDINGUNG. */
  function riegelBeobachten() {
    riegeln(document);
    if (!global.MutationObserver) return;
    var beo = new global.MutationObserver(function (aenderungen) {
      for (var i = 0; i < aenderungen.length; i++) {
        if (aenderungen[i].addedNodes && aenderungen[i].addedNodes.length) { riegeln(document); return; }
      }
    });
    try { beo.observe(document.body, { childList: true, subtree: true }); } catch (_e) {}
  }

  function starten() {
    I18N = woerterbuch();       // die Seite kann ihr Wörterbuch erst jetzt gesetzt haben
    anwenden(sprache);
    knopfVerdrahten();
    riegelBeobachten();
    beobachten();
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", starten);
  else starten();

  /* ⚠ EIN SATZ AUS DEM SKRIPT BRAUCHT DENSELBEN WEG WIE EINER AUS DEM MARKUP.
   * `data-i18n` deckt nur ab, was in der Seite steht. Was ein Skript zur
   * Laufzeit schreibt (eine Rückmeldung an einem Knopf, eine Marke in einem
   * Bericht), hat bis zum 2026-09-21 fest verdrahtet Deutsch getragen — auf
   * Englisch stand danach ein deutsches Wort auf dem Knopf.
   *
   * ⚠ UND ES FÄLLT NIE AUF DEN SCHLÜSSELNAMEN ZURÜCK. Genau das hat in Mein
   * Rezeptbuch „+ hAddLbl hinzufügen" auf den Schirm gebracht: `T(k)` gab bei
   * einem fehlenden Schlüssel den Schlüssel heraus, also immer etwas Wahres,
   * und ein `|| 'Rückfall'` dahinter konnte nie greifen. Hier sind es drei
   * Stufen, und die letzte ist der deutsche Satz, der im Code daneben steht. */
  function text(k, deutsch) {
    var w = I18N[sprache] || {};
    if (w[k]) return w[k];
    if (I18N.de && I18N.de[k]) return I18N.de[k];
    return deutsch || "";
  }

  global.PTSprache = {
    getLang: getLang,
    text: text,
    anwenden: anwenden,
    waehlen: waehlen,
    hatGewaehlt: hatGewaehlt,
    googleHatUebersetzt: googleHatUebersetzt,
    riegeln: riegeln,
    eigennamen: EIGENNAMEN,
    schluessel: { sprache: LS_SPRACHE, wahl: LS_WAHL }
  };
})(window);
