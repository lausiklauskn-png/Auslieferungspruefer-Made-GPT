/* Eine Probe, die als KINDPROZESS läuft — mit eigener Frist und mit drei
 * Ausgängen statt zwei.
 *
 * WARUM ES DIESE DATEI GIBT (Befund 2026-09-10, behoben 2026-09-11).
 * `tests/smoke.mjs` startete `smoke_pruefer.mjs` mit `execFileSync` OHNE Frist
 * und meldete rot, sobald das Kind mit einem Fehler endete. Im Prüfer selbst
 * stehen Browser-Wartepunkte auf 30 s. Reicht die unter Last nicht, stirbt das
 * Kind an seiner eigenen Zeitüberschreitung — und im Eltern-Lauf stand
 * „eigene Probe grün: nein".
 *
 * ⚠ DAS IST EINE ZEILE, DIE NACH EINEM BEFUND AUSSIEHT UND KEINER IST.
 * Gemessen am 2026-09-10, während anderes lief: derselbe Baum, dreimal
 * `node tests/smoke.mjs` → 737 · 737 · 738. Einzeln aufgerufen war der Prüfer
 * jedes Mal grün. Die Zahl wanderte, ohne dass jemand etwas geändert hätte.
 *
 * ⚠ DIE FRIST HÖHERZUDREHEN WÄRE DIE FALSCHE ABHILFE — dieselbe Falle wie
 * „länger warten statt auf die Bedingung warten". Die Frist hier ist NICHT
 * dazu da, geduldiger zu sein; sie ist dazu da, eine Zeitüberschreitung
 * ERKENNBAR zu machen. Deshalb ist sie großzügig und deshalb gibt es einen
 * dritten Ausgang.
 *
 * DREI AUSGÄNGE, wie Sages Läufer sie kennt:
 *
 *   gruen  — das Kind lief durch und war zufrieden
 *   rot    — das Kind hat etwas gefunden, ODER es ist aus einem anderen Grund
 *            gestorben (fehlende Datei, Syntaxfehler). Ein Wurf ist ein Befund.
 *   frist  — das Kind ist NICHT FERTIG GEWORDEN. Das ist ungeprüft, nicht grün
 *            und nicht rot: es steht keine Aussage über den Prüfling dahinter.
 *
 * ⚠ EIN ECHTER BEFUND BLEIBT ROT, auch wenn irgendwo „Timeout" im Text steht.
 * Deshalb wird ZUERST die Schlusszeile des Kindes gelesen: nennt sie eine Zahl
 * ROT größer null, ist es ein Befund und sonst nichts. Ohne diese Reihenfolge
 * könnte ein Prüfling, dessen Befundtext das Wort trägt, sich selbst freisprechen.
 *
 * ⚠ KEIN SCHALTER AUS DER UMGEBUNG. Eine Frist, die sich per Umgebungsvariable
 * hochdrehen lässt, lässt sich auch still abschalten — und dann steht sie da,
 * ohne zu wirken (Kimhub, 2026-09-07). Wer sie zum Prüfen kürzen will, übergibt
 * `fristMs`; genau das tun die Wächter in `smoke.mjs` an einem erfundenen Kind.
 */
import { execFileSync } from 'node:child_process';

/* GEMESSEN, NICHT GERATEN (2026-09-11, diese Maschine, Chromium installiert):
   zwei volle Läufe von `tests/smoke_pruefer.mjs` → 10 969 ms und 8 016 ms,
   beide „216 grün, 0 ROT, 0 übersprungen".
   180 000 ms sind rund das SECHZEHNFACHE des langsameren. Eine Maschine müsste
   sechzehnmal langsamer sein, damit ein gesunder Lauf hier fällt.
   ⚠ Und weil eine festgenagelte Zahl still veralten kann, gibt `starteProbe`
   die GEMESSENE Dauer mit zurück — sie steht bei jedem Lauf daneben. Wächst sie
   auf die Frist zu, sieht man es dort und nicht erst an dem Tag, an dem sie fällt. */
export const FRIST_PRUEFER_MS = 180000;

/* Die Schlusszeile einer Probe: „216 grün, 0 ROT, 0 übersprungen". */
const SCHLUSS = /(\d+) grün, (\d+) ROT/;

/* Woran man eine Zeitüberschreitung des KINDES erkennt. Playwright schreibt
   `TimeoutError: page.waitForFunction: Timeout 30000ms exceeded.` — das ist
   keine Aussage über die Seite, sondern eine über die Uhr. */
const ZEIT = /TimeoutError|Timeout \d+ms exceeded|waitFor\w*: Timeout/;

