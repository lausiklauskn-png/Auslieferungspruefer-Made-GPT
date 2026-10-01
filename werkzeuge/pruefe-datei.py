#!/usr/bin/env python3
"""Auslieferungsprüfer für Text-, JSON-, Markdown- und Konfigurationsdateien.

    python3 pruefe-datei.py belege.json [weitere ...]
    python3 pruefe-datei.py --ordner .          # alles unter . durchsehen

Sucht, was vor der Auslieferung nicht in einer Datei stehen sollte:
Zugangsschlüssel, Personenbezug, Abrechnungsdaten, fremde Adressen, Reste aus
der Bauzeit. Rückgabewert 0 = sauber, 1 = Befunde, 2 = Aufruffehler.

Nur Python-3-Standardbibliothek. Kein Netz, keine Installation.

══ WARUM ES DIESES WERKZEUG GIBT ═══════════════════════════════════════════

Am 2026-08-22 lagen 75 Rechnungen als JSON unter einer öffentlichen Adresse,
obwohl das Depot privat stand. `pruefe-seite.py` hätte sie DURCHGEWINKT: es ist
ein HTML-Leser, und auf einer JSON-Datei feuert kein einziges Tag. Einziger
Fund wäre gewesen „keine Sprache angegeben" — eine Meldung, die vom
eigentlichen Schaden ablenkt.

Der Browser-Zwilling steht in `PWA-Toolpoint/assets/pruefer-formate.js`.
`PWA-Toolpoint/tests/smoke_pruefer.mjs` vergleicht beide Fassungen Zeile für
Zeile gegeneinander — dieselbe Zusicherung wie bei `pruefe-seite.py`: zwei
Fassungen, ein Ergebnis. Wer hier ein Muster ändert, ändert es DORT mit.

══ DER ORDNER-GANG IST DER EIGENTLICHE ZWECK ═══════════════════════════════

Der Browser kann immer nur eine Datei. Vor dem Veröffentlichen will man aber
den ganzen Baum wissen — und genau dafür ist die Kommandozeile da:

    python3 pruefe-datei.py --ordner ~/mein-repo
"""
import os, re, sys

BEFUNDE = ("SCHLUESSEL", "PERSONENBEZUG", "RECHNUNGSDATEN",
           "FREMDE-ADRESSE", "FUELLTEXT")

# ⚠ FREIGESTELLT WIRD DER PFAD, NIE DER WERT.
# Neunzehn von Klaus' Seiten tragen ein Impressum mit echter Anschrift und
# echter Mailadresse. Die MÜSSEN dort stehen (§ 5 DDG). Ein Prüfer, der bei
# jedem Lauf Alarm schlägt, wird abgeschaltet — und meldet dann auch den echten
# Fund nicht mehr.
# Würde man den WERT freistellen („diese Mailadresse ist in Ordnung"), schwiege
# dieselbe Adresse auch dort, wo sie versehentlich steht: in einer Konfiguration,
# in einem Protokoll, in einem Datenauszug. Genau die ist der echte Fund.
# DIESE LISTE MUSS MIT `PWA-Toolpoint/assets/pruefer-formate.js` GLEICH BLEIBEN.
FREI_PFADE = ("impressum.html", "datenschutz.html", "rechte.md",
              "impressum.md", "datenschutz.md", "license", "licence")


def ist_freigestellt(pfad):
    name = str(pfad or "").lower().replace("\\", "/").rsplit("/", 1)[-1]
    return any(name == f or name.startswith(f) for f in FREI_PFADE)


