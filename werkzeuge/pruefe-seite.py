#!/usr/bin/env python3
"""Auslieferungsprüfer für HTML-Seiten.

    python3 pruefe-seite.py meineseite.html [weitere.html ...]

Meldet zeilengenau, was eine Seite vor der Auslieferung nicht enthalten sollte.
Rückgabewert 0 = sauber, 1 = Befunde, 2 = Aufruffehler.

Nur Python-3-Standardbibliothek. Kein Netz, keine Installation.

Was er NICHT kann, steht in LIESMICH.md — und das ist der wichtigere Teil.
"""
import html.parser, os, re, sys

BEFUNDE = ("FREMDE-ADRESSE", "FUELLTEXT", "BILD-OHNE-ALT", "LEERER-LINK", "KEINE-SPRACHE")

# Attribute, in denen eine Adresse stehen kann. `srcset` und `content` sind
# leicht zu vergessen — ein og:image aus dem Netz ist genauso eine fremde
# Adresse wie ein <script src>.
# ⚠ `background` und `ping` ergänzt 2026-08-23, an der laufenden Fassung
# gemessen: beide wurden nicht gemeldet. `background` am <body> laden alle
# großen Browser bis heute; `ping` schickt beim Klick eine Meldung an eine
# fremde Adresse — Nachverfolgung ohne eine Zeile JavaScript, also nicht von
# der Grenze „führt kein JS aus" gedeckt.
# DIESE LISTE MUSS MIT `PWA-Toolpoint/assets/pruefer.js` GLEICH BLEIBEN.
ADRESS_ATTRIBUTE = ("src", "srcset", "poster", "data", "action",
                    "formaction", "content", "imagesrcset",
                    "background", "ping")

# `href` ist zweierlei. Bei <link> und <base> HOLT die Seite etwas; bei <a>
# geht der Besucher weg, wenn er klickt — das ist keine fremde Ladung, sondern
# ein ganz normaler Link. An Klaus' echten Seiten gemessen (2026-08-20) waren
# 27 von 58 Meldungen genau solche Links. Eine Warnung, die man nicht mehr los
# wird, ist keine Warnung.
# ⚠ `image` und `use` ergänzt 2026-08-23. Ein <svg image href> und ein
# <svg use href> HOLEN, genau wie ein <img src> — sie standen nicht in der
# Liste, und beide Fassungen meldeten sie nicht.
HREF_LAEDT = ("link", "base", "image", "use")

# Schemata, die keine fremde Adresse sind: sie holen nichts nach.
# ⚠ `cid:` gehoert dazu, seit Klaus eine gespeicherte Seite geprueft hat
# (2026-09-11). Chrome legt beim Herunterladen eine `.mhtml` an und verweist
# darin mit `cid:...@mhtml.blink` auf die Teile IM SELBEN Behaelter — die
# lokalste Adresse, die es gibt. Gemeldet wurden sie als "holt von einem
# fremden Rechner: cid:". Und genau dieser Weg ist der, den das Tablet nimmt.
HARMLOS = ("data", "mailto", "tel", "sms", "about", "blob", "javascript", "cid")

# Die Liste ist an Klaus' echten Seiten geeicht (2026-08-20). Vier Woerter sind
# bewusst NICHT darin, obwohl sie naheliegen:
#   `placeholder` ist ein gueltiges HTML-Attribut (32 Treffer, alle harmlos),
#   `platzhalter` ein gewoehnliches deutsches Wort im Quelltext (24 Treffer).
# Wer sie aufnimmt, bekommt auf jeder Seite mit einem Formular Laerm.
#
# ⚠ `deine adresse` und `dein name` sind am 2026-08-23 DAZUGEKOMMEN, auf Klaus'
# Bericht einer echten Seite. Beide sind gewoehnliches Deutsch, und beide
# standen an Stellen, an denen sie hingehoeren — nachgezaehlt in seinen Depots:
#     „Andere verweisen nur auf deine Adresse."   (Fliesstext, Sage-Protokol)
#     <label>Dein Name (optional)</label>         (Formular, family-project)
# Das zweite ist derselbe Fall wie `placeholder`: ein echtes Etikett ist von
# einem vergessenen Platzhalter nicht zu unterscheiden. Wo man nicht entscheiden
# kann, meldet man nicht.
# DIESE LISTE MUSS MIT `PWA-Toolpoint/assets/pruefer.js` GLEICH BLEIBEN.
FUELLWOERTER = (
    "lorem ipsum", "todo", "fixme", "tbd", "xxx",
    "max mustermann", "max.mustermann", "musterstr", "musterfrau",
    "beispiel gmbh", "muster gmbh", "example.com", "example.org",
    "ihre firma",
    "coming soon", "hier text", "blindtext", "0123456789",
)

