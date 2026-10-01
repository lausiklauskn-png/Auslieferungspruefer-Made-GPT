/* ============================================================================
 * PWA Toolpoint — die zwei Werkzeuge in der Kopfleiste:
 *   ◐ Thema wechseln (Nacht · Signal · Tag)
 *   ⟳ Aktualisieren  (Vorrat wegwerfen und wirklich neu laden)
 *
 * Drei Themen wie bei Family Projekt, aber in eigenem Ton: dort Minze auf
 * Blauschwarz, hier Bernstein auf Graphit. Gleiche Bauart, andere Handschrift.
 *
 * ZWEI UNTERSCHIEDE ZUR VORLAGE, beide mit Grund:
 *
 * 1 · Das Thema hängt an einem Attribut (`data-thema` am <html>), nicht an
 *     einzeln gesetzten CSS-Variablen. Die Farben stehen damit vollständig im
 *     Stylesheet — man sieht sie an einer Stelle statt in zwei, und der
 *     Umschalter selbst kennt gar keine Farbe mehr.
 *
 * 2 · Gesetzt wird das Attribut von einem winzigen Schnipsel im <head>, VOR dem
 *     ersten Anstrich. Wer sein Thema gewählt hat, sieht es sofort — nicht
 *     erst, wenn diese Datei geladen ist. Sonst blitzt bei jedem Aufruf kurz
 *     das Standard-Thema auf.
 *
 * Der Knopf ist ein echter `<button>`. Ein Element, das etwas auslöst, muss mit
 * der Tastatur erreichbar sein.
 * ========================================================================== */
