/* Auslieferungsprüfer — die zweite Meinung des Browsers.
 *
 * Klaus am 2026-08-23: „schauen, ob du noch richtige HTML Seiten … einmal durch
 * diesen Filter laufen [lässt] … also sowas wie einen Mini Browser, der checkt.
 * Vielleicht geht das. Ich weiß es nicht."
 *
 * Es geht — und es trifft genau die Abhilfe, die der Brief der Vorsitzung für
 * die schlimmste offene Umgehung nennt: „Beide Fälle haben dieselbe Abhilfe:
 * `DOMParser` statt des selbstgebauten Regex-Scanners. Der Browser bringt genau
 * den Parser mit, dessen Verhalten geprüft werden soll; jede Nachbildung driftet
 * davon ab."
 *
 * ══ WARUM ALS ZWEITE MEINUNG UND NICHT ALS ERSATZ ═════════════════════════
 *
 * Der Brief wollte den Regex-Scanner ERSETZEN. Das wäre teuer und würde etwas
 * zerstören, das mehr wert ist als der Gewinn:
 *
 *   · `DOMParser` liefert KEINE Zeilennummern. Er gibt einen Baum zurück, keine
 *     Stellen im Text. Ein Befund ohne Zeile ist für den, der ihn beheben soll,
 *     fast wertlos.
 *   · `pruefer.js` steht unter der Zusicherung „zwei Fassungen, ein Ergebnis" —
 *     Python und Browser müssen Zeichen für Zeichen dasselbe melden. Python hat
 *     keinen `DOMParser`. Ein Nachbau dort wäre wieder eine Nachbildung, also
 *     genau das Problem.
 *
 * Also beides, nebeneinander. Und dann ist der eigentliche Gewinn nicht der
 * Baum, sondern DER UNTERSCHIED: was der Browser lädt und der Textleser nicht
 * sieht, ist kein Schönheitsfehler — das ist ein Versteck. Ein Angreifer
 * braucht genau diese Lücke; ein vertippter Kommentar erzeugt sie versehentlich.
 *
 * Läuft NUR im Browser (DOMParser). Ist er nicht da, sagt das Werkzeug das,
 * statt still nichts zu prüfen.
 */
