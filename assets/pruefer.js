/* Auslieferungsprüfer — die Prüf-Logik.
 *
 * HERKUNFT: gebaut in der Kimhub-Werkstatt am 2026-08-20 als Python-Werkzeug
 * (`werkzeuge/auslieferung-pruefer/pruefe-seite.py`, Emils Vorschlag, in der
 * Ideen-Konferenz mit 20 von 20 möglichen Fremdstimmen angenommen). Diese Datei
 * ist die Browser-Fassung davon, damit man den Prüfer ohne Python benutzen kann.
 *
 * ⚠ ZWEI FASSUNGEN, EIN ERGEBNIS. Die Python-Fassung bleibt für die Prüfkette
 * (Rückgabewert 0/1/2 in einem Skript). Beide MÜSSEN auf der Köderseite exakt
 * dieselben Befunde mit denselben Zeilennummern liefern — sonst laufen sie
 * auseinander, und dann glaubt man der falschen. `tests/smoke_pruefer.mjs`
 * vergleicht sie Zeile für Zeile gegeneinander.
 *
 * WARUM EIN EIGENER SCANNER UND NICHT `DOMParser`. Der Browser-Parser wäre
 * bequemer, liefert aber KEINE Zeilennummern — er gibt einen Baum zurück, keine
 * Stellen im Text. Ein Befund ohne Zeile ist für den, der ihn beheben soll,
 * fast wertlos: er weiß, dass etwas da ist, aber nicht wo. Und `DOMParser`
 * repariert stillschweigend kaputtes Markup, verschiebt Elemente in den Body
 * und ergänzt fehlende Tags — dann prüft man am Ende nicht die ausgelieferte
 * Datei, sondern die Reparatur des Browsers.
 *
 * Läuft in beiden Welten (Browser und Node), wie die SBKIM-Module — damit die
 * Probe genau den Code prüft, den der Besucher ausführt, und nicht einen
 * nachgebauten Zwilling.
 */