(function () {
  "use strict";

  /* App-eigener Schlüssel: alle Seiten auf GitHub Pages teilen sich eine
     Adresse, und ein allgemeiner Name würde sich mit den Geschwister-Apps
     ins Gehege kommen. */
  var SPEICHER = "apgpt_thema";
  var THEMEN = [
    { schluessel: "nacht",  name: "Nacht",  zeichen: "◐" },
    { schluessel: "signal", name: "Signal", zeichen: "◑" },
    { schluessel: "tag",    name: "Tag",    zeichen: "○" }
  ];

  function aktuelles() {
    var gesetzt = document.documentElement.getAttribute("data-thema") || "tag";
    for (var i = 0; i < THEMEN.length; i++) if (THEMEN[i].schluessel === gesetzt) return i;
    return 0;
  }

  function anwenden(i) {
    var t = THEMEN[((i % THEMEN.length) + THEMEN.length) % THEMEN.length];
    document.documentElement.setAttribute("data-thema", t.schluessel);
    try { localStorage.setItem(SPEICHER, t.schluessel); } catch (_e) {}
    beschriften(t);
  }

  function beschriften(t) {
    var knopf = document.getElementById("themaKnopf");
    if (!knopf) return;
    var naechstes = THEMEN[(THEMEN.indexOf(t) + 1) % THEMEN.length];
    var zeichenEl = knopf.querySelector(".thema-zeichen");
    var nameEl = knopf.querySelector(".thema-name");
    if (zeichenEl) zeichenEl.textContent = t.zeichen;
    if (nameEl) nameEl.textContent = t.name;
    /* Der Vorlese-Name sagt, was der Knopf TUT, nicht was gerade eingestellt
       ist — sonst hört jemand „Nacht" und weiß nicht, was beim Drücken kommt. */
    knopf.setAttribute("aria-label", "Thema wechseln — aktuell " + t.name +
                                     ", weiter zu " + naechstes.name);
    knopf.title = "Thema wechseln (weiter zu " + naechstes.name + ")";
  }

  /* ---- Aktualisieren -----------------------------------------------------
   * Nach jedem neuen Stand hängen zwei Speicher hartnäckig: der Vorrat des
   * Service-Workers und der HTTP-Cache des Browsers. Ein gewöhnliches Neuladen
   * kommt an beiden nicht vorbei — Klaus musste dafür bisher „Cache leeren und
   * neu laden" im Chrome-Menü suchen. Dieser Knopf macht dieselben drei
   * Schritte, aber als Knopf in der Seite:
   *
   *   1. jeden Vorrat wegwerfen,
   *   2. den Service-Worker abmelden (der nächste Aufruf installiert frisch),
   *   3. mit einer neuen Adresse laden — nur eine GEÄNDERTE Adresse ist für
   *      den HTTP-Cache eine andere Datei. `location.reload()` genügt hier
   *      nicht, und das alte `reload(true)` ignorieren die Browser längst.
   *
   * Der Anhängsel wird beim nächsten Start wieder aus der Adresszeile geputzt,
   * damit niemand eine Adresse mit `?frisch=…` weitergibt.
   *
   * Fail-soft: kann der Browser einen Schritt nicht, wird trotzdem geladen. Ein
   * Aktualisieren-Knopf, der bei einem Fehler gar nichts tut, wäre schlimmer
   * als keiner. */
  async function aktualisieren(knopf) {
    if (knopf) { knopf.disabled = true; var alt = knopf.textContent; knopf.textContent = "⟳ lädt …"; }
    try {
      if (window.caches && caches.keys) {
        var namen = await caches.keys();
        await Promise.all(namen.filter(function (n) { return n.indexOf("ap-gpt-") === 0; }).map(function (n) { return caches.delete(n); }));
      }
    } catch (_e) {}
    try {
      if (navigator.serviceWorker && navigator.serviceWorker.getRegistrations) {
        var regs = await navigator.serviceWorker.getRegistrations();
        await Promise.all(regs.filter(function (r) { return r.scope === new URL("./", location.href).href; }).map(function (r) { return r.unregister(); }));
      }
    } catch (_e) {}
    location.replace(location.pathname + "?frisch=" + Date.now());
  }

  /* Das Anhängsel aus der Adresszeile nehmen — ohne neu zu laden. */
  function adresseAufraeumen() {
    try {
      if (!/[?&]frisch=/.test(location.search)) return;
      if (!window.history || !history.replaceState) return;
      history.replaceState(null, "", location.pathname + location.hash);
    } catch (_e) {}
  }

  /* ── Die klebende Kopfleiste und die Sprungziele ──────────────────────────
   * Klaus 2026-09-21: er klickt auf der Detailseite „Ausführlich: wie hier
   * geprüft wird →", landet auf dem Marktplatz — und die versprochene
   * Überschrift steht hinter der Kopfleiste.
   *
   * `scroll-padding-top` im Stylesheet löst das, braucht aber eine Zahl. Die
   * Leiste ist je Seite und Breite zwischen 61 und 185 px hoch (gemessen über
   * zehn Breiten), also wird sie ABGELESEN statt geraten. Ohne diese Datei
   * gilt der Rückfall aus dem Stylesheet — dann steht die Überschrift tiefer
   * als nötig, aber sie steht da. */
  var LUFT = 10;

  function kopfHoeheSetzen() {
    var kopf = document.querySelector("header");
    if (!kopf) return;
    var h = Math.round(kopf.getBoundingClientRect().height);
    /* Eine 0 wäre schlimmer als der Rückfall: dann klebte das Ziel wieder
       unter der Leiste, nur ohne dass man es dem Stylesheet ansieht. */
    if (h > 0) document.documentElement.style.setProperty("--kopf-hoehe", (h + LUFT) + "px");
  }

  /* ⚠ UND DER FALL, AUF DEN ES ANKOMMT, IST DER SPRUNG BEIM LADEN.
   * Klaus' Weg ist ein Sprung von EINER Seite auf eine andere (`../../#pruefung`).
   * Den macht der Browser, bevor diese Datei läuft — also mit dem Rückfall,
   * nicht mit der gemessenen Höhe. Deshalb wird er danach EINMAL nachgezogen.
   *
   * Nur einmal und nur beim Start: wer inzwischen selbst gescrollt hat, wird
   * nicht zurückgerissen — ein Sprung, den der Nutzer nicht ausgelöst hat,
   * wäre schlimmer als ein paar Pixel zu viel Luft. */
  function sprungNachziehen() {
    var id = (location.hash || "").slice(1);
    if (!id) return;
    var ziel = null;
    try { ziel = document.getElementById(decodeURIComponent(id)); } catch (e) { ziel = null; }
    if (!ziel) return;

    /* ⚠ EIN HARTER SPRUNG UND EINE LAUFENDE WEICHE BEWEGUNG KAEMPFEN
       GEGENEINANDER. `html { scroll-behavior: smooth }` laesst schon den
       Sprung des Browsers ANIMIEREN; wer mittendrin hart springt, wird von
       der weiterlaufenden Animation wieder weggezogen — und zwar mal mehr,
       mal weniger. Gemessen am unveraenderten Baum, drei Laeufe derselben
       Datei: Abstand 34 · 50 · 34 px, einmal ueber der Grenze.
       Fuer diese eine Korrektur wird die Weichheit deshalb abgeschaltet;
       ein Sprung mit `auto` bricht die laufende Animation ab, statt neben
       ihr herzulaufen. Danach steht sie wieder, wo sie stand. */
    var wurzel = document.documentElement;
    var vorher = wurzel.style.scrollBehavior;
    wurzel.style.scrollBehavior = "auto";
    ziel.scrollIntoView({ block: "start", behavior: "auto" });
    wurzel.style.scrollBehavior = vorher;
  }

  function start() {
    adresseAufraeumen();

    kopfHoeheSetzen();
    sprungNachziehen();
    /* Die Leiste bricht bei schmalen Breiten in mehrere Reihen um — wer das
       Fenster dreht, bekommt eine andere Höhe. `rAF` statt eines Zeitgebers:
       gemessen wird, wenn der Browser ohnehin neu zeichnet. */
    var laeuft = false;
    window.addEventListener("resize", function () {
      if (laeuft) return;
      laeuft = true;
      requestAnimationFrame(function () { laeuft = false; kopfHoeheSetzen(); });
    });

    var knopf = document.getElementById("themaKnopf");
    if (knopf) {
      beschriften(THEMEN[aktuelles()]);
      knopf.addEventListener("click", function () { anwenden(aktuelles() + 1); });
    }

    var frisch = document.getElementById("frischKnopf");
    if (frisch) {
      frisch.addEventListener("click", function () { aktualisieren(frisch); });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