# Auf WORTGRENZE, nicht als Teilzeichenkette. Ohne das meldet `tbd` die Knopf-
# Kennung `tbDark` — auch das ist an einer echten Seite passiert.
FUELL_MUSTER = tuple((w, re.compile(r"\b" + re.escape(w) + r"\b", re.I)) for w in FUELLWOERTER)


def _hosts(wert):
    """Gibt die fremden Hosts in einem Attributwert zurück (leer = harmlos).

    `srcset` traegt mehrere Adressen, durch Komma getrennt — wer nur die erste
    liest, uebersieht die Bilder fuer grosse Bildschirme.

    Getrennt wird an JEDEM Komma. Hier stand eine Weile ein Ausdruck, der Kommata
    innerhalb von Klammern schuetzte — uebernommen aus dem CSS-Denken, wo `url()`
    das braucht. Sten hat in der Gegenpruefung vom 2026-08-20 gefragt, ob der an
    einer Adresse mit Klammern zerbricht. Nachgemessen: er machte ueberhaupt
    keinen Unterschied. Kein einziger Fall liess sich bauen, in dem er etwas
    anderes ergab — und ein Riegel, den keine Probe von seinem Fehlen
    unterscheiden kann, ist eine Behauptung, kein Riegel.

    Nach dem HTML-Standard duerfen Kommata in einer `srcset`-Adresse ohnehin
    nicht roh stehen; sie muessen als %2C geschrieben werden.
    """
    gefunden = []
    for teil in (wert or "").split(","):
        w = teil.strip().split(" ")[0].strip()
        if not w:
            continue
        if w.startswith("//"):                       # protokoll-relativ
            gefunden.append(w[2:].split("/")[0])
            continue
        m = re.match(r"^([A-Za-z][A-Za-z0-9+.\-]*):(.*)", w)
        if not m:                                    # relativ oder Anker
            continue
        schema, rest = m.group(1).lower(), m.group(2)
        if schema in HARMLOS:
            continue
        if schema in ("http", "https") and rest.startswith("//"):
            gefunden.append(rest[2:].split("/")[0])
        elif schema not in ("http", "https"):
            gefunden.append(schema + ":")            # ftp:, ws: und Verwandte
    return gefunden