(function (welt) {
  "use strict";

  var BEFUNDE = ["FREMDE-ADRESSE", "FUELLTEXT", "BILD-OHNE-ALT", "LEERER-LINK", "KEINE-SPRACHE"];

  /* Attribute, in denen eine Adresse stehen kann. `srcset` und `content` sind
     leicht zu vergessen — ein og:image aus dem Netz ist genauso eine fremde
     Adresse wie ein <script src>. */
  /* ⚠ `background` und `ping` ergänzt 2026-08-23, an der laufenden Fassung
     gemessen: beide wurden nicht gemeldet. `background` am <body> laden alle
     grossen Browser bis heute; `ping` schickt beim Klick eine Meldung an eine
     fremde Adresse — Nachverfolgung ohne eine Zeile JavaScript, also nicht von
     der Grenze "fuehrt kein JS aus" gedeckt. */
  var ADRESS_ATTRIBUTE = ["src", "srcset", "poster", "data", "action",
                          "formaction", "content", "imagesrcset",
                          "background", "ping"];

  /* `href` ist zweierlei. Bei <link> und <base> HOLT die Seite etwas; bei <a>
     geht der Besucher weg, wenn er klickt — das ist keine fremde Ladung,
     sondern ein ganz normaler Link. An Klaus' echten Seiten gemessen
     (2026-08-20) waren 27 von 58 Meldungen genau solche Links. Eine Warnung,
     die man nicht mehr los wird, ist keine Warnung. */
  /* ⚠ `image` und `use` ergaenzt 2026-08-23. Ein <svg image href> und ein
     <svg use href> HOLEN, genau wie ein <img src> — sie standen nicht in der
     Liste, und beide Fassungen meldeten sie nicht. Gemessen, nicht vermutet. */
  var HREF_LAEDT = ["link", "base", "image", "use"];

  /* Schemata, die keine fremde Adresse sind: sie holen nichts nach. */
  /* ⚠ `cid:` GEHOERT DAZU, seit Klaus eine gespeicherte Seite geprueft hat
     (2026-09-11). Chrome legt beim Herunterladen eine `.mhtml` an und
     verweist darin mit `cid:...@mhtml.blink` auf die Teile IM SELBEN
     Behaelter — die lokalste Adresse, die es gibt. Gemeldet wurden sie als
     „holt von einem fremden Rechner: cid:", also drei Befunde ueber etwas,
     das gar nicht ins Netz greift.

     Und genau dieser Weg ist der, den das Tablet nimmt: `view-source:` sperrt
     Chrome dort, „Adresse abrufen" scheitert an der Browser-Sperre — was
     immer geht, ist der Herunterladen-Pfeil. Eine Warnung, die bei jedem
     Aufruf auf diesem Weg erscheint, ist eine, die man nicht mehr los wird. */
  var HARMLOS = ["data", "mailto", "tel", "sms", "about", "blob", "javascript", "cid"];

  /* An Klaus' echten Seiten geeicht (2026-08-20). Vier Wörter sind bewusst
     NICHT darin, obwohl sie naheliegen:
       `placeholder` ist ein gültiges HTML-Attribut (32 Treffer, alle harmlos),
       `platzhalter` ein gewöhnliches deutsches Wort im Quelltext (24 Treffer).
     Wer sie aufnimmt, bekommt auf jeder Seite mit einem Formular Lärm.

     ⚠ `deine adresse` und `dein name` sind am 2026-08-23 DAZUGEKOMMEN, auf
     Klaus' Bericht einer echten Seite. Beide sind gewöhnliches Deutsch, und
     beide standen an Stellen, an denen sie hingehören — nachgezählt in seinen
     Depots:
       „Andere verweisen nur auf deine Adresse."   (Fließtext, Sage-Protokol)
       `<label>Dein Name (optional)</label>`       (Formular, family-project)
     Das zweite ist derselbe Fall wie `placeholder`: ein echtes Etikett ist von
     einem vergessenen Platzhalter nicht zu unterscheiden. Wo man nicht
     entscheiden kann, meldet man nicht — sonst ist es eine Warnung, die man
     nicht mehr los wird. */
  var FUELLWOERTER = [
    "lorem ipsum", "todo", "fixme", "tbd", "xxx",
    "max mustermann", "max.mustermann", "musterstr", "musterfrau",
    "beispiel gmbh", "muster gmbh", "example.com", "example.org",
    "ihre firma",
    "coming soon", "hier text", "blindtext", "0123456789"
  ];

  function maskiere(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }

  /* Auf WORTGRENZE, nicht als Teilzeichenkette. Ohne das meldet `tbd` die
     Knopf-Kennung `tbDark` — auch das ist an einer echten Seite passiert.

     ⚠ JavaScripts `\b` rechnet nur mit A–Z, a–z, 0–9 und _. Bei Wörtern mit
     Punkt (`example.com`, `max.mustermann`) säße die Grenze deshalb an der
     falschen Stelle. Darum wird die Grenze selbst gebaut: davor und danach darf
     kein Wortzeichen stehen. Python macht mit `\b` dasselbe, weil dort der
     Punkt ebenfalls kein Wortzeichen ist — das Ergebnis stimmt also überein. */
  var FUELL_MUSTER = FUELLWOERTER.map(function (w) {
    return { wort: w, muster: new RegExp("(?:^|[^A-Za-z0-9_])" + maskiere(w) + "(?![A-Za-z0-9_])", "i") };
  });

  /* Gibt die fremden Wirte in einem Attributwert zurück (leer = harmlos).

     `srcset` trägt mehrere Adressen, durch Komma getrennt — wer nur die erste
     liest, übersieht die Bilder für große Bildschirme. Getrennt wird an JEDEM
     Komma: nach dem HTML-Standard dürfen Kommata in einer `srcset`-Adresse
     ohnehin nicht roh stehen, sie müssen %2C geschrieben werden. In der
     Python-Fassung stand hier eine Weile ein Ausdruck, der Kommata in Klammern
     schützte; nachgemessen machte er keinen Unterschied, und ein Riegel, den
     keine Probe von seinem Fehlen unterscheiden kann, ist eine Behauptung. */
  function wirte(wert) {
    var gefunden = [];
    var teile = String(wert || "").split(",");
    for (var i = 0; i < teile.length; i++) {
      var w = teile[i].trim().split(" ")[0].trim();
      if (!w) continue;
      if (w.indexOf("//") === 0) {                      /* protokoll-relativ */
        gefunden.push(w.slice(2).split("/")[0]);
        continue;
      }
      var m = /^([A-Za-z][A-Za-z0-9+.\-]*):([\s\S]*)$/.exec(w);
      if (!m) continue;                                  /* relativ oder Anker */
      var schema = m[1].toLowerCase(), rest = m[2];
      if (HARMLOS.indexOf(schema) !== -1) continue;
      if ((schema === "http" || schema === "https") && rest.indexOf("//") === 0) {
        gefunden.push(rest.slice(2).split("/")[0]);
      } else if (schema !== "http" && schema !== "https") {
        gefunden.push(schema + ":");                     /* ftp:, ws: und Verwandte */
      }
    }
    return gefunden;
  }

  /* Liest die Attribute eines Starttags. Kleingeschrieben, wie im Parser. */
  function attribute(roh) {
    var a = {}, re = /([A-Za-z_:][-A-Za-z0-9_:.]*)\s*(?:=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g, m;
    while ((m = re.exec(roh)) !== null) {
      var wert = m[2] !== undefined ? m[2] : (m[3] !== undefined ? m[3] : (m[4] !== undefined ? m[4] : ""));
      a[m[1].toLowerCase()] = wert;
    }
    return a;
  }

  function entitaeten(s) {
    return String(s)
      .replace(/&lt;/gi, "<").replace(/&gt;/gi, ">")
      .replace(/&quot;/gi, '"').replace(/&#39;/g, "'")
      .replace(/&amp;/gi, "&");
  }

  /**
   * Prüft einen HTML-Text.
   * @param {string} text     der Quelltext der Seite
   * @param {string[]} erlaubt  Wirte, die nicht als fremd gelten (z. B. die eigene Domain)
   * @returns {{zeile:number, kennung:string, satz:string}[]} nach Zeile sortiert
   */
  function pruefe(text, erlaubt) {
    text = String(text == null ? "" : text);
    erlaubt = (erlaubt || []).map(function (e) { return String(e).toLowerCase().trim(); })
                             .filter(Boolean);

    var treffer = [];
    var htmlGesehen = false;

    function melde(zeile, kennung, satz) {
      if (kennung === "FREMDE-ADRESSE") {
        var wirt = satz.split(": ").pop();
        for (var i = 0; i < erlaubt.length; i++) {
          if (wirt === erlaubt[i] || wirt.slice(-(erlaubt[i].length + 1)) === "." + erlaubt[i]) return;
        }
      }
      treffer.push({ zeile: zeile, kennung: kennung, satz: satz });
    }

    /* Zeilennummer einer Stelle im Text. Der Parser meldet die Zeile des
       `<`-Zeichens; bei einem über mehrere Zeilen umbrochenen Tag ist das die
       ERSTE Zeile — genau wie in der Python-Fassung. */
    var zeilenanfaenge = [0];
    for (var p = 0; p < text.length; p++) if (text.charCodeAt(p) === 10) zeilenanfaenge.push(p + 1);
    function zeileVon(pos) {
      var lo = 0, hi = zeilenanfaenge.length - 1;
      while (lo < hi) {
        var mid = (lo + hi + 1) >> 1;
        if (zeilenanfaenge[mid] <= pos) lo = mid; else hi = mid - 1;
      }
      return lo + 1;
    }

    /* Tag-Scanner. Kommentare, CDATA und Deklarationen werden übersprungen —
       sonst läse er `<!-- <img src=…> -->` als echtes Bild. */
    var re = /<(!--[\s\S]*?--|![^>]*|\/?[A-Za-z][^\s\/>]*)((?:"[^"]*"|'[^']*'|[^>"'])*)>?/g;
    var m;
    while ((m = re.exec(text)) !== null) {
      var kopf = m[1];
      /* Kommentare und Deklarationen fängt der Ausdruck oben bereits ALS GANZES
         (`!--[\s\S]*?--` bzw. `![^>]*`) — ihr Inhalt wird gar nicht erst
         angesehen. Hier stand eine Weile zusätzlich ein `continue` für genau
         diesen Fall. Die Gegenprobe konnte es nicht kaputtmachen: ohne das
         `continue` ändert sich nichts, weil `!--…--` auf keinen der geprüften
         Tag-Namen passt. Ein Riegel, den keine Probe von seinem Fehlen
         unterscheiden kann, ist eine Behauptung — also raus. Was den Fall
         wirklich trägt, ist der Ausdruck, und darauf zielt die Gegenprobe. */
      if (kopf.charAt(0) === "/") {
        if (kopf.slice(1).toLowerCase() === "style") { /* Ende <style> */ }
        continue;
      }

      var tag = kopf.toLowerCase();
      var zeile = zeileVon(m.index);
      var a = attribute(m[2] || "");

      if (tag === "html") {
        htmlGesehen = true;
        if (!String(a.lang || "").trim()) {
          melde(zeile, "KEINE-SPRACHE",
                "<html> ohne lang-Angabe — Vorleseprogramme raten dann die Sprache.");
        }
      }

      if (tag === "style") {
        /* Der Inhalt bis zum schließenden Tag, mit eigener Zeilenrechnung. */
        var start = re.lastIndex;
        var ende = text.toLowerCase().indexOf("</style", start);
        if (ende === -1) ende = text.length;
        var inhalt = text.slice(start, ende);
        var cre = /(?:url\(\s*['"]?|@import\s+['"])([^'")\s]+)/g, cm;
        while ((cm = cre.exec(inhalt)) !== null) {
          var czeile = zeileVon(start + cm.index);
          wirte(entitaeten(cm[1])).forEach(function (h) {
            melde(czeile, "FREMDE-ADRESSE", "<style> holt von aussen: " + h);
          });
        }
        re.lastIndex = ende;
        continue;
      }

      /* Ein <meta> trägt nur dann eine Adresse, wenn es auch eine meinen kann.
         Ohne diese Klemme meldet jedes <meta name="description"> mit einem
         Doppelpunkt im Text eine fremde Adresse — und dann glaubt niemand mehr
         einer Meldung. */
      var pruefbar = {};
      for (var k in a) if (Object.prototype.hasOwnProperty.call(a, k)) pruefbar[k] = a[k];
      if (tag === "meta" && !/(image|url|video|audio)/.test(((a.property || "") + (a.name || "")).toLowerCase())) {
        delete pruefbar.content;
      }

      var namen = ADRESS_ATTRIBUTE.slice();
      if (HREF_LAEDT.indexOf(tag) !== -1) namen.push("href");
      namen.forEach(function (name) {
        if (Object.prototype.hasOwnProperty.call(pruefbar, name)) {
          wirte(entitaeten(pruefbar[name])).forEach(function (h) {
            melde(zeile, "FREMDE-ADRESSE", "<" + tag + " " + name + "> holt von aussen: " + h);
          });
        }
      });

      if (Object.prototype.hasOwnProperty.call(a, "style")) {
        var sre = /url\(\s*['"]?([^'")]+)/g, sm;
        while ((sm = sre.exec(a.style)) !== null) {
          wirte(entitaeten(sm[1])).forEach(function (h) {
            melde(zeile, "FREMDE-ADRESSE", "<" + tag + " style=url()> holt von aussen: " + h);
          });
        }
      }

      /* ══ SKRIPT-INHALT IST KEIN MARKUP (2026-08-23) ═════════════════════════
       * Klaus' Bericht einer echten Seite meldete `<a> ohne Ziel` für diese
       * Zeile:   kurz: 'Blob plus `<a download>` laedt eine spore.json'
       * Das ist ein JavaScript-Text. Jede Seite, die Markup in einer
       * Zeichenkette zusammenbaut (`el.innerHTML = "<img …>"`), bekam Phantome.
       *
       * ⚠ UND ES WAR EIN BRUCH DER ZUSICHERUNG „ZWEI FASSUNGEN, EIN ERGEBNIS".
       * Gemessen: Python meldete 0 Befunde, diese Fassung 3. Pythons
       * `HTMLParser` behandelt Skript-Inhalt als Rohdaten — wie jeder echte
       * Browser. `<style>` wurde von Anfang an übersprungen; dass `<script>`
       * fehlte, war ein Versehen.
       *
       * ⚠⚠ UND DIESER SPRUNG STAND ZUERST ZU WEIT OBEN — direkt nach der
       * `<html>`-Prüfung. Damit übersprang er den Tag, BEVOR dessen eigene
       * Adresse angesehen wurde, und ein `<script src="https://cdn…">` fiel
       * heraus: der wichtigste Fund, den dieses Werkzeug kennt. Gemessen an
       * einem eruda-Einbau: Python 1 Befund, diese Fassung 0 — die Parität war
       * in der anderen Richtung gebrochen, eine Stunde nach der Reparatur.
       * Er steht deshalb HIER: die Attribute sind geprüft, nur der INHALT wird
       * übersprungen. */
      if (tag === "script") {
        var sAnf = re.lastIndex;
        var sEnd = text.toLowerCase().indexOf("</script", sAnf);
        if (sEnd === -1) sEnd = text.length;
        re.lastIndex = sEnd;
        continue;
      }

      if (tag === "img" && !Object.prototype.hasOwnProperty.call(a, "alt")) {
        melde(zeile, "BILD-OHNE-ALT",
              "<img> ohne alt — als Bild ohne Beschreibung gar nicht vorhanden.");
      }

      if (tag === "a") {
        var ziel = String(a.href === undefined ? "" : a.href).trim();
        var hatHref = Object.prototype.hasOwnProperty.call(a, "href");
        if (!hatHref || ziel === "" || ziel === "#" || ziel.toLowerCase().indexOf("javascript:void") === 0) {
          melde(zeile, "LEERER-LINK",
                "<a> ohne Ziel (href=" + (hatHref ? "'" + a.href + "'" : "'—'") +
                ") — ein Knopf, der nichts tut.");
        }
      }
    }

    if (!htmlGesehen) {
      melde(1, "KEINE-SPRACHE", "Kein <html>-Element gefunden — Sprache nicht angebbar.");
    }

    /* Fülltext wird ZEILENWEISE gesucht, nicht über den Scanner: Reste stecken
       genauso in Kommentaren und Attributen wie im sichtbaren Text, und gerade
       ein vergessenes TODO im Kommentar ist der Fall, der ausgeliefert wird. */
    var zeilen = text.split("\n");
    for (var z = 0; z < zeilen.length; z++) {
      for (var f = 0; f < FUELL_MUSTER.length; f++) {
        if (FUELL_MUSTER[f].muster.test(zeilen[z])) {
          melde(z + 1, "FUELLTEXT", "Rest aus dem Bau: '" + FUELL_MUSTER[f].wort + "'");
        }
      }
    }

    treffer.sort(function (x, y) {
      return x.zeile - y.zeile || (x.kennung < y.kennung ? -1 : x.kennung > y.kennung ? 1 : 0);
    });
    return treffer;
  }

  welt.Auslieferungspruefer = {
    pruefe: pruefe,
    BEFUNDE: BEFUNDE,
    FUELLWOERTER: FUELLWOERTER,
    _meta: { herkunft: "Kimhub-Werkstatt 2026-08-20", fassung: "1" }
  };
})(typeof window !== "undefined" ? window : globalThis);
