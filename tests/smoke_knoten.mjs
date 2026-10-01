/* Auslieferungsprüfer — Text-Wächter ohne Browser: der SBKIM-Knoten, das
 * Wörterbuch, die Versionsnummern.
 *
 * ⚠ HERKUNFT: die Prüfer-Abschnitte aus PWA-Toolpoints `tests/smoke.mjs`
 * (origin/main 6f5d868, „Der Auslieferungsprüfer als eigener Knoten",
 * „Wer im Semantik-Feld gewinnt", „Sprache", „?v="). Beim Umzug in dieses Depot
 * am 2026-09-26 kam nur `smoke_pruefer.mjs` mit — und die Gegenprobe meldete
 * 20 Fälle BLIND, weil ihre Wächter drüben im Marktplatz-Smoke stehen. Diese
 * Datei holt sie her.
 *
 * Was sich beim Umzug geändert hat, und nur das:
 *   · Vergleiche mit dem MARKTPLATZ (Wizard byte-gleich mit `sbkim-andock-
 *     wizard.js`, Spore gehört nicht dem Marktplatz) gibt es hier nicht — der
 *     Marktplatz liegt in einem anderen Depot. An ihre Stelle tritt ein
 *     SHA-256-Pin auf die Kanon-Fassung aus Sage (`src/modules/16b_andock_
 *     wizard.js` bzw. die 13 Module). Gleiche Zusicherung, andere Quelle.
 *   · Die ?v=-Nummern hängen hier NICHT an der CACHE_VERSION (v1 gegen ?v=76,
 *     beides übernommen). Gemessen wird, dass alle ?v= dieselbe Nummer tragen.
 *
 * Der eigene Rückgabewert entscheidet — `| tail` ist zum Lesen da. */
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';

const ROOT = new URL('..', import.meta.url);
const lies = (p) => readFileSync(new URL(p, ROOT), 'utf8');
const da = (p) => existsSync(new URL(p, ROOT));
const sha = (p) => createHash('sha256').update(readFileSync(new URL(p, ROOT))).digest('hex');

let pass = 0, fail = 0;
const ok = (name, cond, hinweis) => {
  cond ? (pass++, console.log('  ✓ ' + name))
       : (fail++, console.log('  ✗ ' + name + (hinweis ? '  → ' + hinweis : '')));
};

console.log('\n── Der Auslieferungsprüfer als eigener Knoten ──');
for (const f of ['auslieferungspruefer.html', 'assets/pruefer-sbkim-init.js',
                 'assets/config/pruefer-netz.js', 'assets/config/netz.js',
                 'assets/pruefer-siegel-inhalt.js', 'assets/pruefer-sbkim-andock-wizard.js',
                 'sbkim/17_floating_widget.js', 'sw.js']) {
  ok(`vorhanden: ${f}`, da(f));
}
const pruefer = lies('auslieferungspruefer.html');
const prInit  = lies('assets/pruefer-sbkim-init.js');
const prNetz  = lies('assets/config/pruefer-netz.js');
const prWiz   = lies('assets/pruefer-sbkim-andock-wizard.js');
const prKonf  = lies('assets/pruefer-siegel-inhalt.js');
const sw      = lies('sw.js');

/* ── Kanon-Pins ─────────────────────────────────────────────────────────────
   Byte-1:1 aus Sage-Protokol/src/modules (gemessen 2026-09-26, Sage origin/main
   und PWA-Toolpoint origin/main tragen dieselben Fingerabdrücke). Ein Drift-
   Guard sagt „unverändert", nicht „aktuell": reift ein Modul in Sage, wird es
   hier neu kopiert UND der Pin nachgezogen — nie die Kopie abgewandelt. */