export function starteProbe({ pfad, fristMs = FRIST_PRUEFER_MS, argv = [] }) {
  const begonnen = Date.now();
  let text = '', gestorben = null;
  try {
    text = String(execFileSync(process.execPath, [pfad, ...argv],
                               { stdio: 'pipe', timeout: fristMs, maxBuffer: 64e6 }));
  } catch (e) {
    gestorben = e;
    text = String(e.stdout || '') + '\n' + String(e.stderr || '') + '\n' + String(e.message || '');
  }
  const dauerMs = Date.now() - begonnen;
  const zeile = text.trim().split('\n').filter((z) => SCHLUSS.test(z)).pop() || '';
  const treffer = zeile.match(SCHLUSS);

  /* 1 · Der Prüfling hat etwas gefunden. Das gilt VOR allem anderen. */
  if (treffer && Number(treffer[2]) > 0) {
    return { art: 'rot', zeile, dauerMs, fristMs,
             hinweis: text.trim().split('\n').filter((z) => /ROT/.test(z)).slice(-2).join(' | ') };
  }
  /* 2 · Durchgelaufen und zufrieden. */
  if (!gestorben && treffer) return { art: 'gruen', zeile, dauerMs, fristMs, hinweis: '' };

  /* 3 · Die eigene Frist hat zugeschlagen — das Kind lebte noch. */
  const getoetet = gestorben && (gestorben.code === 'ETIMEDOUT' ||
                                 gestorben.signal === 'SIGTERM' || gestorben.killed === true);
  /* 4 · Das Kind ist an seiner INNEREN Uhr gestorben, bevor unsere Frist kam.
         Das ist der Fall, der am 2026-09-10 gemessen wurde. */
  if (getoetet || (gestorben && !treffer && ZEIT.test(text))) {
    return { art: 'frist', zeile, dauerMs, fristMs,
             hinweis: getoetet ? `nach ${Math.round(dauerMs / 1000)} s abgebrochen (eigene Frist ${Math.round(fristMs / 1000)} s)`
                               : `das Kind ist an seiner eigenen Uhr gestorben (${Math.round(dauerMs / 1000)} s)` };
  }
  /* 4b · DER VERTRAG IST GEBROCHEN, nicht der Prüfling.
   *
   * Das Kind ist zufrieden zurückgekommen (Rückgabewert 0), aber seine
   * Schlusszeile ist nicht zu lesen — `SCHLUSS` hat nichts gefunden. Das ist
   * KEIN Befund über den Prüfling, und es als einen zu melden weist in die
   * falsche Richtung: man sucht dann im Prüfling nach einem Fehler, den es
   * nicht gibt.
   *
   * Gemessen am 2026-09-21, an tests/smoke_detail.mjs: es schrieb
   * `10 grün · 0 ROT` mit Mittelpunkt statt Komma. ZEHN grüne Zeilen, null
   * rote — und der Lauf meldete ROT mit dem Hinweis „Rückgabewert
   * undefined". Ein Wächter am Wortlaut, diesmal zwischen zwei Dateien.
   *
   * Rot bleibt es trotzdem: eine Probe, deren Ergebnis niemand lesen kann,
   * ist nicht grün. Nur sagt die Zeile jetzt, WORAN es liegt. */
  if (!gestorben && !treffer) {
    return { art: 'rot', zeile, dauerMs, fristMs,
             hinweis: 'das Kind kam mit 0 zurück, aber ohne lesbare Schlusszeile ' +
                      '— erwartet wird „N grün, N ROT" (siehe SCHLUSS in tests/kindprozess.mjs). ' +
                      'Letzte Zeile: ' + (text.trim().split('\n').pop() || '(leer)') };
  }

  /* 5 · Jeder andere Wurf ist ein Befund — fehlende Datei, Syntaxfehler.
         Kimhubs Regel: eine Probe, die wirft, ist ROT, kein toter Läufer. */
  return { art: 'rot', zeile, dauerMs, fristMs,
           hinweis: text.trim().split('\n').filter((z) => /ROT|Error/.test(z)).slice(-2).join(' | ')
                    || `Rückgabewert ${gestorben && gestorben.status}` };
}

/* Die Schlusszeile steht HIER und nicht im Läufer, damit ein Wächter sie
   wirklich FAHREN kann statt sie zu lesen. Eine dritte Spalte, die nur bei
   Bedarf erscheint, liest niemand — deshalb steht sie immer da, auch als Null. */
export function schlusszeile(pass, fail, offen) {
  return `${pass}/${pass + fail} bestanden · ${offen} nicht abgeschlossen`;
}