# ══ DIE MUSTER ══════════════════════════════════════════════════════════════
# Jedes Muster ist so eng gefasst, wie es sein kann, ohne den Fall zu verlieren.
# Eine Warnung, die man nicht mehr los wird, ist keine Warnung: ein Prüfer, der
# auf jeder Datei etwas meldet, wird weggeklickt — und dann sieht niemand mehr
# den einen Fund, auf den es ankam.
# Deshalb steht bei den Schlüsseln überall eine MINDESTLÄNGE.
MUSTER = (
    ("SCHLUESSEL", "ein Anthropic-Schlüssel", re.compile(r"sk-ant-[A-Za-z0-9_\-]{16,}")),
    ("SCHLUESSEL", "ein OpenAI-Schlüssel", re.compile(r"\bsk-(?!ant-)[A-Za-z0-9_\-]{20,}")),
    ("SCHLUESSEL", "ein GitHub-Token", re.compile(r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}")),
    ("SCHLUESSEL", "ein GitHub-Token (neue Form)", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}")),
    ("SCHLUESSEL", "ein Google-API-Schlüssel", re.compile(r"\bAIza[A-Za-z0-9_\-]{30,}")),
    ("SCHLUESSEL", "ein Amazon-Zugangsschlüssel", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("SCHLUESSEL", "ein Slack-Token", re.compile(r"\bxox[baprs]-[A-Za-z0-9\-]{10,}")),
    # Klaus' eigenes Netz: der private Nostr-Schlüssel der Pinnwand. Wer den
    # veröffentlicht, gibt seine Identität am Brett aus der Hand.
    ("SCHLUESSEL", "ein privater Nostr-Schlüssel (nsec)",
     re.compile(r"\bnsec1[02-9ac-hj-np-z]{50,}")),
    ("SCHLUESSEL", "ein privater Schlüssel im Klartext",
     re.compile(r"-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----")),
    # ⚠ DAS SCHLIESSENDE ANFÜHRUNGSZEICHEN MUSS MIT. In JSON heisst das Feld
    # `"api_key":` — mit Zeichen VOR dem Doppelpunkt. Eine Fassung ohne das
    # `["']?` trifft in einer JSON-Datei nie, also genau dort, wo Schlüssel am
    # häufigsten liegen. An einer Probedatei gemessen: 0 Treffer, obwohl der
    # Schlüssel dastand.
    ("SCHLUESSEL", "ein Feld, das einen Schlüssel trägt",
     re.compile(r"\b(?:api[_\-]?key|apikey|secret|client[_\-]?secret|passwort|password|passwd)\b"
                r"[\"']?\s*[:=]\s*[\"']?[^\s\"',}]{12,}", re.I)),
    ("SCHLUESSEL", "ein Bearer-Token in einem Kopf",
     re.compile(r"Authorization\s*:\s*Bearer\s+[A-Za-z0-9._\-]{16,}", re.I)),

    ("PERSONENBEZUG", "eine Mailadresse",
     re.compile(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}")),
    # ⚠ NUR MIT LÄNDERVORWAHL ODER tel:. Eine blosse Ziffernfolge als
    # Telefonnummer zu lesen meldet jede Kennung und jeden Zeitstempel in einer
    # JSON-Datei — das wäre der lauteste Fehlalarm von allen. Lieber eine Nummer
    # ohne Vorwahl übersehen als jede Datei mit Zahlen anklagen.
    ("PERSONENBEZUG", "eine Telefonnummer",
     re.compile(r"(?:tel:|\+\d{2}[\s\-/()]?)\d[\d\s\-/()]{6,}\d")),
)

# Die IBAN bekommt eine eigene Prüfung statt eines Musters: die Form allein
# trifft auch Bestellnummern und Kennungen. Mit der Prüfziffer nach ISO 7064
# bleibt fast nur eine echte IBAN übrig — dieselbe Rechnung, die auch die Bank
# macht. Ein Muster ohne diese Rechnung wäre ein Fehlalarm-Werk.
IBAN_FORM = re.compile(r"\b[A-Z]{2}\d{2}(?:[ \-]?[A-Z0-9]{2,4}){3,8}\b")


def ist_iban(roh):
    s = re.sub(r"[\s\-]", "", str(roh)).upper()
    if not re.fullmatch(r"[A-Z]{2}\d{2}[A-Z0-9]{10,30}", s):
        return False
    um = s[4:] + s[:4]
    rest = 0
    for zeichen in um:
        teil = str(ord(zeichen) - 55) if zeichen.isalpha() else zeichen
        for ziffer in teil:
            rest = (rest * 10 + int(ziffer)) % 97
    return rest == 1


# Rechnungsdaten. Der Fall, um den es geht: eine Sammlung von Belegen, die
# niemand ins Depot legen wollte. Ein einzelner Betrag ist kein Befund — ein
# FELD, das Beträge oder Belegnummern trägt, schon.
GELD_FELD = re.compile(
    r"\"(?:betrag|amount|total|summe|netto|brutto|preis|price|ust|mwst|steuer|tax)\"\s*:", re.I)
BELEG_FELD = re.compile(
    r"\"(?:rechnung|rechnungsnummer|invoice|invoice_id|beleg|belegnummer|receipt"
    r"|receipt_number|kundennummer|customer_id)[a-z_]*\"\s*:", re.I)
GELD_WERT = re.compile(
    r"\d+[.,]\d{2}\s?(?:€|EUR|\$|USD|CHF)\b|\b(?:EUR|USD|CHF)\s?\d+[.,]\d{2}")

# Fremde Adressen. In HTML hängt eine Adresse an einem Attribut; hier steht sie
# nackt. Gemeldet wird nur, was wirklich holt — nicht jedes Wort mit Punkt.
ADRESSE = re.compile(r"\bhttps?://([A-Za-z0-9._\-]+(?::\d+)?)")
# Ein Namensraum ist ein NAME, kein Abruf — Zwilling von pruefer-formate.js.
NAMENSRAUM_WIRTE = {"www.w3.org", "schemas.openxmlformats.org",
                    "schemas.microsoft.com", "purl.org", "ns.adobe.com"}
VOR_XMLNS = re.compile(r"xmlns(?::[\w.\-]+)?\s*=\s*[\"']$", re.I)

# Dieselbe Fülltext-Liste wie im HTML-Prüfer, damit ein „TODO" in einer README
# genauso auffällt wie eines in der Seite. Eine zweite, eigene Liste wäre eine
# Drift-Quelle mit Ansage — deshalb wird sie von dort geholt, nicht abgeschrieben.
try:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import importlib.util as _il
    _spec = _il.spec_from_file_location(
        "pruefe_seite", os.path.join(os.path.dirname(os.path.abspath(__file__)), "pruefe-seite.py"))
    _mod = _il.module_from_spec(_spec)
    _spec.loader.exec_module(_mod)
    FUELL_MUSTER = _mod.FUELL_MUSTER
except Exception:                                    # pragma: no cover
    # Fällt der Nachbar aus, wird das GESAGT statt still weniger geprüft.
    FUELL_MUSTER = ()
    print("⚠ pruefe-seite.py nicht ladbar — Fülltext wird NICHT geprüft "
          "(ungeprüft, nicht sauber).", file=sys.stderr)


def pruefe_text(text, pfad="", erlaubt=()):
    """Gibt [(zeile, kennung, satz)] zurück, nach Zeile sortiert."""
    erlaubt = tuple(e.lower().strip() for e in erlaubt if e and e.strip())
    frei = ist_freigestellt(pfad)
    treffer = []

    for nr, zeile in enumerate(str(text or "").splitlines(), 1):
        for kennung, was, muster in MUSTER:
            # ⚠ NUR DER PERSONENBEZUG WIRD FREIGESTELLT, NIE EIN SCHLÜSSEL.
            # In einem Impressum gehört eine Anschrift; ein Zugangsschlüssel
            # gehört dort so wenig hin wie anderswo. Eine Freistellung, die auch
            # Schlüssel mitnimmt, wäre eine Hintertür mit Dateinamen.
            if frei and kennung == "PERSONENBEZUG":
                continue
            if muster.search(zeile):
                treffer.append((nr, kennung, f"Gefunden: {was}."))

        if not frei:
            for m in IBAN_FORM.finditer(zeile):
                if ist_iban(m.group(0)):
                    treffer.append((nr, "PERSONENBEZUG",
                                    "Gefunden: eine Kontonummer (IBAN, Prüfziffer stimmt)."))
                    break

        if GELD_FELD.search(zeile) or BELEG_FELD.search(zeile) or GELD_WERT.search(zeile):
            treffer.append((nr, "RECHNUNGSDATEN",
                            "Gefunden: ein Feld oder Betrag aus einer Abrechnung."))

        gemeldet = set()
        for m in ADRESSE.finditer(zeile):
            wirt = m.group(1).lower().split(":")[0]
            if wirt in gemeldet:
                continue
            if wirt in NAMENSRAUM_WIRTE or VOR_XMLNS.search(zeile[:m.start()]):
                continue
            if any(wirt == e or wirt.endswith("." + e) for e in erlaubt):
                continue
            gemeldet.add(wirt)
            treffer.append((nr, "FREMDE-ADRESSE", f"Adresse eines fremden Rechners: {wirt}"))

        for wort, muster in FUELL_MUSTER:
            if muster.search(zeile):
                treffer.append((nr, "FUELLTEXT", f"Rest aus dem Bau: {wort!r}"))

    treffer.sort(key=lambda t: (t[0], t[1]))
    return treffer


# Was beim Ordner-Gang übersprungen wird. Nicht aus Bequemlichkeit: eine
# `.git`-Historie durchzusehen dauert ewig und meldet jeden je gelöschten
# Schlüssel noch einmal — richtig, aber unbrauchbar. Wer das will, nennt den
# Pfad ausdrücklich.
UEBERSPRINGEN = {".git", "node_modules", "__pycache__", ".cache", "dist", "build"}
TEXT_ENDUNGEN = {".json", ".txt", ".md", ".csv", ".yml", ".yaml", ".toml", ".ini",
                 ".cfg", ".conf", ".env", ".js", ".mjs", ".cjs", ".py", ".sh",
                 ".html", ".htm", ".css", ".xml", ".jsonl"}


def dateien_unter(wurzel):
    for ordner, unter, namen in os.walk(wurzel):
        unter[:] = [u for u in unter if u not in UEBERSPRINGEN]
        for name in sorted(namen):
            if os.path.splitext(name)[1].lower() in TEXT_ENDUNGEN:
                yield os.path.join(ordner, name)


def main(argv):
    erlaubt, dateien, ordner = [], [], []
    i = 0
    while i < len(argv):
        if argv[i] == "--erlaubt" and i + 1 < len(argv):
            erlaubt.append(argv[i + 1].lower()); i += 2
        elif argv[i] == "--ordner" and i + 1 < len(argv):
            ordner.append(argv[i + 1]); i += 2
        else:
            dateien.append(argv[i]); i += 1

    for o in ordner:
        if not os.path.isdir(o):
            print(f"{o}: kein Ordner"); return 2
        dateien.extend(dateien_unter(o))

    if not dateien:
        print(__doc__.strip()); return 2

    gesamt, geprueft, nicht_lesbar = 0, 0, 0
    for pfad in dateien:
        if not os.path.isfile(pfad):
            print(f"{pfad}: nicht gefunden"); nicht_lesbar += 1; continue
        try:
            with open(pfad, encoding="utf-8", errors="strict") as f:
                inhalt = f.read()
        except (UnicodeDecodeError, OSError):
            # ⚠ NICHT ALS SAUBER MELDEN. Eine Datei, die nicht gelesen werden
            # konnte, ist UNGEPRÜFT — sie unter „sauber" zu verbuchen ist genau
            # der stille Fehlschlag, vor dem die Tafeln dieses Netzes warnen.
            nicht_lesbar += 1
            continue
        geprueft += 1
        treffer = pruefe_text(inhalt, pfad, tuple(erlaubt))
        for zeile, kennung, satz in treffer:
            print(f"{pfad}:{zeile}: [{kennung}] {satz}")
        gesamt += len(treffer)
        if not treffer and not ordner:
            print(f"{pfad}: kein Befund")

    print(f"\n{gesamt} Befund(e) in {geprueft} geprüften Datei(en).")
    if nicht_lesbar:
        print(f"{nicht_lesbar} Datei(en) NICHT lesbar — ungeprüft, nicht sauber.")
    return 1 if gesamt else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