const KANON = {
  'sbkim/01_storage.js':        '5a5a4bf64dfc',
  'sbkim/02_spore.js':          '6789fe6e903a',
  'sbkim/03_embedding.js':      'e4bb8bd6a237',
  'sbkim/04_match.js':          '5de95923c3f6',
  'sbkim/05_anastomose.js':     '255ac79aeb3b',
  'sbkim/05b_nostr_relay.js':   '030aa2d26014',
  'sbkim/07_apoptose.js':       '0acdd6ab2d95',
  'sbkim/15_membran.js':        '829a5bc01976',
  'sbkim/16_siegel.js':         'd84fa539e76e',
  'sbkim/17_floating_widget.js':'e4ee076c1295',
  'sbkim/23_rendezvous.js':     '3caa0bb1fbe7',
  'sbkim/23_rendezvous_ui.js':  'fc47f16b24d5',
  'sbkim/noble-secp256k1.js':   '8f3879ca422c',
  /* Der Wizard: seit A18 eine Kanon-Datei (Sage 16b_andock_wizard.js), die
     Identität steht getrennt in pruefer-siegel-inhalt.js. Drüben wurde er gegen
     den Marktplatz-Wizard verglichen; hier gegen den Pin derselben Fassung. */
  'assets/pruefer-sbkim-andock-wizard.js': 'c415eafdb1b6',
};
for (const [f, pin] of Object.entries(KANON)) {
  const ist = da(f) ? sha(f).slice(0, 12) : 'fehlt';
  ok(`Kanon byte-1:1: ${f}`, ist === pin, `ist ${ist}, gepinnt ${pin}`);
}

/* Alle dreizehn, namentlich — „mindestens zehn" wäre keine Zusicherung. */
const KANON13 = ['01_storage', '02_spore', '03_embedding', '04_match', '05_anastomose',
  '05b_nostr_relay', '07_apoptose', '15_membran', '16_siegel', '17_floating_widget',
  '23_rendezvous', '23_rendezvous_ui'];
const prKette = [...prInit.matchAll(/"(sbkim\/[^"]+)"/g)].map(m => m[1]);
const fehltImKanon = KANON13.filter(m => !prKette.some(k => k.includes(m)));
ok('die Kette des Prüfers nennt alle Pflicht-Module namentlich',
   fehltImKanon.length === 0, fehltImKanon.join(', '));

/* ⚠ EIN FEHLENDES KOMMA ZWISCHEN ZWEI LISTEN IST KEIN SYNTAXFEHLER, sondern ein
   Index-Zugriff (Befund Toolpoint 2026-09-14). */
{
  const block = (prInit.match(/var KANON = \[([\s\S]*?)\n  \];/) || [, ''])[1];
  ok('die Kette ist lesbar', block.length > 0);
  const ohneKommentar = block.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
  const luecke = /\]\s*\n\s*\[/.test(ohneKommentar);
  ok('kein Kettenglied ohne Komma dahinter', !luecke,
     luecke ? 'zwei Literale stehen ohne Komma nebeneinander — das liest JS als Index-Zugriff' : '');
  const glieder = [...ohneKommentar.matchAll(/\[\s*"([^"]*)"\s*,\s*"([^"]+)"\s*\]/g)];
  ok(`jedes Kettenglied ist ein Paar aus Typ und Pfad (${glieder.length})`, glieder.length >= 12);
}
ok('… und noble liegt da, auch ohne in der Kette zu stehen', da('sbkim/noble-secp256k1.js'));
for (const k of prKette) ok(`Kettenglied existiert: ${k}`, da(k));

