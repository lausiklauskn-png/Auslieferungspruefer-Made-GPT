/*
 * smoke_vorbelegung.mjs — der Weg über `?adresse=`: vorbelegt, NICHT abgerufen.
 *
 * Übernommen aus PWA-Toolpoints `tests/smoke_detail.mjs` (Abschnitt „DER WEG
 * ZUM PRÜFER"), 2026-09-26. Dort lief er gegen die Detailseiten des
 * Marktplatzes, die es hier nicht gibt; deshalb stand er in der ersten Kopie
 * dieses Depots NICHT, und die Gegenprobe meldete vier Fälle als blind —
 * zwei davon Sicherheits-Zusicherungen (kein Abruf beim Laden, kein
 * `javascript:`-Wert im Feld).
 *
 * Zusätzlich: `index.html` reicht den Anhang an die Prüferseite weiter. Ohne
 * das käme ein Link auf die kurze Adresse mit leerem Feld an.
 *
 * Drei Ausgänge: ✓ grün · ✗ ROT · ⊘ nicht lauffähig.
 */
import http from "node:http";
import { readFileSync } from "node:fs";
import { join, dirname, extname } from "node:path";
import { fileURLToPath } from "node:url";
import { findeChromium } from "./chromium-finden.mjs";

const WURZEL = join(dirname(fileURLToPath(import.meta.url)), "..");
let gruen = 0, rot = 0;
const ok = (bed, satz, info) => {
  if (bed) { gruen++; console.log("✓ " + satz); }
  else { rot++; console.log("✗ ROT: " + satz + (info ? "  → " + info : "")); }
};

let chromium;
try { ({ chromium } = await import("playwright-core")); }
catch { console.log("⊘ nicht lauffähig: playwright-core fehlt"); process.exit(0); }
const exe = findeChromium();
if (!exe) { console.log("⊘ nicht lauffähig: kein Chromium"); process.exit(0); }

const TYP = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".css": "text/css",
  ".json": "application/json", ".svg": "image/svg+xml", ".png": "image/png" };
const server = http.createServer((q, a) => {
  const p = decodeURIComponent(new URL(q.url, "http://x").pathname).replace(/^\/+/, "") || "index.html";
  try { const b = readFileSync(join(WURZEL, p)); a.writeHead(200, { "content-type": TYP[extname(p)] || "application/octet-stream" }); a.end(b); }
  catch { a.writeHead(404); a.end(); }
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));   // Port 0: kein Zusammenstoß mit einem zweiten Lauf
const BASIS = `http://127.0.0.1:${server.address().port}/`;

const browser = await chromium.launch({ executablePath: exe });
try {
  const ctx = await browser.newContext({ viewport: { width: 412, height: 900 }, serviceWorkers: "block" });

  const sichtbarkeit = (seite) => seite.evaluate(() => {
    const sicht = (el) => {
      if (!el) return false;
      const r = el.getBoundingClientRect();
      return r.width > 0 && r.height > 0 && el.checkVisibility && el.checkVisibility();
    };
    const offen = [...document.querySelectorAll('[id^="reiter-"]')]
      .filter((t) => t.getAttribute("aria-selected") === "true").map((t) => t.id);
    return { offen, feld: sicht(document.getElementById("adrFeld")), knopf: sicht(document.getElementById("adrKnopf")),
      wert: (document.getElementById("adrFeld") || {}).value ?? null };
  });

  /* ── vorbelegt, aber kein Abruf ─────────────────────────────────────── */
  const s2 = await ctx.newPage();
  const hinaus = [];
  s2.on("request", (r) => { if (!r.url().startsWith(BASIS)) hinaus.push(r.url()); });
  const fremd = "https://lausiklauskn-png.github.io/Mein-Mixarium-Page/";
  await s2.goto(`${BASIS}auslieferungspruefer.html?adresse=${encodeURIComponent(fremd)}`, { waitUntil: "load" });
  await s2.waitForTimeout(600);   // Sorte B: hier soll etwas AUSBLEIBEN, also muss eine Frist verstreichen
  const z2 = await sichtbarkeit(s2);
  ok(z2.wert === fremd, `die Adresse steht im Feld des Prüfers ("${z2.wert}")`);
  /* Gemessen wird der VERKEHR, nicht der Quelltext: gar nichts nach draußen,
     wie im Original. Ein Abruf beim Laden wäre eine Eigenanfrage ins offene
     Netz, ausgelöst von einer Adresszeile. */
  ok(hinaus.length === 0, `… und es ging KEIN Abruf hinaus (${hinaus.length})`, hinaus.join(" · "));
  ok(z2.offen.length === 1 && z2.offen[0] === "reiter-adresse",
    "… und der Eingang „Adresse abrufen“ steht offen", z2.offen.join(", "));
  ok(z2.feld && z2.knopf, "… Feld und Knopf sind wirklich ZU SEHEN");

  /* ── die Gegenrichtung: ohne Anhang bleibt alles beim Alten ──────────── */
  const s3 = await ctx.newPage();
  await s3.goto(`${BASIS}auslieferungspruefer.html`, { waitUntil: "load" });
  const z3 = await sichtbarkeit(s3);
  ok(typeof z3.wert === "string" && z3.wert.length > 0 && z3.wert !== fremd,
    `ohne Anhang steht die Vorgabe des Markups da ("${z3.wert}")`);
  ok(z3.offen[0] === "reiter-html", `ohne Anhang bleibt der erste Eingang offen (${z3.offen.join(", ")})`);

  /* ── ein javascript:-Wert kommt nicht hinein und legt nichts um ────────── */
  const s4 = await ctx.newPage();
  await s4.goto(`${BASIS}auslieferungspruefer.html?adresse=` + encodeURIComponent("javascript:alert(1)"), { waitUntil: "load" });
  const z4 = await sichtbarkeit(s4);
  ok(z4.wert === z3.wert, `ein javascript:-Wert kommt NICHT ins Feld ("${z4.wert}")`);
  ok(z4.offen[0] === "reiter-html", `… und legt den Reiter NICHT um (${z4.offen.join(", ")})`);

  /* ── die kurze Adresse reicht den Anhang weiter ──────────────────────── */
  const s5 = await ctx.newPage();
  await s5.goto(`${BASIS}?adresse=${encodeURIComponent(fremd)}`, { waitUntil: "load" });
  await s5.waitForFunction(() => location.pathname.endsWith("auslieferungspruefer.html"));
  const z5 = await sichtbarkeit(s5);
  ok(z5.wert === fremd, `index.html leitet samt ?adresse= weiter ("${z5.wert}")`);
} catch (e) {
  rot++; console.log("✗ ROT: unterwegs gestolpert → " + (e && e.stack || e));
} finally {
  await browser.close(); server.close();
  console.log(`\n${gruen} grün · ${rot} ROT`);
  process.exitCode = rot ? 1 : 0;
}