class Leser(html.parser.HTMLParser):
    def __init__(self, melde):
        super().__init__(convert_charrefs=False)
        self.melde = melde
        self.html_gesehen = False
        self.in_style = False

    def handle_starttag(self, tag, attrs):
        zeile = self.getpos()[0]
        a = {k.lower(): (v or "") for k, v in attrs}

        if tag == "html":
            self.html_gesehen = True
            if not a.get("lang", "").strip():
                self.melde(zeile, "KEINE-SPRACHE",
                           "<html> ohne lang-Angabe — Vorleseprogramme raten dann die Sprache.")

        if tag == "style":
            self.in_style = True

        # Ein <meta> traegt nur dann eine Adresse, wenn es auch eine meinen kann.
        # Ohne diese Klemme meldet jedes <meta name="description"> mit einem
        # Doppelpunkt im Text eine fremde Adresse — und dann glaubt niemand mehr
        # einer Meldung.
        pruefbar = dict(a)
        if tag == "meta" and not re.search(
                r"(image|url|video|audio)", (a.get("property", "") + a.get("name", "")).lower()):
            pruefbar.pop("content", None)

        namen = list(ADRESS_ATTRIBUTE) + (["href"] if tag in HREF_LAEDT else [])
        for name in namen:
            if name in pruefbar:
                for h in _hosts(pruefbar[name]):
                    self.melde(zeile, "FREMDE-ADRESSE",
                               f"<{tag} {name}> holt von aussen: {h}")

        if "style" in a:
            for m in re.finditer(r"url\(\s*['\"]?([^'\")]+)", a["style"]):
                for h in _hosts(m.group(1)):
                    self.melde(zeile, "FREMDE-ADRESSE", f"<{tag} style=url()> holt von aussen: {h}")

        if tag == "img" and "alt" not in a:
            self.melde(zeile, "BILD-OHNE-ALT",
                       "<img> ohne alt — als Bild ohne Beschreibung gar nicht vorhanden.")

        if tag == "a":
            ziel = a.get("href", "").strip()
            if "href" not in a or ziel in ("", "#") or ziel.lower().startswith("javascript:void"):
                self.melde(zeile, "LEERER-LINK",
                           f"<a> ohne Ziel (href={a.get('href', '—')!r}) — ein Knopf, der nichts tut.")

    def handle_endtag(self, tag):
        if tag == "style":
            self.in_style = False

    def handle_data(self, daten):
        if not self.in_style:
            return
        start = self.getpos()[0]
        for m in re.finditer(r"(?:url\(\s*['\"]?|@import\s+['\"])([^'\")\s]+)", daten):
            zeile = start + daten[:m.start()].count("\n")
            for h in _hosts(m.group(1)):
                self.melde(zeile, "FREMDE-ADRESSE", f"<style> holt von aussen: {h}")


def pruefe(pfad, erlaubt=()):
    with open(pfad, encoding="utf-8", errors="replace") as f:
        text = f.read()

    treffer = []

    def melde(zeile, kennung, satz):
        if kennung == "FREMDE-ADRESSE":
            wirt = satz.rsplit(": ", 1)[-1]
            if any(wirt == e or wirt.endswith("." + e) for e in erlaubt):
                return
        treffer.append((zeile, kennung, satz))

    leser = Leser(melde)
    leser.feed(text)
    leser.close()

    if not leser.html_gesehen:
        melde(1, "KEINE-SPRACHE", "Kein <html>-Element gefunden — Sprache nicht angebbar.")

    # Fuelltext wird zeilenweise gesucht, NICHT ueber den Parser: Reste stecken
    # genauso in Kommentaren und Attributen wie im sichtbaren Text, und gerade
    # ein vergessenes TODO im Kommentar ist der Fall, der ausgeliefert wird.
    for nr, zeile in enumerate(text.splitlines(), 1):
        for wort, muster in FUELL_MUSTER:
            if muster.search(zeile):
                melde(nr, "FUELLTEXT", f"Rest aus dem Bau: {wort!r}")

    treffer.sort(key=lambda t: (t[0], t[1]))
    return treffer


def main(argv):
    erlaubt, dateien = [], []
    i = 0
    while i < len(argv):
        if argv[i] == "--erlaubt" and i + 1 < len(argv):
            erlaubt.append(argv[i + 1].lower()); i += 2
        else:
            dateien.append(argv[i]); i += 1

    if not dateien:
        print(__doc__.strip()); return 2

    gesamt = 0
    for pfad in dateien:
        if not os.path.isfile(pfad):
            print(f"{pfad}: nicht gefunden"); gesamt += 1; continue
        treffer = pruefe(pfad, tuple(erlaubt))
        for zeile, kennung, satz in treffer:
            print(f"{pfad}:{zeile}: [{kennung}] {satz}")
        gesamt += len(treffer)
        if not treffer:
            print(f"{pfad}: sauber")

    print(f"\n{gesamt} Befund(e).")
    return 1 if gesamt else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