/* FALLE 1 (Sage LEHREN § 4): die ZUWEISUNG im <head>, vor dem Andock. */
const iPrSuffix = pruefer.search(/<script>\s*window\.SBKIM_DB_SUFFIX\s*=/);
const iPrKopf = pruefer.indexOf('</head>');
const iPrLaden = pruefer.search(/<script src="assets\/pruefer-sbkim-init\.js/);
ok('die Schublade steht im <head>', iPrSuffix > 0 && iPrSuffix < iPrKopf);
ok('… und VOR dem Andock, das die Module holt',
   iPrSuffix > 0 && iPrLaden > 0 && iPrSuffix < iPrLaden);
const prSuffix = (pruefer.match(/window\.SBKIM_DB_SUFFIX\s*=\s*"([a-z0-9_-]+)"/) || [])[1] || '';
ok(`die Schublade heisst „${prSuffix}“`, prSuffix === 'auslieferungspruefer-gpt');
/* Register: Sage-Protokol/sbkim/DB-SUFFIXE.md — benannte KOPIE, wie drüben. */
const VERGEBEN = ['alismoderaum', 'blp', 'bookledgerpro', 'companybrain', 'familyprojekt',
  'jasonstresor', 'kimbell', 'kimboard', 'kimseek', 'meintresor', 'mixarium',
  'muttisrezeptbuch', 'perfectskinbeauty', 'perfectskinfashion', 'privatbrain',
  'pwatoolpoint', 'rezeptbuch', 'sage', 'tomyhub', 'toolpoint', 'workfloh',
  'workflohpage', 'kimhubcompany'];
ok('… und sie ist netzweit keine fremde', !!prSuffix && !VERGEBEN.includes(prSuffix));
ok('der Suffix steht auch in der Konfiguration, gleich geschrieben',
   !!prSuffix && new RegExp(`dbSuffix:\\s*"${prSuffix}"`).test(prNetz));

/* Die abgelegte Spore des Prüfers: Beleg, nicht Sender. */
if (da('sbkim/pruefer-spore.json')) {
  const prRoh = lies('sbkim/pruefer-spore.json');
  let prSp = null;
  try { prSp = JSON.parse(prRoh); } catch { /* bleibt null */ }
  ok('die abgelegte Spore ist lesbares JSON', prSp !== null);
  if (prSp) {
    for (const feld of ['id', 'publicKey', 'signature', 'nodeName', 'domain',
                        'domainVector', 'protocolVersion', 'nodeType', 'endpoint'])
      ok(`Spore trägt Pflichtfeld: ${feld}`, prSp[feld] !== undefined);
    ok('Spore: KEIN privater Schlüssel im JWK', prSp.publicKey?.d === undefined);
    ok('Spore: der Schlüssel darf nur prüfen', JSON.stringify(prSp.publicKey?.key_ops ?? []) === '["verify"]');
    ok('Spore: nirgends ein privates Feld im Rohtext',
       !/"(d|privateKey|private_key|seed|mnemonic)"\s*:/.test(prRoh));
    const prNameKonf = (prNetz.match(/nodeName:\s*"([^"]+)"/) || [])[1];
    ok(`Spore gehört dem Prüfer („${prSp.nodeName}“)`, prSp.nodeName === prNameKonf);
  }
}
ok('kein sbkim/spore.json — der Prüfer trägt seine Spore unter eigenem Namen',
   !da('sbkim/spore.json'));

/* FALLE 2: 05b ist ein ES-Modul. */
ok('Modul 05b läuft als ES-Modul, nicht als klassisches Skript',
   /\["module",\s*"sbkim\/05b_nostr_relay\.js"\]/.test(prInit));

/* FALLE 3: 17 legt die Anker an, also vor 15 und 16 — geladen UND gestartet. */
const prIdx = (t) => prKette.findIndex(k => k.includes(t));
ok('Modul 17 steht in der Kette vor 15 und vor 16',
   prIdx('17_floating_widget') >= 0 && prIdx('15_membran') >= 0 && prIdx('16_siegel') >= 0
   && prIdx('17_floating_widget') < prIdx('15_membran')
   && prIdx('17_floating_widget') < prIdx('16_siegel'));
ok('… und es wird auch wirklich gestartet, nicht nur geladen', /SbkimWidget\.init\(/.test(prInit));
ok('… und zwar VOR Membran und Siegel',
   prInit.indexOf('SbkimWidget.init(') >= 0 &&
   prInit.indexOf('SbkimWidget.init(') < prInit.indexOf('SbkimMembrane.init(') &&
   prInit.indexOf('SbkimWidget.init(') < prInit.indexOf('SbkimSiegel.init('));

/* Ladezeit: nichts blockierend, erst in der Leerlauf-Pause, fail-soft. */
ok('keine SBKIM-Module als blockierendes <script> in der Seite', !/<script src="sbkim\//.test(pruefer));
ok('die Kette kommt nach dem Laden, in der Leerlauf-Pause',
   /addEventListener\("load"/.test(prInit) && /requestIdleCallback/.test(prInit));
ok('eine fehlende Datei hält die Kette nicht an (onerror wie onload)',
   /s\.onload = s\.onerror = function/.test(prInit));

ok('das Wappen-Band trägt den EIGENEN Namen',
   /ribbonText:\s*"AUSLIEFERUNGSPRÜFER GPT"/.test(prInit) && !/ribbonText:\s*"PWA TOOLPOINT"/.test(prInit));
ok('Siegel und Membran hängen in die Anker von Modul 17',
   /badgeSelector:\s*"#sbkim-siegel-badge"/.test(prInit) && /lampSelector:\s*"#lamp-fremd"/.test(prInit));

/* Die Beschreibung — zwei Wege zur Spore, ein Text. */
const textVon = (t) => {
  const m = t.match(/(?:beschreibung|domainDescription):\s*([\s\S]*?),\n\s*(?:stichworte|domainKeywords)/);
  return m ? [...m[1].matchAll(/"((?:[^"\\]|\\.)*)"/g)].map(x => x[1]).join('') : '';
};
const prBeschreibungNetz = textVon(prNetz);
const prBeschreibungWiz  = textVon(prKonf);
ok(`die Beschreibung trägt Substanz (${prBeschreibungNetz.length} Zeichen)`,
   prBeschreibungNetz.length > 400 && prBeschreibungNetz.split(/[.!?]\s/).length >= 4);
ok('… und sie steht in beiden Wegen zur Spore WORTGLEICH da',
   !!prBeschreibungNetz && prBeschreibungNetz === prBeschreibungWiz);
ok('… und nennt den eigenen Knoten beim Namen', /Auslieferungsprüfer/.test(prBeschreibungWiz));

/* Der Wizard: Element UND Verdrahtung, nicht Namen aus dem Kopf-Kommentar. */
for (const [was, id] of [['Identität erzeugen', 'sbwiz-s1'],
                         ['Spore signieren + herunterladen', 'sbwiz-s2'],
                         ['verschlüsselte Sicherung', 'sbwiz-s3'],
                         ['Wiederherstellen', 'sbwiz-s4'],
                         ['Identitäts-Wechsler', 'sbwiz-idsel']]) {
  ok(`Wizard: Baustein „${was}" — Element UND Verdrahtung`,
     prWiz.includes(`id="${id}"`) && new RegExp(`#${id}"\\)\\.addEventListener`).test(prWiz));
}
ok('… und der Wechsler stellt die aktive Kennung wirklich um',
   /\bfunction switchWizardIdentity\s*\(/.test(prWiz));

/* Wer im Semantik-Feld gewinnt — gemessen wird der BLOCK, nicht die Datei. */
{
  const q = prWiz;
  const iFeld = q.indexOf('ta.id = "sbkim-si-semantik-text"');
  const iHerk = q.indexOf('var herkunft = document.createElement');
  const vorbelegung = iFeld >= 0 && iHerk > iFeld ? q.slice(iFeld, iHerk) : '';
  ok('das Feld zeigt den Vorschlag der APP', /ta\.value = c\.domainDescription\b/.test(vorbelegung));
  const iLade = q.indexOf('getOwnSpore().then');
  const iEnde = q.indexOf('ta.addEventListener("input"', iLade);
  const ladePfad = iLade >= 0 && iEnde > iLade ? q.slice(iLade, iEnde) : '';
  ok('… und die gespeicherte Spore überschreibt ihn nur, wenn der Nutzer SELBST geschrieben hat',
     ladePfad.length > 0 && /if \(!abweichend\) return;/.test(ladePfad)
     && /if \(hatEigenenText\(\)\) \{/.test(ladePfad));
  ok('… und beim Signieren wird vermerkt, ob der Text ein eigener war',
     /merkeEigenenText\(beschreibung\)/.test(q) && /function merkeEigenenText/.test(q));
  ok('eine Zeile NENNT, welcher Text im Feld steht',
     /data-woher/.test(q) && /id = "sbkim-si-semantik-herkunft"/.test(q));
}

/* INTERFACES § 11.7: Gerätename per Glue ins Panel, nie in die Spore. */
ok('das Gerätenamen-Feld hängt per Glue ins Panel',
   /setAttribute\("data-sbkim-geraetename"/.test(prInit) &&
   /getElementById\("sbkim-rdv-panel"\)/.test(prInit) && /panel\.insertBefore/.test(prInit));
ok('… und die byte-kopierte Panel-Datei legt selbst KEIN Feld an',
   !/setAttribute\(\s*["']data-sbkim-geraetename/.test(lies('sbkim/23_rendezvous_ui.js')));
ok('der Gerätename geht nicht in die signierte Spore', !/generateOwnSpore/.test(prInit));

/* Relais: ABGELESEN, nicht abgeschrieben — und netz.js steht davor. */
ok('die Relais werden aus netz.js ABGELESEN, nicht abgeschrieben',
   /window\.PT_NETZ && window\.PT_NETZ\.relais/.test(prNetz) && !/wss:\/\//.test(prNetz));
ok('… und netz.js liefert wirklich Relais', (lies('assets/config/netz.js').match(/wss:\/\//g) || []).length >= 1);
ok('… und `netz.js` steht in der Seite VOR `pruefer-netz.js`',
   pruefer.indexOf('assets/config/netz.js') > 0 &&
   pruefer.indexOf('assets/config/netz.js') < pruefer.indexOf('assets/config/pruefer-netz.js'));

console.log('\n── Offline-Vorrat und Versionsnummern ──');
const coreRoh = (sw.match(/(?:var|const) CORE\s*=\s*\[([\s\S]*?)\];/) || ['', ''])[1]
  .replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/^\s*\/\/.*$/gm, ' ');
const core = [...coreRoh.matchAll(/"([^"]+)"/g)].map(m => m[1]);
ok('CORE ist lesbar und nicht leer', core.length > 0);
ok('SBKIM-Module stehen für den Offline-Betrieb im Vorrat', core.some(c => c.startsWith('sbkim/')));
for (const e of core) ok(`Vorrat existiert: ${e}`, e === './' || da(e.split('?')[0]));
const imVorrat = (pfad) =>
  core.some((u) => new RegExp('^' + pfad.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '(\\?v=\\d+)?$').test(u));
ok('der Klebstoff, den die Seite lädt, steht im Vorrat',
   imVorrat('assets/pruefer-sbkim-init.js') && imVorrat('assets/config/pruefer-netz.js'));
ok('was die Kette holt, landet zur Laufzeit im Vorrat (Falle 4)',
   core.filter(c => c.startsWith('sbkim/')).length >= 13 && /cache\.put\(key/.test(sw));

/* ⚠ EINE VERSIONSNUMMER GILT FÜR JEDE ADRESSE. Gefunden, nicht gepflegt: jede
   Seite der Wurzel, jedes Skript unter assets/, der Vorrat. */
const jsUnter = (verz) =>
  readdirSync(new URL(verz + '/', ROOT), { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? jsUnter(`${verz}/${e.name}`) : (e.name.endsWith('.js') ? [`${verz}/${e.name}`] : []));
const seiten = readdirSync(new URL('./', ROOT)).filter(n => n.endsWith('.html')).sort();
const traeger = [...seiten, ...jsUnter('assets').sort()];
const nummern = new Map();
for (const name of traeger)
  for (const t of lies(name).matchAll(/assets\/[A-Za-z0-9./_-]+\?v=(\d+)/g))
    nummern.set(`${name}: ${t[0]}`, t[1]);
for (const e of core) { const t = e.match(/\?v=(\d+)$/); if (t) nummern.set(`sw.js CORE: ${e}`, t[1]); }
const verteilung = {};
for (const v of nummern.values()) verteilung[v] = (verteilung[v] || 0) + 1;
const haeufigste = Object.entries(verteilung).sort((a, b) => b[1] - a[1])[0]?.[0];
const abweichend = [...nummern].filter(([, v]) => v !== haeufigste).map(([k]) => k);
ok(`ALLE ?v= in Seiten, Skripten und Vorrat tragen dieselbe Nummer (v=${haeufigste})`,
   abweichend.length === 0, abweichend.slice(0, 4).join(' · '));
ok(`… und es stehen wirklich Versionsnummern da (${nummern.size})`, nummern.size >= 10);
ok('Asset-Abfragen verwenden im SW den Pfad ohne Versionsparameter', /const key=APP_BASE.origin\+path/.test(sw) && [...nummern.keys()].some(k => /\.html:/.test(k)));
ok('CACHE_VERSION gesetzt', /const CACHE_VERSION=CACHE_PREFIX\+'v[\d.]+'/.test(sw));

console.log('\n── Wörterbuch ──');
/* ⚠ BEFUND 2026-09-18 (Klaus, mit Bild): „Impressum &amp; Datenschutz" stand
   wörtlich in der Fußzeile. `data-i18n` setzt textContent, und das deutet
   keine Entität. Gemessen wird die FAMILIE: jeder Schlüssel, den eine Seite
   ohne `-html` benutzt, darf in keiner Sprache eine Entität tragen. */
const BUCH = {
  'auslieferungspruefer.html': 'assets/i18n-pruefer.js',
  'impressum.html': 'assets/i18n-recht.js',
  'datenschutz.html': 'assets/i18n-recht.js',
};
for (const [name, buch] of Object.entries(BUCH)) {
  const seite = lies(name);
  const welt = {};
  new Function('window', lies(buch))(welt);
  const d = welt.PT_SEITE_I18N || {};
  const alsText = new Set([...seite.matchAll(/data-i18n(?:-ph|-titel)?="([^"]+)"/g)].map((m) => m[1]));
  ok(`${name}: das Wörterbuch trägt DE und EN, und die Seite benutzt Schlüssel (${alsText.size})`,
     !!d.de && !!d.en && alsText.size > 0);
  const mitEntitaet = [];
  const fehlen = [];
  for (const lang of Object.keys(d)) {
    for (const k of alsText) {
      const v = d[lang] && d[lang][k];
      if (typeof v === 'string' && /&[A-Za-z#][A-Za-z0-9]*;/.test(v)) mitEntitaet.push(`${lang}:${k}`);
    }
  }
  ok(`${name}: kein per textContent gesetzter Eintrag trägt eine HTML-Entität`,
     mitEntitaet.length === 0, mitEntitaet.join(', '));
}

console.log('\n── Was ohne JavaScript dasteht ──');
/* ⚠ BEFUND 2026-09-26, von der Gegenprobe entlarvt: zwei Fälle blieben blind
   („der Knopf heisst wieder Selbsttest", „der Satz ‚keine Virenprüfung'
   verschwindet"). Ihre Wächter in smoke_pruefer.mjs lesen textContent im
   BROWSER — und dort hat `sprache.js` den Satz längst aus dem Wörterbuch neu
   geschrieben. Für eine Sabotage an der DATEI waren sie damit blind. Genau das
   liest aber ein Leser ohne Skript und ein Crawler. Dieselbe Lehre steht in
   PWA-Toolpoints CLAUDE.md („ein Wächter las den Text NACH dem Wörterbuch").
   Gemessen wird deshalb BEIDES: der Satz in der Datei und in jeder Sprache
   des Wörterbuchs. Gesucht wird am Element (Kennung bzw. Marke), nicht frei in
   der Datei — der Kommentar darüber nennt dieselben Wörter. */
{
  const seite = lies('auslieferungspruefer.html');
  const welt = {};
  new Function('window', lies('assets/i18n-pruefer.js'))(welt);
  const d = welt.PT_SEITE_I18N || {};
  const elementText = (re) => { const m = seite.match(re); return m ? m[1] : null; };

  const knopf = elementText(/<button[^>]*id="koederKnopf"[^>]*>([\s\S]*?)<\/button>/);
  ok('der Test-Knopf steht in der Datei', knopf !== null);
  ok(`… und heißt dort nicht „Selbsttest" (${(knopf || '').trim()})`,
     knopf !== null && knopf.trim().length > 0 && !/Selbsttest/i.test(knopf));
  const knopfKey = (seite.match(/id="koederKnopf"[\s\S]*?data-i18n="([^"]+)"/) || [])[1];
  ok(`… und in keiner Sprache des Wörterbuchs (${knopfKey})`,
     !!knopfKey && !!d.de && !!d.en &&
     Object.keys(d).every((l) => typeof d[l][knopfKey] === 'string' && !/Selbsttest/i.test(d[l][knopfKey])));

  const grenze = elementText(/<p[^>]*data-mail-grenze="keine-virenpruefung"[^>]*>([\s\S]*?)<\/p>/);
  const flach = (t) => (t || '').replace(/<[^>]+>/g, '').replace(/\s+/g, ' ');
  /* ⚠ TAFEL-EVOLUTION (Klaus 2026-09-29): hier stand „nicht geöffnet". Seit
     assets/pruefer-anhang.js werden Anhänge GELESEN; die Zusage heißt jetzt
     „nie ausgeführt" — und dass Bildpunkte nicht gelesen werden. */
  ok('der Mail-Eingang sagt in der Datei, dass er KEINE Virenprüfung ist',
     /[Kk]eine Virenprüfung/.test(flach(grenze)) && /nie ausgeführt/.test(flach(grenze)) &&
     /Bildpunkten/.test(flach(grenze)));
  const grenzKey = (seite.match(/data-mail-grenze="keine-virenpruefung"[^>]*data-i18n-html="([^"]+)"/) || [])[1];
  ok(`… und das Wörterbuch sagt es auf Deutsch (${grenzKey})`,
     !!grenzKey && /[Kk]eine Virenprüfung/.test(flach(d.de && d.de[grenzKey])));
  ok('… und auf Englisch',
     !!grenzKey && /not a virus scan/i.test(flach(d.en && d.en[grenzKey])));
}

/* ══ EIGENSTÄNDIG: pdf.js liegt im eigenen Ordner (Klaus 2026-09-30) ═════════
   „Der Prüfer soll gar nicht mehr von Workflow PDF abhängen." Vorher holte die
   Seite pdf.js von ../Workflow-PDF/vendor/pdfjs/ — wurde das Nachbar-Depot
   umbenannt, war der Seitentext jedes PDFs ungeprüft. */
{
  const PDFJS_PINS = {
    'vendor/pdfjs/pdf.min.js':        '978fd1b2d134a98e98966186a97777bebf87d8e770dadab1ece3687e21a5aa6c',
    'vendor/pdfjs/pdf.worker.min.js': '38cde5311957b86bc3669f93e7d2566de333a90055ed6635bef60d9bf00e96f2',
  };
  for (const [p, h] of Object.entries(PDFJS_PINS)) {
    ok(`${p} liegt im eigenen Ordner, unverändert (pdf.js 3.11.174, Apache-2.0)`, da(p) && sha(p) === h, da(p) ? sha(p) : 'fehlt');
  }
  const ui = lies('assets/pruefer-ui.js');
  ok('die Seite holt pdf.js aus dem EIGENEN Ordner (pfade → vendor/pdfjs/)',
     /pfade\(\{\s*pdfjs:\s*new URL\("vendor\/pdfjs\/", location\.href\)/.test(ui));
  /* Gesucht wird in allem, was ausgeliefert wird — Kommentare ausgenommen,
     sonst verböte der Wächter den Satz, der erklärt, woher es früher kam. */
  const ohneKommentar = (t) => t.replace(/\/\*[\s\S]*?\*\//g, '').replace(/<!--[\s\S]*?-->/g, '');
  const ausgeliefert = ['auslieferungspruefer.html', 'index.html', 'sw.js',
    ...readdirSync(new URL('assets/', ROOT)).filter(f => f.endsWith('.js')).map(f => 'assets/' + f)];
  const fremd = ausgeliefert.filter(f => /Workflow-PDF/.test(ohneKommentar(lies(f))));
  ok(`keine ausgelieferte Datei holt etwas aus ../Workflow-PDF/ (${ausgeliefert.length} Dateien geprüft)`,
     fremd.length === 0 && ausgeliefert.length > 10, fremd.join(', '));
  ok('pdf-lib (nur zum Bauen der Proben) liegt in tests/vendor/, nicht auf der Seite',
     da('tests/vendor/pdf-lib.min.js') && !da('vendor/pdf-lib.min.js'));
  ok('die Herkunft der mitgelieferten Bibliotheken steht in THIRD_PARTY.md',
     da('THIRD_PARTY.md') && /3\.11\.174/.test(lies('THIRD_PARTY.md')) && /Apache/.test(lies('THIRD_PARTY.md')));
}

/* ══ EIGENSTÄNDIG: Tesseract liegt im eigenen Ordner (Stufe 2 A, 2026-09-30) ═
   Byte-gleich aus Workflow-PDF/vendor/tesseract/ (Tesseract.js 7.0.0, deu/eng/rus,
   21 MB). Nicht im Installations-Vorrat: der fetch-Zweig von sw.js legt die
   Dateien beim ersten Bild ab. */
{
  const TESS_PINS = {
    'vendor/tesseract/LICENSE-Apache-2.0.txt': 'c6596eb7be8581c18be736c846fb9173b69eccf6ef94c5135893ec56bd92ba08',
    'vendor/tesseract/lang/deu.traineddata': '19d219bbb6672c869d20a9636c6816a81eb9a71796cb93ebe0cb1530e2cdb22d',
    'vendor/tesseract/lang/eng.traineddata': '7d4322bd2a7749724879683fc3912cb542f19906c83bcc1a52132556427170b2',
    'vendor/tesseract/lang/rus.traineddata': 'e16e5e036cce1d9ec2b00063cf8b54472625b9e14d893a169e2b0dedeb4df225',
    'vendor/tesseract/tesseract-core-lstm.wasm.js': 'eef5f8b2f8e20e150680b20adaec4a60babafee3adbe8a94583c81fee46e8680',
    'vendor/tesseract/tesseract-core-relaxedsimd-lstm.wasm.js': '861a536cf9ef8e63cb644d57bab39c388f37f7d6b6f60024b741c5f6b39a59b3',
    'vendor/tesseract/tesseract-core-simd-lstm.wasm.js': 'c58b46a4c796c0b8afccf77591d5b875b6896b45d402bbce8caa6f5362447b38',
    'vendor/tesseract/tesseract.min.js': '000c27d9cd0def655f77b36c72a389c0ab13793aa31cb4d7aab56d09c0afbc7e',
    'vendor/tesseract/tesseract.min.js.LICENSE.txt': 'cdf963ced7d25a0f98901a547647b4d6e2dbe0197fd78c87a059a87b0e542fe2',
    'vendor/tesseract/worker.min.js': '576b7df7e3393e137e51849357c9adb53fe7ac1bb69bfa06cf3d61520f182c6d',
    'vendor/tesseract/worker.min.js.LICENSE.txt': '45f54171aeaa1d10c0c1a66f374b7bba1f02472b1487fbe892eec04f840002ac',
  };
  for (const [p, h] of Object.entries(TESS_PINS)) {
    ok(`${p} liegt im eigenen Ordner, unverändert (Tesseract.js 7.0.0)`, da(p) && sha(p) === h, da(p) ? sha(p) : 'fehlt');
  }
  const ui = lies('assets/pruefer-ui.js');
  ok('die Seite holt die Texterkennung aus dem EIGENEN Ordner (pfade → vendor/tesseract/)',
     /tesseract:\s*new URL\("vendor\/tesseract\/", location\.href\)/.test(ui));
  const sw = lies('sw.js'), core = (sw.match(/(?:var|const) CORE\s*=\s*\[([\s\S]*?)\];/) || [])[1] || '';
  ok('Alle drei OCR-Sprachdaten stehen im Offline-Vorrat', ['deu','eng','rus'].every(lang => core.includes('lang/'+lang+'.traineddata')));
  ok('THIRD_PARTY.md nennt Tesseract.js 7.0.0, die Sprachdaten und die Lizenz',
     /Tesseract\.js 7\.0\.0/.test(lies('THIRD_PARTY.md')) && /traineddata/.test(lies('THIRD_PARTY.md')) && /tessdata_fast/.test(lies('THIRD_PARTY.md')));
}

console.log(`\n${pass} grün · ${fail} ROT`);
process.exitCode = fail ? 1 : 0;