(function (welt) {
  "use strict";

  /* Dieselben Träger wie im Textleser — hier aber am fertigen Baum abgefragt.
     Eine zweite, abweichende Liste wäre eine Drift-Quelle: dann meldete die
     zweite Meinung Unterschiede, die nur aus ihrer eigenen Lücke stammen. */
  var LADE_ATTRIBUTE = ["src", "srcset", "poster", "data", "action",
                        "formaction", "imagesrcset", "background", "ping"];
  var HREF_LAEDT = ["link", "base", "image", "use"];
  var HARMLOS = ["data", "mailto", "tel", "sms", "about", "blob", "javascript"];

  function wirteAus(wert) {
    var gefunden = [];
    String(wert || "").split(",").forEach(function (teil) {
      var w = teil.trim().split(" ")[0].trim();
      if (!w) return;
      if (w.indexOf("//") === 0) { gefunden.push(w.slice(2).split("/")[0].toLowerCase()); return; }
      var m = /^([A-Za-z][A-Za-z0-9+.\-]*):([\s\S]*)$/.exec(w);
      if (!m) return;
      var schema = m[1].toLowerCase(), rest = m[2];
      if (HARMLOS.indexOf(schema) !== -1) return;
      if ((schema === "http" || schema === "https") && rest.indexOf("//") === 0) {
        gefunden.push(rest.slice(2).split("/")[0].toLowerCase());
      } else if (schema !== "http" && schema !== "https") {
        gefunden.push(schema + ":");
      }
    });
    return gefunden;
  }

  /* Zeilennummer zu einem Wirt: die erste Zeile im ROHTEXT, in der er vorkommt.
     Der Baum kennt keine Zeilen, der Text schon — also wird nachgeschlagen
     statt geraten. Findet sich nichts (der Wirt steckt in einer Entität oder in
     einem srcdoc), bleibt es ehrlich bei null. */
  function zeileVonWirt(zeilen, wirt) {
    for (var i = 0; i < zeilen.length; i++) {
      if (zeilen[i].toLowerCase().indexOf(wirt) !== -1) return i + 1;
    }
    return 0;
  }

  /* Sammelt am fertigen Baum ein, was WIRKLICH geladen würde. */
  function ausDemBaum(doc, aufnehmen) {
    var alle = doc.querySelectorAll("*");
    for (var i = 0; i < alle.length; i++) {
      var el = alle[i], tag = el.tagName.toLowerCase();

      for (var a = 0; a < LADE_ATTRIBUTE.length; a++) {
        var name = LADE_ATTRIBUTE[a];
        if (!el.hasAttribute(name)) continue;
        /* `content` nur an einem <meta>, das auch eine Adresse meinen kann —
           dieselbe Klemme wie im Textleser, sonst meldet jede Beschreibung mit
           einem Doppelpunkt eine fremde Adresse. */
        wirteAus(el.getAttribute(name)).forEach(function (w) { aufnehmen(w, tag + " " + name); });
      }
      if (tag === "meta") {
        var kennz = ((el.getAttribute("property") || "") + (el.getAttribute("name") || "")).toLowerCase();
        if (/(image|url|video|audio)/.test(kennz)) {
          wirteAus(el.getAttribute("content")).forEach(function (w) { aufnehmen(w, "meta content"); });
        }
      }
      if (HREF_LAEDT.indexOf(tag) !== -1 && el.hasAttribute("href")) {
        wirteAus(el.getAttribute("href")).forEach(function (w) { aufnehmen(w, tag + " href"); });
      }
      if (el.hasAttribute("style")) {
        var sre = /url\(\s*['"]?([^'")]+)/g, sm;
        while ((sm = sre.exec(el.getAttribute("style"))) !== null) {
          wirteAus(sm[1]).forEach(function (w) { aufnehmen(w, tag + " style"); });
        }
      }
      if (tag === "style") {
        var cre = /(?:url\(\s*['"]?|@import\s+['"])([^'")\s]+)/g, cm;
        while ((cm = cre.exec(el.textContent || "")) !== null) {
          wirteAus(cm[1]).forEach(function (w) { aufnehmen(w, "style"); });
        }
      }
    }
  }

  /**
   * Vergleicht, was der Browser lädt, mit dem, was der Textleser gemeldet hat.
   *
   * @param {string} text      der Quelltext
   * @param {object[]} textBefunde  die Treffer aus `Auslieferungspruefer.pruefe`
   * @param {string[]} erlaubt eigene Wirte
   * @returns {{moeglich:boolean, grund?:string, treffer:object[], geprueft:number}}
   */
  function zweiteMeinung(text, textBefunde, erlaubt) {
    if (typeof welt.DOMParser !== "function") {
      return { moeglich: false, treffer: [], geprueft: 0,
               grund: "Dieser Browser stellt keinen DOMParser bereit — die zweite Meinung ist ungeprüft, nicht sauber." };
    }
    text = String(text == null ? "" : text);
    erlaubt = (erlaubt || []).map(function (e) { return String(e).toLowerCase().trim(); }).filter(Boolean);
    var zeilen = text.split("\n");
    var treffer = [];

    function eigen(wirt) {
      for (var i = 0; i < erlaubt.length; i++) {
        if (wirt === erlaubt[i] || wirt.slice(-(erlaubt[i].length + 1)) === "." + erlaubt[i]) return true;
      }
      return false;
    }

    /* Was der Textleser schon gemeldet hat — nach Wirt, nicht nach Wortlaut. */
    var vomTextleser = {};
    (textBefunde || []).forEach(function (b) {
      if (b.kennung !== "FREMDE-ADRESSE") return;
      var w = String(b.satz).split(": ").pop().trim().toLowerCase();
      if (w) vomTextleser[w] = 1;
    });

    var doc;
    try { doc = new welt.DOMParser().parseFromString(text, "text/html"); }
    catch (e) {
      return { moeglich: false, treffer: [], geprueft: 0,
               grund: "Der Browser konnte den Text nicht als Seite lesen." };
    }

    var imBaum = {};
    ausDemBaum(doc, function (wirt, woher) {
      if (!wirt || eigen(wirt)) return;
      if (!imBaum[wirt]) imBaum[wirt] = woher;
    });

    /* ══ DER EIGENTLICHE FUND ════════════════════════════════════════════════
       Ein Wirt, den der Browser lädt und den der Textleser nicht gemeldet hat.
       Das ist kein Unterschied in der Meinung — der Textleser hat ihn nicht
       GESEHEN, und was er nicht sieht, meldet er auch bei der nächsten Prüfung
       nicht. */
    Object.keys(imBaum).forEach(function (wirt) {
      if (vomTextleser[wirt]) return;
      treffer.push({
        zeile: zeileVonWirt(zeilen, wirt),
        kennung: "VERSTECKT-VOR-DEM-TEXTLESER",
        satz: "Der Browser lädt von " + wirt + " (" + imBaum[wirt] +
              "), der Textleser hat das nicht gesehen."
      });
    });

    /* ── Der leere Kommentar ────────────────────────────────────────────────
       Der teuerste der bekannten Fälle, und der einzige, der auch OHNE
       Angreifer vorkommt: ein vertippter Kommentar. Der Browser sieht laut
       HTML-Standard einen sofort geschlossenen Kommentar
       (`abrupt-closing-of-empty-comment`) und führt alles danach aus. Der
       Textleser sucht das nächste `--` und frisst alles dazwischen — es genügt
       irgendein späterer, gewöhnlicher Kommentar, und den hat fast jede Seite.
       Wird ausdrücklich benannt, weil der Wirt-Vergleich oben ihn nur dann
       fängt, wenn dahinter zufällig eine fremde Adresse steht. */
    var leer = /<!--+>/g, lm;
    while ((lm = leer.exec(text)) !== null) {
      var bis = text.slice(0, lm.index).split("\n").length;
      treffer.push({
        zeile: bis, kennung: "LEERER-KOMMENTAR",
        satz: "Ein leerer Kommentar (" + lm[0] + "). Der Browser schließt ihn sofort " +
              "und führt aus, was danach steht — der Textleser liest bis zum nächsten " +
              "'--' und übersieht alles dazwischen."
      });
    }

    /* ── srcdoc: eine ganze zweite Seite in einem Attribut ─────────────────── */
    var rahmen = doc.querySelectorAll("iframe[srcdoc]");
    for (var r = 0; r < rahmen.length; r++) {
      var innen = rahmen[r].getAttribute("srcdoc") || "";
      var inneresDoc = null;
      try { inneresDoc = new welt.DOMParser().parseFromString(innen, "text/html"); } catch (e) {}
      var drin = {};
      if (inneresDoc) ausDemBaum(inneresDoc, function (w) { if (w && !eigen(w)) drin[w] = 1; });
      treffer.push({
        zeile: zeileVonWirt(zeilen, "srcdoc"),
        kennung: "ZWEITE-SEITE-IM-ATTRIBUT",
        satz: "Ein <iframe srcdoc> trägt eine vollständige zweite Seite" +
              (Object.keys(drin).length
                 ? ", die von " + Object.keys(drin).join(", ") + " lädt."
                 : " im Attribut.")
      });
    }

    /* ── Weiterleitung per meta refresh ─────────────────────────────────────
       Mehr als Nachladen: die Seite gibt den Besucher samt Herkunfts-Angabe
       nach außen. Der Textleser sieht `content` nur an einem <meta> mit
       image/url/video/audio in name oder property — `http-equiv` gar nicht. */
    var metas = doc.querySelectorAll('meta[http-equiv]');
    for (var mi = 0; mi < metas.length; mi++) {
      if (!/^refresh$/i.test(metas[mi].getAttribute("http-equiv") || "")) continue;
      var inhalt = metas[mi].getAttribute("content") || "";
      var zm = /url\s*=\s*['"]?([^'";]+)/i.exec(inhalt);
      if (!zm) continue;
      var zielWirte = wirteAus(zm[1].trim()).filter(function (w) { return !eigen(w); });
      treffer.push({
        zeile: zeileVonWirt(zeilen, "refresh"),
        kennung: "WEITERLEITUNG",
        satz: "Die Seite leitet von allein weiter" +
              (zielWirte.length ? " auf " + zielWirte.join(", ") : "") +
              " — der Besucher geht dorthin, ohne geklickt zu haben."
      });
    }

    treffer.sort(function (x, y) {
      return x.zeile - y.zeile || (x.kennung < y.kennung ? -1 : x.kennung > y.kennung ? 1 : 0);
    });
    return { moeglich: true, treffer: treffer, geprueft: Object.keys(imBaum).length };
  }

  welt.PrueferBrowser = {
    zweiteMeinung: zweiteMeinung,
    BEFUNDE: ["VERSTECKT-VOR-DEM-TEXTLESER", "LEERER-KOMMENTAR",
              "ZWEITE-SEITE-IM-ATTRIBUT", "WEITERLEITUNG"],
    _meta: { herkunft: "PWA Toolpoint 2026-08-23", fassung: "1" }
  };
})(typeof window !== "undefined" ? window : globalThis);
